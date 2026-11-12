extends Node
## Session — espejo en el cliente del estado que envía el servidor (autoload).
##
## Responsabilidad: recibir los mensajes S del Protocol, mantener copias de solo lectura
## (estadísticas, inventario, objetos del mundo, clima, grupo, progresión) y avisar a la
## interfaz y al mundo mediante señales. Nunca decide resultados: las funciones request_*
## solo envían peticiones. Persistencia: ninguna (todo vive en el servidor).

signal welcomed()
signal rejected(code: String)
signal stats_changed()
signal inventory_changed()
signal container_opened(key: int)
signal container_changed()
signal container_closed()
signal env_changed()
signal objects_received(sectors: Array)
signal object_event(kind: int, id: int, state: Variant)
signal notified(code: String, params: Dictionary)
signal progress_changed()
signal group_changed()
signal group_invite(gid: int, from: String)
signal chat_received(channel: int, peer: int, pname: String, text: String)
signal emote_received(peer: int, code: int)
signal mark_received(peer: int, pname: String, pos: Vector3)
signal trade_offer(offer: Dictionary)
signal action_changed(code: int, id: int, seconds: float)
signal corrected(seq: int, pos: Vector3, why: String)
signal snapshot(server_ms: int, players: Array, creatures: Array)
signal roster_changed()
signal went_down(wait: float)
signal respawned(pos: Vector3)
signal document_opened(id: String, first: bool)

var active := false
var my_id := 0
var my_name := ""
var server_name := ""
var difficulty := "normal"
var first_time := false
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0
var stats: Dictionary = {"hp": 100.0, "food": 80.0, "water": 80.0, "sta": 100.0, "temp": 0.0, "fat": 10.0, "wet": 0.0, "eff": [], "w": 0.0, "wmax": 22.0, "down": false}
var inv: Inventory = Inventory.new(12)
var equip: Dictionary = {}
var quick: Array = ["", "", "", ""]
var container_key := -1
var container_inv: Inventory = null
var env: Dictionary = {"day": 1, "hour": 9.0, "len": 2400.0, "w": "despejado", "cloud": 0.2, "fog": 0.05, "rain": 0.0, "wind": 0.3, "dir": 0.9}
var env_local_ms := 0
var roster: Dictionary = {}
var progress: Dictionary = {"xp": 0, "level": 1, "places": [], "docs": [], "stats": {}, "done": [], "contracts": {}, "respawn": null, "days": 0.0}
var group: Dictionary = {"id": 0, "members": []}
var group_pos: Array = []
var marks: Array = []
var global_chat := true
# ---- objetos del mundo ----
var open_doors: Dictionary = {}
var open_containers: Dictionary = {}
var pickups: Dictionary = {}       # id -> {item, n, pos}
var depleted: Dictionary = {}
var structs: Dictionary = {}       # id -> {id, type, pos, yaw, stage, owner, perm, lit, water, open, lock}
var action: Dictionary = {"code": 0, "id": 0, "end_ms": 0, "seconds": 0.0}
var last_board: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.message.connect(_on_message)
	Net.state_changed.connect(_on_net_state)

func _on_net_state(state: int) -> void:
	if state == Net.State.HANDSHAKE:
		Net.send(Protocol.C.HELLO, {"v": Protocol.VERSION, "account": Profile.account, "token": Profile.token, "name": Profile.player_name, "cos": Profile.cosmetics})
	elif state == Net.State.OFFLINE:
		active = false

func reset() -> void:
	active = false
	roster.clear(); open_doors.clear(); open_containers.clear(); pickups.clear(); depleted.clear(); structs.clear(); marks.clear()
	container_key = -1
	container_inv = null
	group = {"id": 0, "members": []}
	group_pos = []

## Hora del día interpolada localmente entre mensajes del servidor.
func hour_now() -> float:
	var el := float(Time.get_ticks_msec() - env_local_ms) / 1000.0
	return fposmod(float(env.hour) + el * 24.0 / maxf(120.0, float(env.len)), 24.0)

func is_night() -> bool:
	var h := hour_now()
	return h < 6.2 or h > 20.6

func has_effect(id: String) -> bool:
	for e: Array in stats.get("eff", []):
		if String(e[0]) == id:
			return true
	return false

func equipped(slot: String) -> String:
	var e: Variant = equip.get(slot)
	return String(e[0]) if e is Array else ""

