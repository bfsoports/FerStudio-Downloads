class_name ServerWorld
extends RefCounted
## ServerWorld — estado persistente de los objetos del mundo (autoridad del servidor).
##
## Datos: puertas abiertas, contenedores (inventarios), objetos recogibles (botín de puntos
## fijos y objetos soltados), nodos de recolección agotados y estructuras construidas.
## Reposición de botín y recursos controlada aquí, solo cuando no hay jugadores cerca.
## Lo llaman: ServerActions (peticiones validadas) y GameServer (interés por sectores).
## Persistencia: save_state()/load_state() dentro de world.json.

const DROP_BASE := 100000
const STRUCT_CONTAINER := 1000000
const PICKUP_TTL := 1800.0
const NEAR := 42.0

var srv: GameServer
var doors: Dictionary = {}         # clave -> true (abierta)
var unlocked: Dictionary = {}      # "d<clave>" / "c<clave>" -> true (cerradura ya abierta con llave o palanca)
var containers: Dictionary = {}    # clave -> {inv: Inventory, gen: float, by: int, table: String}
var pickups: Dictionary = {}       # id -> {item, n, d, pos: Vector3, src: int, t: float}
var loot_taken: Dictionary = {}    # clave de punto de botín -> instante en que se recogió
var harvest_ready: Dictionary = {} # id de nodo -> instante en que vuelve a estar disponible
var harvest_busy: Dictionary = {}  # id de nodo -> peer que lo está recolectando
var structures: Dictionary = {}    # id -> {id, type, pos: Vector3, yaw, stage, owner, perm, fuel, water, open, lock, by}
var next_drop := DROP_BASE
var next_struct := 1
var _sector_pickups: Dictionary = {}
var _sector_structs: Dictionary = {}
var _respawn_cursor := 0
var _rng := RandomNumberGenerator.new()

func _init(server: GameServer) -> void:
	srv = server
	_rng.randomize()

# ---- índice por sector --------------------------------------------------------------------------------
func _idx_add(d: Dictionary, pos: Vector3, id: int) -> void:
	var k := WorldMap.sector_key(pos.x, pos.z)
	if not d.has(k):
		d[k] = {}
	d[k][id] = true

func _idx_del(d: Dictionary, pos: Vector3, id: int) -> void:
	var k := WorldMap.sector_key(pos.x, pos.z)
	if d.has(k):
		(d[k] as Dictionary).erase(id)

func player_near(pos: Vector3, r: float) -> bool:
	for p: ServerPlayer in srv.players.values():
		if p.pos.distance_squared_to(pos) < r * r:
			return true
	return false

# ---- botín de puntos fijos ---------------------------------------------------------------------------------
func loot_point_pos(key: int) -> Variant:
	var bi := key / 64
	var li := key % 64
	if bi < 0 or bi >= srv.world.buildings.size():
		return null
	var pts: Array = (srv.world.buildings[bi].meta as Dictionary).get("loot", [])
	if li >= pts.size():
		return null
	return srv.world.to_world(bi, DataFiles.v3(pts[li].pos))

func roll_table(table_id: String) -> Array:
	var t: Dictionary = GameData.loot_tables.get(table_id, {})
	var out: Array = []
	if t.is_empty():
		return out
	for g: String in t.get("guaranteed", []):
		out.append([g, 1])
	var rolls: Array = t.get("rolls", [1, 1])
	var n := _rng.randi_range(int(rolls[0]), int(rolls[1]))
	var items: Array = t.get("items", [])
	var total := 0.0
	for e: Array in items:
		total += float(e[1])
	for i in n:
		var r := _rng.randf() * total
		for e: Array in items:
			r -= float(e[1])
			if r <= 0.0:
				if not (String(e[0]) in t.get("guaranteed", [])):
					out.append([String(e[0]), _rng.randi_range(int(e[2]), int(e[3]))])
				break
	return out

