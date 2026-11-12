class_name WorldRoot
extends Node3D
## WorldRoot — raíz de la escena del mundo en el cliente.
##
## Responsabilidad: montar cielo/clima, agua, streaming de sectores y jugador local; crear y
## actualizar los objetos dinámicos que dicta el servidor (objetos recogibles, recolección,
## estructuras, puertas, contenedores), los jugadores remotos y las criaturas.
## Datos: registros id -> nodo. Señales: ui_requested(nombre), loaded().
## Autoridad online: ninguna; todo refleja Session (estado recibido del servidor).

signal ui_requested(screen: String)
signal loaded()

static var current: WorldRoot = null
static var interactables: Array[Interactable] = []

var world: WorldMap
var streamer: WorldStreamer
var sky: SkyWeather
var water: MeshInstance3D
var player: PlayerController
var dynamic: Node3D
var remotes: Dictionary = {}
var creatures: Dictionary = {}
var door_nodes: Dictionary = {}
var box_nodes: Dictionary = {}
var pickup_nodes: Dictionary = {}
var struct_nodes: Dictionary = {}
var harvest_nodes: Dictionary = {}
var detail: Dictionary = {}
var is_loaded := false
var _seen: Dictionary = {}
var _ctx_acc := 0.0

static func request_ui(screen: String) -> void:
	if current != null:
		current.ui_requested.emit(screen)

func _enter_tree() -> void:
	current = self
	interactables.clear()

func _exit_tree() -> void:
	if current == self:
		current = null
	interactables.clear()
	AudioDirector.stop_ambience()

func _ready() -> void:
	world = GameData.world
	sky = SkyWeather.new()
	sky.name = "Sky"
	add_child(sky)
	_make_water()
	dynamic = Node3D.new()
	dynamic.name = "Dynamic"
	add_child(dynamic)
	streamer = WorldStreamer.new()
	streamer.name = "Streamer"
	streamer.world = world
	streamer.budget_ms = 14.0
	add_child(streamer)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.frozen = true
	player.place(Session.spawn_pos + Vector3(0, 0.3, 0), Session.spawn_yaw)
	streamer.ready_near.connect(_on_near_ready)
	Session.object_event.connect(_on_object_event)
	Session.objects_received.connect(_on_objects)
	Session.snapshot.connect(_on_snapshot)
	Session.roster_changed.connect(_on_roster)
	Session.emote_received.connect(_on_emote)
	Session.respawned.connect(func(p: Vector3) -> void: streamer.update_center(p))
	streamer.update_center(player.global_position)

func _on_near_ready() -> void:
	if is_loaded:
		return
	is_loaded = true
	streamer.budget_ms = 4.0 if OS.has_feature("mobile") else 6.0
	player.frozen = false
	var g := world.ground(player.global_position.x, player.global_position.z)
	if player.global_position.y < g - 0.2:
		player.global_position.y = g + 0.2
	loaded.emit()