func equipped_charge(slot: String) -> int:
	var e: Variant = equip.get(slot)
	return int(e[2]) if e is Array else 0

func has_item(id: String) -> bool:
	if inv.count(id) > 0:
		return true
	for s: String in equip.keys():
		if equipped(s) == id:
			return true
	return false

func struct_from(a: Array) -> Dictionary:
	return {"id": int(a[0]), "type": String(a[1]), "pos": Vector3(a[2], a[3], a[4]), "yaw": float(a[5]), "stage": int(a[6]), "owner": String(a[7]), "perm": int(a[8]),
		"lit": bool(a[9]), "water": int(a[10]), "open": bool(a[11]), "lock": bool(a[12])}

func is_mine(s: Dictionary) -> bool:
	return String(s.owner) == Profile.account.left(8)

func _on_message(id: int, data: Variant) -> void:
	match id:
		Protocol.S.WELCOME:
			var d: Dictionary = data
			reset()
			my_id = int(d.id)
			my_name = String(d.name)
			server_name = String(d.server)
			difficulty = String(d.difficulty)
			first_time = bool(d.first)
			global_chat = bool(d.get("global_chat", true))
			spawn_pos = Vector3(d.pos[0], d.pos[1], d.pos[2])
			spawn_yaw = float(d.yaw)
			_set_env(d.env)
			for r: Dictionary in d.roster:
				roster[int(r.id)] = r
			stats = d.stats
			_set_inv(d.inv)
			progress = d.progress
			group = d.group
			Profile.cosmetics = d.cos
			active = true
			Net.mark_online()
			welcomed.emit()
			roster_changed.emit()
		Protocol.S.REJECT:
			rejected.emit(String((data as Dictionary).get("c", "")))
		Protocol.S.SNAPSHOT:
			snapshot.emit(int(data[0]), data[1], data[2])
		Protocol.S.PLAYER_JOIN, Protocol.S.PLAYER_UPDATE:
			roster[int(data.id)] = data
			roster_changed.emit()
		Protocol.S.PLAYER_LEAVE:
			roster.erase(int(data.id))
			roster_changed.emit()
		Protocol.S.CORRECT:
			corrected.emit(int(data[0]), Vector3(data[1], data[2], data[3]), String(data[4]))
		Protocol.S.STATS:
			stats = data
			stats_changed.emit()
		Protocol.S.INV:
			_set_inv(data)
			inventory_changed.emit()
		Protocol.S.CONTAINER:
			var opened := container_key != int(data.key)
			container_key = int(data.key)
			container_inv = Inventory.from_data(data.slots, (data.slots as Array).size())
			if opened:
				container_opened.emit(container_key)
			container_changed.emit()
		Protocol.S.CONTAINER_CLOSED:
			container_key = -1
			container_inv = null
			container_closed.emit()
		Protocol.S.OBJECTS:
			_on_objects(data)
		Protocol.S.OBJ_EVENT:
			_on_obj_event(int(data[0]), int(data[1]), data[2])
		Protocol.S.ENV:
			_set_env(data)
			env_changed.emit()
		Protocol.S.NOTIFY:
			if String(data.c) == "board":
				last_board = data.p
			notified.emit(String(data.c), data.p)
		Protocol.S.PROGRESS:
			progress = data
			progress_changed.emit()
		Protocol.S.GROUP:
			var g: Dictionary = data
			if g.has("invite"):
				group_invite.emit(int(g.invite), String(g.from))
			elif g.has("pos"):
				group_pos = g.pos
			else:
				group = g
				group_changed.emit()
		Protocol.S.CHAT:
			if not Profile.muted.has(String(data[2])):
				chat_received.emit(int(data[0]), int(data[1]), String(data[2]), String(data[3]))
		Protocol.S.EMOTE:
			emote_received.emit(int(data[0]), int(data[1]))
		Protocol.S.MARK:
			var m := {"peer": int(data[0]), "name": String(data[1]), "pos": Vector3(data[2], data[3], data[4]), "ms": Time.get_ticks_msec()}
			marks.append(m)
			if marks.size() > 6:
				marks.pop_front()
			mark_received.emit(int(m.peer), String(m.name), m.pos)
		Protocol.S.TRADE:
			trade_offer.emit(data)
		Protocol.S.ACTION:
			action = {"code": int(data[0]), "id": int(data[1]), "seconds": float(data[2]), "end_ms": Time.get_ticks_msec() + int(float(data[2]) * 1000.0)}
			action_changed.emit(int(data[0]), int(data[1]), float(data[2]))
		Protocol.S.DOWN:
			went_down.emit(float(data.wait))
		Protocol.S.RESPAWNED:
			respawned.emit(Vector3(data.pos[0], data.pos[1], data.pos[2]))
		Protocol.S.DOC:
			document_opened.emit(String(data.id), bool(data.first))