func _spawn_loot_point(key: int, announce: bool) -> void:
	var pos: Variant = loot_point_pos(key)
	if pos == null or pickups.has(key):
		return
	var bi := key / 64
	var table := String((srv.world.buildings[bi].meta as Dictionary).loot[key % 64].table)
	var rolled := roll_table(table)
	if rolled.is_empty():
		return
	var e: Array = rolled[0]
	_add_pickup(key, String(e[0]), mini(int(e[1]), GameData.stack_max(String(e[0]))), -2, pos, key, announce)

func _add_pickup(id: int, item: String, n: int, d: int, pos: Vector3, src: int, announce: bool) -> void:
	if d == -2:
		d = int(GameData.item(item).get("dur", -1))
	pickups[id] = {"item": item, "n": n, "d": d, "pos": pos, "src": src, "t": srv.unix}
	_idx_add(_sector_pickups, pos, id)
	if announce:
		srv.obj_event(pos, Protocol.O_PICKUP, id, [item, n, pos.x, pos.y, pos.z])

## Suelta un objeto en el mundo (jugador que descarta, botín que no cabe…).
func drop_item(item: String, n: int, d: int, pos: Vector3) -> int:
	var id := next_drop
	next_drop += 1
	var g := srv.world.ground(pos.x, pos.z)
	var y := pos.y if absf(pos.y - g) < 6.0 and pos.y > g - 0.3 else g
	_add_pickup(id, item, n, d, Vector3(pos.x + _rng.randf_range(-0.25, 0.25), y + 0.05, pos.z + _rng.randf_range(-0.25, 0.25)), -1, true)
	return id

## Retira un objeto recogible. Devuelve su entrada o un diccionario vacío si ya no existe.
func take_pickup(id: int) -> Dictionary:
	var e: Variant = pickups.get(id)
	if e == null:
		return {}
	pickups.erase(id)
	_idx_del(_sector_pickups, e.pos, id)
	if int(e.src) >= 0:
		loot_taken[int(e.src)] = srv.unix
	srv.obj_event(e.pos, Protocol.O_PICKUP, id, null)
	return e

# ---- contenedores -----------------------------------------------------------------------------------------------
func container_info(key: int) -> Dictionary:
	# -> {pos, slots, table, locked, struct} o vacío si la clave no corresponde a nada
	if key >= STRUCT_CONTAINER:
		var s: Variant = structures.get(key - STRUCT_CONTAINER)
		if s == null or int(s.stage) < 1:
			return {}
		var def: Dictionary = GameData.structures.get(String(s.type), {})
		if not def.has("container"):
			return {}
		return {"pos": s.pos + Vector3(0, 0.4, 0), "slots": int(def.container), "table": "", "locked": "", "struct": int(s.id)}
	var bi := key / 64
	var ci := key % 64
	if bi < 0 or bi >= srv.world.buildings.size():
		return {}
	var list: Array = (srv.world.buildings[bi].meta as Dictionary).get("containers", [])
	if ci >= list.size():
		return {}
	var c: Dictionary = list[ci]
	var def := DataFiles.prop(String(c.model))
	var lp := DataFiles.v3(c.pos) + Vector3(0, float(def.get("wall", 0.0)) + 0.5, 0)
	return {"pos": srv.world.to_world(bi, lp), "slots": int((def.get("container", {}) as Dictionary).get("slots", 8)), "table": String(c.loot), "locked": String(c.get("locked", "")), "struct": -1}

func get_container(key: int) -> Dictionary:
	var info := container_info(key)
	if info.is_empty():
		return {}
	var c: Variant = containers.get(key)
	var table := String(info.table)
	var respawn := float((GameData.loot_tables.get(table, {}) as Dictionary).get("respawn", 7200))
	if c == null or (table != "" and int(c.by) == 0 and srv.unix - float(c.gen) > respawn and (c.inv as Inventory).used() <= 1):
		var inv := Inventory.new(int(info.slots))
		for e: Array in roll_table(table):
			inv.add(String(e[0]), int(e[1]))
		c = {"inv": inv, "gen": srv.unix, "by": 0, "table": table}
		containers[key] = c
	return c

func close_container(p: ServerPlayer) -> void:
	if p.container < 0:
		return
	var c: Variant = containers.get(p.container)
	if c != null and int(c.by) == p.peer:
		c.by = 0
	var info := container_info(p.container)
	if not info.is_empty():
		srv.obj_event(info.pos, Protocol.O_CONTAINER, p.container, false)
	p.container = -1
	srv.send(p, Protocol.S.CONTAINER_CLOSED, null)