func _make_water() -> void:
	water = MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(WorldMap.SIZE, WorldMap.SIZE)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	water.mesh = pm
	water.position = Vector3(WorldMap.SIZE * 0.5, world.water_level, WorldMap.SIZE * 0.5)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = AssetLib.material("water")
	var img := Image.create_from_data(world.samples, world.samples, false, Image.FORMAT_RF, world.heights.to_byte_array())
	mat.set_shader_parameter("height_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("water_level", world.water_level)
	mat.set_shader_parameter("world_size", WorldMap.SIZE + world.step)
	water.material_override = mat
	add_child(water)

func _process(delta: float) -> void:
	var cam_pos := player.cam.global_position
	streamer.update_center(player.global_position)
	sky.update(delta, cam_pos, player.indoors)
	_ctx_acc += delta
	if _ctx_acc > 0.5:
		_ctx_acc = 0.0
		AudioDirector.set_context(world.region_name(cam_pos.x, cam_pos.z), player.indoors, Session.is_night(), sky.rain_amount, sky.wind, sky.mist)
		var now := Time.get_ticks_msec()
		for id: int in _seen.keys():          # quien deja de llegar en las fotos de estado, desaparece
			if now - int(_seen[id]) > 2500:
				_seen.erase(id)
				if id > 0 and remotes.has(id):
					(remotes[id] as Node).queue_free()
					remotes.erase(id)
				elif id < 0 and creatures.has(-id):
					(creatures[-id] as Node).queue_free()
					creatures.erase(-id)

# ---- detalle por sector --------------------------------------------------------------------------------
func sector_detail(key: int, on: bool) -> void:
	if on:
		detail[key] = true
		for hi: int in world.sector_harvest(key):
			var node: Dictionary = world.harvest_nodes[hi]
			if not harvest_nodes.has(int(node.id)):
				var h := Interactables.Harvest.new()
				h.setup(node)
				dynamic.add_child(h)
				harvest_nodes[int(node.id)] = h
		_sync_sector(key)
	else:
		detail.erase(key)
		for hi: int in world.sector_harvest(key):
			var id := int(world.harvest_nodes[hi].id)
			if harvest_nodes.has(id):
				(harvest_nodes[id] as Node).queue_free()
				harvest_nodes.erase(id)
		for id: int in pickup_nodes.keys():
			var n: Node3D = pickup_nodes[id]
			if WorldMap.sector_key(n.position.x, n.position.z) == key:
				n.queue_free()
				pickup_nodes.erase(id)
		for id: int in struct_nodes.keys():
			var n: Node3D = struct_nodes[id]
			if WorldMap.sector_key(n.position.x, n.position.z) == key:
				n.queue_free()
				struct_nodes.erase(id)

func forget_interior(key: int) -> void:
	for bi: int in world.sector_buildings(key):
		for k: int in door_nodes.keys():
			if k / 64 == bi:
				door_nodes.erase(k)
		for k: int in box_nodes.keys():
			if k / 64 == bi:
				box_nodes.erase(k)

func _sync_sector(key: int) -> void:
	for id: int in Session.pickups.keys():
		var p: Dictionary = Session.pickups[id]
		if WorldMap.sector_key(p.pos.x, p.pos.z) == key:
			_ensure_pickup(id, p)
	for id: int in Session.structs.keys():
		var s: Dictionary = Session.structs[id]
		if WorldMap.sector_key(s.pos.x, s.pos.z) == key:
			_ensure_struct(s)

func _ensure_pickup(id: int, p: Dictionary) -> void:
	if pickup_nodes.has(id):
		return
	var n := Interactables.Pickup.new()
	n.setup(id, p)
	dynamic.add_child(n)
	pickup_nodes[id] = n

func _ensure_struct(s: Dictionary) -> void:
	var n: Interactables.Structure = struct_nodes.get(int(s.id))
	if n == null:
		n = Interactables.Structure.new()
		n.setup(s)
		dynamic.add_child(n)
		struct_nodes[int(s.id)] = n
	else:
		n.apply(s)

func _on_objects(keys: Array) -> void:
	for k: Variant in keys:
		if detail.has(int(k)):
			_sync_sector(int(k))
	for dk: int in door_nodes.keys():
		(door_nodes[dk] as Interactables.Door).set_open(Session.open_doors.has(dk), false)
	for hid: int in harvest_nodes.keys():
		(harvest_nodes[hid] as Interactables.Harvest).set_ready(not Session.depleted.has(hid))
	for id: int in pickup_nodes.keys():
		if not Session.pickups.has(id):
			(pickup_nodes[id] as Node).queue_free()
			pickup_nodes.erase(id)
	for id: int in struct_nodes.keys():
		if not Session.structs.has(id):
			(struct_nodes[id] as Node).queue_free()
			struct_nodes.erase(id)

func _on_object_event(kind: int, id: int, state: Variant) -> void:
	match kind:
		Protocol.O_DOOR:
			if door_nodes.has(id):
				(door_nodes[id] as Interactables.Door).set_open(bool(state))
		Protocol.O_CONTAINER:
			if box_nodes.has(id):
				(box_nodes[id] as Interactables.Box).set_open(bool(state))
		Protocol.O_PICKUP:
			if state == null:
				if pickup_nodes.has(id):
					(pickup_nodes[id] as Node).queue_free()
					pickup_nodes.erase(id)
			elif Session.pickups.has(id):
				var p: Dictionary = Session.pickups[id]
				if detail.has(WorldMap.sector_key(p.pos.x, p.pos.z)):
					_ensure_pickup(id, p)
		Protocol.O_HARVEST:
			if harvest_nodes.has(id):
				(harvest_nodes[id] as Interactables.Harvest).set_ready(bool(state))
		Protocol.O_STRUCT:
			if state == null:
				if struct_nodes.has(id):
					(struct_nodes[id] as Node).queue_free()
					struct_nodes.erase(id)
			elif Session.structs.has(id):
				var s: Dictionary = Session.structs[id]
				if detail.has(WorldMap.sector_key(s.pos.x, s.pos.z)):
					_ensure_struct(s)

# ---- otros jugadores y criaturas ---------------------------------------------------------------------------
func _on_snapshot(_ms: int, players: Array, crs: Array) -> void:
	var now := Time.get_ticks_msec()
	for pl: Array in players:
		var id := int(pl[0])
		_seen[id] = now
		var r: RemotePlayer = remotes.get(id)
		if r == null:
			if not Session.roster.has(id):
				continue
			r = RemotePlayer.new()
			add_child(r)
			r.setup(Session.roster[id])
			remotes[id] = r
		r.push(Vector3(pl[1], pl[2], pl[3]), float(pl[4]), int(pl[6]), int(pl[7]))
	for c: Array in crs:
		var id := int(c[0])
		_seen[-id] = now
		var v: CreatureView = creatures.get(id)
		if v == null:
			v = CreatureView.new()
			add_child(v)
			v.setup(id, ServerCreatures.TYPES[int(c[1])])
			creatures[id] = v
		v.push(Vector3(c[2], c[3], c[4]), float(c[5]), int(c[6]), int(c[7]))

func _on_roster() -> void:
	for id: int in remotes.keys():
		if not Session.roster.has(id):
			(remotes[id] as Node).queue_free()
			remotes.erase(id)
		else:
			(remotes[id] as RemotePlayer).apply_info(Session.roster[id])

func _on_emote(peer: int, code: int) -> void:
	if peer < 0:
		if creatures.has(-peer):
			(creatures[-peer] as CreatureView).event(code)
	elif code == 100:
		var at: Vector3 = (remotes[peer] as Node3D).global_position if remotes.has(peer) else player.global_position
		AudioDirector.play_at("rattle", at, 4.0)