func _set_env(e: Dictionary) -> void:
	env = e
	env_local_ms = Time.get_ticks_msec()

func _set_inv(d: Dictionary) -> void:
	inv = Inventory.from_data(d.slots, (d.slots as Array).size())
	equip = d.equip
	quick = d.quick

func _on_objects(d: Dictionary) -> void:
	var keep: Dictionary = {}
	for k: Variant in d.keep:
		keep[int(k)] = true
	# olvida lo que queda fuera del conjunto de interés
	for id: int in pickups.keys():
		var pp: Vector3 = pickups[id].pos
		if not keep.has(WorldMap.sector_key(pp.x, pp.z)):
			pickups.erase(id)
	for id: int in structs.keys():
		var sp: Vector3 = structs[id].pos
		if not keep.has(WorldMap.sector_key(sp.x, sp.z)):
			structs.erase(id)
	var keys: Array = []
	for s: Dictionary in d.sectors:
		keys.append(int(s.k))
		for dk: Variant in s.doors:
			open_doors[int(dk)] = true
		for p: Array in s.pickups:
			pickups[int(p[0])] = {"item": String(p[1]), "n": int(p[2]), "pos": Vector3(p[3], p[4], p[5])}
		for h: Variant in s.harvest:
			depleted[int(h)] = true
		for st: Array in s.structs:
			structs[int(st[0])] = struct_from(st)
	objects_received.emit(keys)

func _on_obj_event(kind: int, id: int, state: Variant) -> void:
	match kind:
		Protocol.O_DOOR:
			if bool(state):
				open_doors[id] = true
			else:
				open_doors.erase(id)
		Protocol.O_CONTAINER:
			if bool(state):
				open_containers[id] = true
			else:
				open_containers.erase(id)
		Protocol.O_PICKUP:
			if state == null:
				pickups.erase(id)
			else:
				pickups[id] = {"item": String(state[0]), "n": int(state[1]), "pos": Vector3(state[2], state[3], state[4])}
		Protocol.O_HARVEST:
			if bool(state):
				depleted.erase(id)
			else:
				depleted[id] = true
		Protocol.O_STRUCT:
			if state == null:
				structs.erase(id)
			else:
				structs[id] = struct_from(state)
	object_event.emit(kind, id, state)

# ---- peticiones (el servidor decide) ------------------------------------------------------------------
func request_interact(kind: int, id: int, arg := "") -> void:
	Net.send(Protocol.C.INTERACT, [kind, id, arg])

func request_move_item(src_c: int, src_slot: int, dst_c: int, dst_slot: int, count: int) -> void:
	Net.send(Protocol.C.INV_MOVE, [src_c, src_slot, dst_c, dst_slot, count])

func request_use(slot: int) -> void:
	Net.send(Protocol.C.INV_USE, slot)

func request_equip(slot: int) -> void:
	Net.send(Protocol.C.INV_EQUIP, slot)

func request_unequip(slot_name: String) -> void:
	Net.send(Protocol.C.INV_UNEQUIP, slot_name)

func request_drop(slot: int, count: int) -> void:
	Net.send(Protocol.C.INV_DROP, [slot, count])

func request_split(slot: int, count: int) -> void:
	Net.send(Protocol.C.INV_SPLIT, [slot, count])

func request_craft(recipe: String, count := 1) -> void:
	Net.send(Protocol.C.CRAFT, [recipe, count])

func close_container() -> void:
	if container_key >= 0:
		Net.send(Protocol.C.CONTAINER_CLOSE)

## Motivo local (orientativo) por el que una receta no se puede fabricar; el servidor revalida.
func recipe_block(r: Dictionary) -> String:
	if int(progress.get("level", 1)) < int(r.get("level", 0)):
		return "level"
	var tool := String(r.get("tool", ""))
	if tool != "" and not has_item(tool):
		return "tool"
	if not inv.has_all(r.get("in", {})):
		return "ingredients"
	return ""