# ---- estructuras ----------------------------------------------------------------------------------------------------
func add_structure(type: String, pos: Vector3, yaw: float, owner: String, stage: int) -> Dictionary:
	var s := {"id": next_struct, "type": type, "pos": pos, "yaw": yaw, "stage": stage, "owner": owner, "perm": 1, "fuel": 0.0, "water": 0, "open": false, "lock": false, "t": srv.unix}
	next_struct += 1
	structures[int(s.id)] = s
	_idx_add(_sector_structs, pos, int(s.id))
	srv.obj_event(pos, Protocol.O_STRUCT, int(s.id), struct_packet(s))
	return s

func update_structure(s: Dictionary) -> void:
	srv.obj_event(s.pos, Protocol.O_STRUCT, int(s.id), struct_packet(s))

func remove_structure(id: int) -> void:
	var s: Variant = structures.get(id)
	if s == null:
		return
	structures.erase(id)
	containers.erase(STRUCT_CONTAINER + id)
	_idx_del(_sector_structs, s.pos, id)
	srv.obj_event(s.pos, Protocol.O_STRUCT, id, null)

func struct_packet(s: Dictionary) -> Array:
	var lit: bool = float(s.fuel) > srv.unix
	return [int(s.id), String(s.type), s.pos.x, s.pos.y, s.pos.z, float(s.yaw), int(s.stage), String(s.owner).left(8), int(s.perm), lit, int(s.water), bool(s.open), bool(s.lock)]

func count_owned(owner: String) -> int:
	var n := 0
	for s: Dictionary in structures.values():
		if String(s.owner) == owner and String(s.type) != "bulto":
			n += 1
	return n

func structures_near(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var s0 := WorldMap.sector_of(pos.x - r, pos.z - r)
	var s1 := WorldMap.sector_of(pos.x + r, pos.z + r)
	for sj in range(s0.y, s1.y + 1):
		for si in range(s0.x, s1.x + 1):
			for id: int in (_sector_structs.get(sj * WorldMap.SECTORS + si, {}) as Dictionary).keys():
				var s: Dictionary = structures[id]
				if (s.pos as Vector3).distance_to(pos) <= r:
					out.append(s)
	return out

## Estación disponible cerca: "fire" (hoguera encendida), "workbench", "water".
func station_near(p: ServerPlayer, station: String) -> bool:
	if station == "":
		return true
	for s: Dictionary in structures_near(p.pos, 4.0):
		var def: Dictionary = GameData.structures.get(String(s.type), {})
		if int(s.stage) >= 1 and String(def.get("station", "")) == station:
			if station == "fire" and float(s.fuel) <= srv.unix:
				continue
			return true
	if p.indoors >= 0 and String((srv.world.buildings[p.indoors].meta as Dictionary).get("station", "")) == station:
		return true
	for pi: int in srv.world.sector_props(WorldMap.sector_key(p.pos.x, p.pos.z)):
		var pr: Dictionary = srv.world.props[pi]
		if (pr.pos as Vector3).distance_to(p.pos) < 4.5 and String(DataFiles.prop(String(pr.model)).get("station", "")) == station:
			return true
	if station == "water" and srv.world.near_water(p.pos.x, p.pos.z):
		return true
	return false

func fire_near(pos: Vector3) -> float:
	# calor aportado por la hoguera encendida más cercana (0..1)
	var best := 0.0
	for s: Dictionary in structures_near(pos, 8.0):
		if String(s.type) == "hoguera" and int(s.stage) >= 1 and float(s.fuel) > srv.unix:
			var warm := float((GameData.structures.hoguera as Dictionary).get("warm", 7.0))
			best = maxf(best, clampf(1.0 - (s.pos as Vector3).distance_to(pos) / warm, 0.0, 1.0))
	return best

func shelter_near(pos: Vector3) -> bool:
	for s: Dictionary in structures_near(pos, 2.6):
		if int(s.stage) >= 1 and String(s.type) in ["refugio", "tejado"]:
			return true
	return false

# ---- paquete de estado de un sector (para el interés de un cliente) -----------------------------------------------------
func sector_packet(key: int) -> Dictionary:
	var open_doors: Array = []
	for bi: int in srv.world.sector_buildings(key):
		for d: Dictionary in (srv.world.buildings[bi].meta as Dictionary).get("doors", []):
			var dk := Protocol.door_key(bi, int(d.id))
			if doors.get(dk, false):
				open_doors.append(dk)
	var pk: Array = []
	for id: int in (_sector_pickups.get(key, {}) as Dictionary).keys():
		var e: Dictionary = pickups[id]
		pk.append([id, String(e.item), int(e.n), e.pos.x, e.pos.y, e.pos.z])
	var hv: Array = []
	for hi: int in srv.world.sector_harvest(key):
		var node: Dictionary = srv.world.harvest_nodes[hi]
		if float(harvest_ready.get(int(node.id), 0.0)) > srv.unix:
			hv.append(int(node.id))
	var st: Array = []
	for id: int in (_sector_structs.get(key, {}) as Dictionary).keys():
		st.append(struct_packet(structures[id]))
	return {"k": key, "doors": open_doors, "pickups": pk, "harvest": hv, "structs": st}

# ---- mantenimiento: reposición, caducidad, hogueras, colectores ----------------------------------------------------------
func tick(_dt: float) -> void:
	# puntos de botín: se reparte el trabajo (unos pocos por segundo)
	var bcount := srv.world.buildings.size()
	for step in 3:
		_respawn_cursor = (_respawn_cursor + 1) % maxi(1, bcount)
		var meta: Dictionary = srv.world.buildings[_respawn_cursor].meta
		var pts: Array = meta.get("loot", [])
		for li in pts.size():
			var key := _respawn_cursor * 64 + li
			if pickups.has(key):
				continue
			var taken := float(loot_taken.get(key, -1.0))
			var respawn := float((GameData.loot_tables.get(String(pts[li].table), {}) as Dictionary).get("respawn", 7200))
			if taken < 0.0 or srv.unix - taken > respawn:
				var pos: Variant = loot_point_pos(key)
				if pos != null and not player_near(pos, NEAR):
					loot_taken.erase(key)
					if _rng.randf() < 0.75:
						_spawn_loot_point(key, true)
					else:
						loot_taken[key] = srv.unix - respawn * 0.5
	for id: int in pickups.keys():
		var e: Dictionary = pickups[id]
		if int(e.src) < 0 and srv.unix - float(e.t) > PICKUP_TTL and not player_near(e.pos, 20.0):
			take_pickup(id)
			break
	for id: int in harvest_ready.keys():
		if float(harvest_ready[id]) <= srv.unix:
			harvest_ready.erase(id)
			var node: Dictionary = srv.world.harvest_nodes[id]
			srv.obj_event(node.pos, Protocol.O_HARVEST, id, true)
			break
	var raining: bool = srv.env.rain > 0.3
	for s: Dictionary in structures.values():
		var t := String(s.type)
		if t == "hoguera" and int(s.stage) >= 1 and float(s.fuel) > 0.0 and float(s.fuel) <= srv.unix:
			s.fuel = 0.0
			update_structure(s)
		elif t == "colector" and int(s.stage) >= 1 and raining and int(s.water) < 5 and _rng.randf() < 0.02:
			s.water = int(s.water) + 1
			update_structure(s)
		elif t == "bulto" and srv.unix - float(s.t) > PICKUP_TTL:
			var c: Variant = containers.get(STRUCT_CONTAINER + int(s.id))
			if c == null or int(c.by) == 0:
				remove_structure(int(s.id))
				break

func spawn_initial_loot() -> void:
	for bi in srv.world.buildings.size():
		var pts: Array = (srv.world.buildings[bi].meta as Dictionary).get("loot", [])
		for li in pts.size():
			if _rng.randf() < 0.8:
				_spawn_loot_point(bi * 64 + li, false)
			else:
				loot_taken[bi * 64 + li] = srv.unix

# ---- persistencia ------------------------------------------------------------------------------------------------------------
func save_state() -> Dictionary:
	var cont: Dictionary = {}
	for k: int in containers.keys():
		var c: Dictionary = containers[k]
		cont[str(k)] = {"inv": (c.inv as Inventory).to_data(), "gen": c.gen, "table": c.table}
	var pk: Dictionary = {}
	for id: int in pickups.keys():
		var e: Dictionary = pickups[id]
		pk[str(id)] = [e.item, e.n, e.d, e.pos.x, e.pos.y, e.pos.z, e.src, e.t]
	var st: Array = []
	for s: Dictionary in structures.values():
		st.append({"id": s.id, "type": s.type, "pos": [s.pos.x, s.pos.y, s.pos.z], "yaw": s.yaw, "stage": s.stage, "owner": s.owner, "perm": s.perm,
			"fuel": s.fuel, "water": s.water, "open": s.open, "lock": s.lock, "t": s.t})
	var d_open: Array = []
	for k: int in doors.keys():
		if doors[k]:
			d_open.append(k)
	var taken: Dictionary = {}
	for k: int in loot_taken.keys():
		taken[str(k)] = loot_taken[k]
	var hv: Dictionary = {}
	for k: int in harvest_ready.keys():
		hv[str(k)] = harvest_ready[k]
	return {"unlocked": unlocked.keys(), "doors": d_open, "containers": cont, "pickups": pk, "structures": st, "loot_taken": taken, "harvest": hv, "next_drop": next_drop, "next_struct": next_struct, "init": true}

func load_state(d: Dictionary) -> void:
	if not bool(d.get("init", false)):
		spawn_initial_loot()
		return
	for k: Variant in d.get("doors", []) as Array:
		doors[int(k)] = true
	for k: Variant in d.get("unlocked", []) as Array:
		unlocked[String(k)] = true
	var cont: Dictionary = d.get("containers", {})
	for ks: String in cont.keys():
		var key := int(ks)
		var info := container_info(key)
		var c: Dictionary = cont[ks]
		var slots := int(info.get("slots", (c.get("inv", []) as Array).size()))
		containers[key] = {"inv": Inventory.from_data(c.get("inv"), slots), "gen": float(c.get("gen", 0.0)), "by": 0, "table": String(c.get("table", ""))}
	for s: Dictionary in d.get("structures", []) as Array:
		if not GameData.structures.has(String(s.get("type", ""))) and String(s.get("type", "")) != "bulto":
			continue
		var p: Array = s.get("pos", [0, 0, 0])
		var e := {"id": int(s.id), "type": String(s.type), "pos": Vector3(p[0], p[1], p[2]), "yaw": float(s.get("yaw", 0.0)), "stage": int(s.get("stage", 0)),
			"owner": String(s.get("owner", "")), "perm": int(s.get("perm", 1)), "fuel": float(s.get("fuel", 0.0)), "water": int(s.get("water", 0)),
			"open": bool(s.get("open", false)), "lock": bool(s.get("lock", false)), "t": float(s.get("t", 0.0))}
		structures[int(e.id)] = e
		_idx_add(_sector_structs, e.pos, int(e.id))
	var pk: Dictionary = d.get("pickups", {})
	for ks: String in pk.keys():
		var a: Array = pk[ks]
		if a.size() >= 8 and GameData.has_item(String(a[0])):
			var id := int(ks)
			pickups[id] = {"item": String(a[0]), "n": int(a[1]), "d": int(a[2]), "pos": Vector3(a[3], a[4], a[5]), "src": int(a[6]), "t": float(a[7])}
			_idx_add(_sector_pickups, pickups[id].pos, id)
	var taken: Dictionary = d.get("loot_taken", {})
	for ks: String in taken.keys():
		loot_taken[int(ks)] = float(taken[ks])
	var hv: Dictionary = d.get("harvest", {})
	for ks: String in hv.keys():
		harvest_ready[int(ks)] = float(hv[ks])
	next_drop = maxi(DROP_BASE, int(d.get("next_drop", DROP_BASE)))
	next_struct = maxi(1, int(d.get("next_struct", 1)))
