class_name ServerActions
extends RefCounted
## ServerActions — peticiones de juego validadas por el servidor.
##
## Responsabilidad: interacción contextual (puertas, recoger, recolectar, contenedores,
## descanso, agua, documentos), operaciones de inventario y equipo, fabricación y
## construcción. Cada petición comprueba identidad, alcance, línea de visión, estado previo,
## permisos y cantidades; el cliente solo recibe el resultado.
## Acciones con duración: se registran en ServerPlayer.action y se resuelven en tick();
## si el jugador se aleja, se desconecta o cancela, no se consume ni se concede nada.
## Prueba: tests/test_actions.gd y tests/net_session.sh.

var srv: GameServer
var ws: ServerWorld

func _init(server: GameServer) -> void:
	srv = server
	ws = server.ws

# ---- acciones con duración --------------------------------------------------------------------------
func _start(p: ServerPlayer, code: int, id: int, seconds: float, extra: Dictionary = {}) -> void:
	cancel_action(p, true)
	var a := {"code": code, "id": id, "end": srv.now_ms + int(seconds * 1000.0), "pos": p.pos}
	a.merge(extra)
	p.action = a
	srv.send(p, Protocol.S.ACTION, [code, id, seconds])

func cancel_action(p: ServerPlayer, silent: bool) -> void:
	if p.action.is_empty():
		return
	if int(p.action.code) == Protocol.T.HARVEST:
		ws.harvest_busy.erase(int(p.action.id))
	p.action = {}
	if not silent:
		srv.send(p, Protocol.S.ACTION, [Protocol.T.NONE, 0, 0.0])

func tick(_dt: float) -> void:
	for p: ServerPlayer in srv.players.values():
		if p.action.is_empty() or srv.now_ms < int(p.action.end):
			continue
		var a := p.action
		p.action = {}
		match int(a.code):
			Protocol.T.HARVEST: _finish_harvest(p, a)
			Protocol.T.CRAFT: _finish_craft(p, a)
			Protocol.T.BUILD: _finish_build(p, a)
			Protocol.T.DISMANTLE: _finish_dismantle(p, a)
			Protocol.T.REST: _finish_rest(p, a)
			Protocol.T.FILL: _finish_fill(p, a)
		srv.send(p, Protocol.S.ACTION, [Protocol.T.NONE, int(a.code), 0.0])

func give(p: ServerPlayer, item: String, n: int, d := -2) -> void:
	var left := p.inv.add(item, n, d)
	if left > 0:
		ws.drop_item(item, left, d, p.pos)
		srv.notify(p, "inv_full_dropped", {"item": item, "n": left})
	p.dirty_inv = true

# ---- interacción contextual ---------------------------------------------------------------------------
func on_interact(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var kind := Guard.i(d[0], 0, 64, 0)
	var id := Guard.i(d[1], -1000, 1 << 30, -1)
	var arg := Guard.s(d[2], 16) if d.size() > 2 else ""
	match kind:
		Protocol.I.DOOR: _door(p, id)
		Protocol.I.PICKUP: _pickup(p, id)
		Protocol.I.HARVEST: _harvest(p, id)
		Protocol.I.CONTAINER: _open_container(p, id)
		Protocol.I.DOC: _read_doc(p, id)
		Protocol.I.REST: _rest(p, id)
		Protocol.I.WATER_DRINK: _drink(p)
		Protocol.I.WATER_FILL: _fill(p, id)
		Protocol.I.STRUCT_USE: _struct_use(p, id, arg)
		Protocol.I.CONTRACT_BOARD: srv.progress.send_board(p)

func _unlock(p: ServerPlayer, lock_key: String, need: String) -> bool:
	if need == "" or ws.unlocked.has(lock_key):
		return true
	if not p.has_tool(need):
		srv.notify(p, "locked", {"item": need})
		return false
	ws.unlocked[lock_key] = true
	if need == "palanca":
		_wear_tool(p, "palanca", 10)
	srv.progress.count(p, "unlock:" + need)
	srv.notify(p, "unlocked", {"item": need})
	return true

func _wear_tool(p: ServerPlayer, tool_id: String, amount: int) -> void:
	var e: Variant = p.equip.get("mano")
	if e != null and String(e.id) == tool_id and int(e.d) > 0:
		e.d = int(e.d) - amount
		if int(e.d) <= 0:
			p.equip["mano"] = null
			srv.notify(p, "tool_broken", {"item": tool_id})
			srv.broadcast(Protocol.S.PLAYER_UPDATE, p.public_info())
		p.dirty_inv = true
		return
	for i in p.inv.size():
		var s: Variant = p.inv.slots[i]
		if s != null and String(s.id) == tool_id and int(s.d) > 0:
			s.d = int(s.d) - amount
			if int(s.d) <= 0:
				p.inv.slots[i] = null
				srv.notify(p, "tool_broken", {"item": tool_id})
			p.dirty_inv = true
			return

func _door(p: ServerPlayer, key: int) -> void:
	var bi := key / 64
	var di := key % 64
	if bi < 0 or bi >= srv.world.buildings.size():
		return
	var doors: Array = (srv.world.buildings[bi].meta as Dictionary).get("doors", [])
	if di >= doors.size():
		return
	var door: Dictionary = doors[di]
	var basis := Basis(Vector3.UP, deg_to_rad(float(door.yaw)))
	var center := srv.world.to_world(bi, DataFiles.v3(door.pos) + basis * Vector3(float(door.w) * 0.5, 1.0, 0))
	if not srv.can_reach(p, center):
		return
	if not _unlock(p, "d%d" % key, String(door.get("locked", ""))):
		return
	var open: bool = not ws.doors.get(key, false)
	if open:
		ws.doors[key] = true
	else:
		# no cerrar la puerta sobre alguien que está en el umbral
		for o: ServerPlayer in srv.players.values():
			if o.pos.distance_to(center - Vector3(0, 1.0, 0)) < 0.55:
				srv.notify(p, "door_blocked")
				return
		ws.doors.erase(key)
	srv.obj_event(center, Protocol.O_DOOR, key, open)
	srv.set_anim(p, Protocol.A.DOOR, 0.9)
	p.noise = maxf(p.noise, 8.0)

func _pickup(p: ServerPlayer, id: int) -> void:
	var e: Variant = ws.pickups.get(id)
	if e == null:
		srv.notify(p, "gone")
		return
	if not srv.can_reach(p, e.pos + Vector3(0, 0.1, 0)):
		return
	var room := p.inv.room_for(String(e.item))
	if room <= 0:
		srv.notify(p, "inv_full")
		return
	var taken := ws.take_pickup(id)            # a partir de aquí ya no existe para nadie más
	if taken.is_empty():
		return
	var n: int = mini(room, int(taken.n))
	p.inv.add(String(taken.item), n, int(taken.d))
	if n < int(taken.n):
		ws.drop_item(String(taken.item), int(taken.n) - n, int(taken.d), taken.pos)
	p.dirty_inv = true
	srv.set_anim(p, Protocol.A.PICKUP, 1.0)
	srv.progress.count(p, "pickups")
	srv.notify(p, "got", {"item": taken.item, "n": n})

func _harvest(p: ServerPlayer, id: int) -> void:
	if id < 0 or id >= srv.world.harvest_nodes.size():
		return
	var node: Dictionary = srv.world.harvest_nodes[id]
	var def: Dictionary = GameData.harvest.get(String(node.type), {})
	if def.is_empty():
		return
	if float(ws.harvest_ready.get(id, 0.0)) > srv.unix:
		srv.notify(p, "depleted")
		return
	var busy := int(ws.harvest_busy.get(id, 0))
	if busy != 0 and busy != p.peer and srv.players.has(busy):
		srv.notify(p, "busy")
		return
	if not srv.can_reach(p, node.pos + Vector3(0, 0.5, 0), float(def.get("radius", 1.0))):
		return
	var time := float(def.get("time", 2.5))
	if String(def.get("tool_bonus", "")) != "" and p.has_tool(String(def.tool_bonus)):
		time *= 0.55
	ws.harvest_busy[id] = p.peer
	_start(p, Protocol.T.HARVEST, id, time)
	srv.set_anim(p, Protocol.A.PICKUP if float(def.get("radius", 1.0)) < 1.0 else Protocol.A.SEARCH, time)
	p.noise = maxf(p.noise, 10.0)

func _finish_harvest(p: ServerPlayer, a: Dictionary) -> void:
	var id := int(a.id)
	ws.harvest_busy.erase(id)
	var node: Dictionary = srv.world.harvest_nodes[id]
	var def: Dictionary = GameData.harvest.get(String(node.type), {})
	if float(ws.harvest_ready.get(id, 0.0)) > srv.unix or p.pos.distance_to(node.pos) > Protocol.REACH + 3.0:
		return
	var bonus := int(p.perk("harvest", 0.0))
	for y: Array in def.get("yield", []):
		var n := randi_range(int(y[1]), int(y[2]))
		if n > 0:
			give(p, String(y[0]), n + bonus)
			srv.notify(p, "got", {"item": y[0], "n": n + bonus})
	if String(def.get("tool_bonus", "")) != "":
		_wear_tool(p, String(def.tool_bonus), 1)
	ws.harvest_ready[id] = srv.unix + float(def.get("regrow", 900.0))
	srv.obj_event(node.pos, Protocol.O_HARVEST, id, false)
	srv.progress.count(p, "harvests")
	srv.progress.add_xp(p, 2)

func _open_container(p: ServerPlayer, key: int) -> void:
	var info := ws.container_info(key)
	if info.is_empty() or not srv.can_reach(p, info.pos, 0.6):
		return
	if int(info.struct) >= 0:
		var s: Dictionary = ws.structures[int(info.struct)]
		if not srv.social.may_use(p, s):
			srv.notify(p, "no_permission")
			return
	elif not _unlock(p, "c%d" % key, String(info.locked)):
		return
	var c := ws.get_container(key)
	if c.is_empty():
		return
	var by := int(c.by)
	if by != 0 and by != p.peer and srv.players.has(by):
		srv.notify(p, "busy")
		return
	ws.close_container(p)
	c.by = p.peer
	p.container = key
	srv.send(p, Protocol.S.CONTAINER, {"key": key, "slots": (c.inv as Inventory).to_data()})
	srv.obj_event(info.pos, Protocol.O_CONTAINER, key, true)
	srv.set_anim(p, Protocol.A.SEARCH, 1.8)

func _read_doc(p: ServerPlayer, bi: int) -> void:
	var doc_id := ""
	var where := Vector3.ZERO
	if bi >= 0 and bi < srv.world.buildings.size():
		doc_id = String((srv.world.buildings[bi].meta as Dictionary).get("doc", ""))
		where = srv.world.buildings[bi].pos
		if p.pos.distance_to(where) > float(srv.world.buildings[bi].radius) + 2.0:
			return
	elif bi == -1:                # tablón de El Collado
		doc_id = "aviso_tablon"
		if not ws.station_near(p, "contracts"):
			return
	if doc_id == "" or not GameData.documents.has(doc_id):
		return
	var first := not p.docs.has(doc_id)
	p.docs[doc_id] = true
	srv.send(p, Protocol.S.DOC, {"id": doc_id, "first": first})
	if first:
		srv.progress.count(p, "docs")
		srv.progress.add_xp(p, 15)
		srv.progress.on_doc(p, doc_id)

func _struct_checked(p: ServerPlayer, sid: int, need_done := true) -> Dictionary:
	var s: Variant = ws.structures.get(sid)
	if s == null or (need_done and int(s.stage) < 1):
		return {}
	if not srv.can_reach(p, s.pos + Vector3(0, 0.6, 0), 1.2):
		return {}
	return s

func _rest(p: ServerPlayer, sid: int) -> void:
	var s := _struct_checked(p, sid)
	if s.is_empty() or not bool((GameData.structures.get(String(s.type), {}) as Dictionary).get("rest", false)):
		return
	if not srv.social.may_use(p, s):
		srv.notify(p, "no_permission")
		return
	_start(p, Protocol.T.REST, sid, 10.0)
	srv.set_anim(p, Protocol.A.REST, 10.0)

func _finish_rest(p: ServerPlayer, a: Dictionary) -> void:
	var s: Variant = ws.structures.get(int(a.id))
	if s == null:
		return
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	p.fatigue = maxf(0.0, p.fatigue - (55.0 if bool(def.get("respawn", false)) else 35.0))
	p.add_effect("descansado", 600.0)
	if bool(def.get("respawn", false)):
		p.respawn = s.pos
		p.respawn_set = true
		srv.notify(p, "respawn_set")
	p.dirty_stats = true
	srv.send(p, Protocol.S.PROGRESS, p.progress_packet())

func _water_quality(p: ServerPlayer) -> int:
	# 0 = no hay agua, 1 = río/marjal (turbia), 2 = pozo/bomba/fuente (mejor), 3 = colector (lluvia)
	for s: Dictionary in ws.structures_near(p.pos, 3.5):
		if String(s.type) == "colector" and int(s.stage) >= 1 and int(s.water) > 0:
			return 3
	for pi: int in srv.world.sector_props(WorldMap.sector_key(p.pos.x, p.pos.z)):
		var pr: Dictionary = srv.world.props[pi]
		if (pr.pos as Vector3).distance_to(p.pos) < 4.5 and String(DataFiles.prop(String(pr.model)).get("station", "")) == "water":
			return 2
	return 1 if srv.world.near_water(p.pos.x, p.pos.z) else 0

func _drink(p: ServerPlayer) -> void:
	var q := _water_quality(p)
	if q == 0:
		return
	if q == 3:
		_take_collector(p)
	p.water = minf(100.0, p.water + 25.0)
	if randf() < [0.0, 0.5, 0.15, 0.0][q]:
		p.add_effect("malestar", 120.0)
	p.dirty_stats = true
	srv.set_anim(p, Protocol.A.CONSUME, 1.6)

func _take_collector(p: ServerPlayer) -> void:
	for s: Dictionary in ws.structures_near(p.pos, 3.5):
		if String(s.type) == "colector" and int(s.water) > 0:
			s.water = int(s.water) - 1
			ws.update_structure(s)
			return

func _fill(p: ServerPlayer, _id: int) -> void:
	if _water_quality(p) == 0:
		return
	if p.inv.count("botella_vacia") <= 0:
		srv.notify(p, "need", {"item": "botella_vacia"})
		return
	_start(p, Protocol.T.FILL, 0, 1.5)
	srv.set_anim(p, Protocol.A.PICKUP, 1.5)

func _finish_fill(p: ServerPlayer, _a: Dictionary) -> void:
	var q := _water_quality(p)
	if q == 0 or not p.inv.remove("botella_vacia", 1):
		return
	if q == 3:
		_take_collector(p)
	give(p, "agua_potable" if q == 3 else "agua_turbia", 1)
	srv.notify(p, "got", {"item": "agua_potable" if q == 3 else "agua_turbia", "n": 1})

func _struct_use(p: ServerPlayer, sid: int, op: String) -> void:
	var s := _struct_checked(p, sid)
	if s.is_empty():
		return
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	match op:
		"fuel":
			if not def.has("fuel"):
				return
			if not p.inv.remove(String(def.fuel), 1):
				srv.notify(p, "need", {"item": def.fuel})
				return
			s.fuel = minf(srv.unix + 1800.0, maxf(float(s.fuel), srv.unix) + float(def.get("burn", 300.0)))
			p.dirty_inv = true
			ws.update_structure(s)
		"toggle":
			if not bool(def.get("door", false)):
				return
			if bool(s.lock) and not srv.social.may_use(p, s):
				srv.notify(p, "no_permission")
				return
			s.open = not bool(s.open)
			ws.update_structure(s)
			srv.set_anim(p, Protocol.A.DOOR, 0.9)
		"lock":
			if bool(def.get("door", false)) and String(s.owner) == p.account:
				s.lock = not bool(s.lock)
				ws.update_structure(s)

# ---- inventario -----------------------------------------------------------------------------------------
func _inv_of(p: ServerPlayer, which: int) -> Inventory:
	if which == 0:
		return p.inv
	if which == 1 and p.container >= 0:
		var c: Variant = ws.containers.get(p.container)
		if c != null and int(c.by) == p.peer:
			var info := ws.container_info(p.container)
			if not info.is_empty() and p.pos.distance_to(info.pos) < Protocol.REACH + 3.0:
				return c.inv
	return null

func _refresh_container(p: ServerPlayer) -> void:
	if p.container >= 0 and ws.containers.has(p.container):
		srv.send(p, Protocol.S.CONTAINER, {"key": p.container, "slots": (ws.containers[p.container].inv as Inventory).to_data()})

func on_inv_move(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var src := _inv_of(p, Guard.i(d[0], 0, 1, 0))
	var dst := _inv_of(p, Guard.i(d[2], 0, 1, 0))
	if src == null or dst == null:
		srv.notify(p, "container_closed")
		return
	var i := Guard.i(d[1], 0, 255, -1)
	var j := Guard.i(d[3], -1, 255, -1)
	var st: Variant = src.get_slot(i)
	if st == null:
		p.dirty_inv = true
		return
	var n := Guard.i(d[4], 1, 999, int(st.n))
	if not Inventory.transfer(src, i, dst, j, mini(n, int(st.n))):
		srv.notify(p, "no_room")
	p.dirty_inv = true
	_refresh_container(p)

func on_split(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	if not p.inv.split(Guard.i(d[0], 0, 255, -1), Guard.i(d[1], 1, 999, 0)):
		srv.notify(p, "no_room")
	p.dirty_inv = true

func on_drop(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var i := Guard.i(d[0], 0, 255, -1)
	var st: Variant = p.inv.get_slot(i)
	if st == null:
		return
	var n: int = mini(Guard.i(d[1], 1, 999, 1), int(st.n))
	var item := String(st.id)
	var dur := int(st.d)
	st.n = int(st.n) - n
	if int(st.n) <= 0:
		p.inv.slots[i] = null
	var fwd := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var at := p.pos + fwd * 0.8
	if srv.world.segment_blocked(p.pos + Vector3(0, 0.9, 0), at + Vector3(0, 0.9, 0), srv.door_open):
		at = p.pos
	ws.drop_item(item, n, dur, at)
	p.dirty_inv = true

func on_quick_set(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var idx := Guard.i(d[0], 0, 3, 0)
	var id := Guard.s(d[1], 32)
	p.quick[idx] = id if (id == "" or GameData.has_item(id)) else ""
	p.dirty_inv = true

func on_inv_use(p: ServerPlayer, i: int) -> void:
	var st: Variant = p.inv.get_slot(i)
	if st == null:
		return
	var id := String(st.id)
	var def := GameData.item(id)
	var use: Dictionary = def.get("use", {})
	if use.has("deter"):
		srv.creatures.deter(p, float(use.deter))
		st.d = int(st.d) - 1
		if int(st.d) <= 0:
			p.inv.slots[i] = null
			srv.notify(p, "tool_broken", {"item": id})
		p.noise = 40.0
		p.dirty_inv = true
		srv.set_anim(p, Protocol.A.WAVE, 1.0)
		srv.send_near(p.pos, 60.0, Protocol.S.EMOTE, [p.peer, 100])
		return
	if not use.is_empty():
		srv.survival.apply_use(p, use)
		st.n = int(st.n) - 1
		if int(st.n) <= 0:
			p.inv.slots[i] = null
		if def.has("gives"):
			give(p, String(def.gives), 1)
		p.dirty_inv = true
		srv.set_anim(p, Protocol.A.CONSUME, 1.7)
		srv.notify(p, "used", {"item": id})
		return
	# recambio/combustible de algo que llevas (pilas -> linterna, filtro -> mascarilla, liquen -> farol)
	var target: Variant = _fuel_target(p, id)
	if target != null:
		var mx := int(GameData.item(String(target.id)).get("dur", 100))
		target.d = mini(mx, int(target.d) + int(ceil(float(mx) * 0.6)))
		st.n = int(st.n) - 1
		if int(st.n) <= 0:
			p.inv.slots[i] = null
		p.dirty_inv = true
		srv.notify(p, "refilled", {"item": target.id})
		return
	if def.has("equip"):
		on_equip(p, i)

func _fuel_target(p: ServerPlayer, fuel: String) -> Variant:
	for s in ServerPlayer.EQUIP_SLOTS:
		var e: Variant = p.equip.get(s)
		if e != null and String(GameData.item(String(e.id)).get("fuel", "")) == fuel and int(e.d) < int(GameData.item(String(e.id)).get("dur", 100)):
			return e
	for st: Variant in p.inv.slots:
		if st != null and String(GameData.item(String(st.id)).get("fuel", "")) == fuel and int(st.d) < int(GameData.item(String(st.id)).get("dur", 100)):
			return st
	return null

func on_equip(p: ServerPlayer, i: int) -> void:
	var st: Variant = p.inv.get_slot(i)
	if st == null:
		return
	var eq: Dictionary = GameData.item(String(st.id)).get("equip", {})
	var slot := String(eq.get("slot", ""))
	if slot == "":
		return
	var old: Variant = p.equip.get(slot)
	p.equip[slot] = {"id": String(st.id), "n": 1, "d": int(st.d)}
	p.inv.slots[i] = old
	_after_equip_change(p)

func on_unequip(p: ServerPlayer, slot: String) -> void:
	if not (slot in ServerPlayer.EQUIP_SLOTS):
		return
	var e: Variant = p.equip.get(slot)
	if e == null:
		return
	p.equip[slot] = null
	var new_size := p.slot_count()
	if p.inv.used() + 1 > new_size:
		p.equip[slot] = e
		srv.notify(p, "no_room")
		return
	for st: Dictionary in p.inv.resize(new_size):
		ws.drop_item(String(st.id), int(st.n), int(st.d), p.pos)
	p.inv.add(String(e.id), 1, int(e.d))
	_after_equip_change(p)

func _after_equip_change(p: ServerPlayer) -> void:
	for st: Dictionary in p.inv.resize(p.slot_count()):
		ws.drop_item(String(st.id), int(st.n), int(st.d), p.pos)
		srv.notify(p, "inv_full_dropped", {"item": st.id, "n": st.n})
	p.dirty_inv = true
	p.dirty_stats = true
	srv.broadcast(Protocol.S.PLAYER_UPDATE, p.public_info())

# ---- fabricación ---------------------------------------------------------------------------------------------
## Motivo por el que no se puede fabricar ("" si se puede).
func craft_block(p: ServerPlayer, r: Dictionary) -> String:
	if r.is_empty():
		return "unknown"
	if p.level() < int(r.get("level", 0)):
		return "level"
	if not ws.station_near(p, String(r.get("station", ""))):
		return "station"
	if not p.has_tool(String(r.get("tool", ""))):
		return "tool"
	if not p.inv.has_all(r.get("in", {})):
		return "ingredients"
	var probe := Inventory.from_data(p.inv.to_data(), p.inv.size())
	probe.remove_all(r.get("in", {}))
	if probe.room_for(String(r.out)) < int(r.n):
		return "room"
	return ""

func on_craft(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var rid := Guard.s(d[0], 40)
	var count := Guard.i(d[1], 1, 5, 1) if d.size() > 1 else 1
	var r: Dictionary = GameData.recipes.get(rid, {})
	var why := craft_block(p, r)
	if why != "":
		srv.notify(p, "craft_fail", {"why": why, "recipe": rid})
		return
	_start(p, Protocol.T.CRAFT, 0, float(r.get("time", 3.0)) * float(count), {"recipe": rid, "count": count})
	srv.set_anim(p, Protocol.A.SEARCH, float(r.get("time", 3.0)) * float(count))

func _finish_craft(p: ServerPlayer, a: Dictionary) -> void:
	var r: Dictionary = GameData.recipes.get(String(a.recipe), {})
	var made := 0
	for k in int(a.count):
		if craft_block(p, r) != "":
			break
		p.inv.remove_all(r.get("in", {}))           # ingredientes y resultado en el mismo paso del servidor
		p.inv.add(String(r.out), int(r.n))
		if String(r.get("tool", "")) != "":
			_wear_tool(p, String(r.tool), 1)
		made += 1
	p.dirty_inv = true
	if made > 0:
		srv.notify(p, "crafted", {"item": r.out, "n": int(r.n) * made})
		srv.progress.count(p, "crafts", float(made))
		srv.progress.add_xp(p, 4 * made)
	else:
		srv.notify(p, "craft_fail", {"why": craft_block(p, r), "recipe": a.recipe})

# ---- construcción -----------------------------------------------------------------------------------------------
## Motivo por el que no se puede colocar ("" si es válido).
func place_block(p: ServerPlayer, type: String, pos: Vector3, def: Dictionary) -> String:
	if def.is_empty():
		return "unknown"
	if ws.structures.size() >= int(srv.options.max_structures) or ws.count_owned(p.account) >= int(srv.options.max_structures_player):
		return "limit"
	if Vector2(pos.x - p.pos.x, pos.z - p.pos.z).length() > 7.5:
		return "far"
	if not srv.world.in_bounds(pos.x, pos.z, 6.0):
		return "bounds"
	var flags := srv.world.cell_flags(pos.x, pos.z)
	var snap := bool(def.get("snap", false))
	var base: Dictionary = {}
	for s: Dictionary in ws.structures_near(pos, 3.2):
		var od: Dictionary = GameData.structures.get(String(s.type), {})
		var dist := Vector2(pos.x - s.pos.x, pos.z - s.pos.z).length()
		if String(s.type) == "suelo" and dist < 2.0:
			base = s
		var min_d := 0.35 if (snap and bool(od.get("snap", false))) else (float(def.get("radius", 1.0)) + float(od.get("radius", 1.0))) * 0.8
		if dist < min_d and not (snap and String(s.type) == "suelo") and not (type == "tejado"):
			return "overlap"
	if flags & WorldMap.F_BUILDING != 0 and srv.world.building_at(pos + Vector3(0, 0.5, 0)) < 0 and base.is_empty():
		return "blocked"
	if flags & WorldMap.F_ROAD != 0 and not snap:
		return "road"
	var g := srv.world.ground(pos.x, pos.z)
	if srv.world.height(pos.x, pos.z) < srv.world.water_level - 0.1 and flags & WorldMap.F_DECK == 0:
		return "water"
	var top := g + (2.9 if not base.is_empty() or type == "tejado" else 0.6)
	if pos.y < g - 0.6 or pos.y > top:
		return "height"
	if base.is_empty() and type != "tejado" and srv.world.slope_deg(pos.x, pos.z) > 28.0:
		return "slope"
	if srv.world.segment_blocked(srv.eye(p), pos + Vector3(0, 0.8, 0), srv.door_open):
		return "sight"
	if not p.inv.has_all(def.get("frame_cost", {})):
		return "materials"
	return ""

func on_build_place(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var type := Guard.s(d[0], 24)
	var pv: Variant = Guard.v3(d[1], d[2], d[3])
	if pv == null:
		return
	var yaw := Guard.f(d[4], -720.0, 720.0, 0.0)
	var def: Dictionary = GameData.structures.get(type, {})
	var why := place_block(p, type, pv, def)
	if why == "" and bool(def.get("instant", false)) and not p.inv.has_all(def.get("cost", {})):
		why = "materials"
	if why != "":
		srv.notify(p, "build_fail", {"why": why})
		return
	p.inv.remove_all(def.get("frame_cost", {}))
	var stage := 0
	if bool(def.get("instant", false)):
		p.inv.remove_all(def.get("cost", {}))
		stage = 1
	p.dirty_inv = true
	var s := ws.add_structure(type, pv, yaw, p.account, stage)
	srv.set_anim(p, Protocol.A.BUILD, 1.2)
	p.noise = maxf(p.noise, 12.0)
	if stage == 1:
		_on_completed(p, s)

func on_build_advance(p: ServerPlayer, sid: int) -> void:
	var s := _struct_checked(p, sid, false)
	if s.is_empty() or int(s.stage) >= 1:
		return
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	if String(s.owner) != p.account and not srv.social.same_group(p, String(s.owner)):
		srv.notify(p, "no_permission")
		return
	if not p.has_tool(String(def.get("tool", ""))):
		srv.notify(p, "need", {"item": def.get("tool", "")})
		return
	if not p.inv.has_all(def.get("cost", {})):
		srv.notify(p, "build_fail", {"why": "materials"})
		return
	_start(p, Protocol.T.BUILD, sid, 3.0)
	srv.set_anim(p, Protocol.A.BUILD, 3.0)
	p.noise = maxf(p.noise, 16.0)

func _finish_build(p: ServerPlayer, a: Dictionary) -> void:
	var s: Variant = ws.structures.get(int(a.id))
	if s == null or int(s.stage) >= 1:
		return
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	if not p.inv.remove_all(def.get("cost", {})):
		srv.notify(p, "build_fail", {"why": "materials"})
		return
	p.dirty_inv = true
	if String(def.get("tool", "")) != "":
		_wear_tool(p, String(def.tool), 2)
	s.stage = 1
	_on_completed(p, s)
	ws.update_structure(s)

func _on_completed(p: ServerPlayer, s: Dictionary) -> void:
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	if def.has("burn"):
		s.fuel = srv.unix + float(def.burn)
		ws.update_structure(s)
	srv.progress.count(p, "builds")
	srv.progress.count(p, "built_" + String(s.type))
	if String(s.owner) != p.account:
		srv.progress.count(p, "group_builds")
	srv.progress.add_xp(p, 10)
	srv.notify(p, "built", {"type": s.type})

func on_build_dismantle(p: ServerPlayer, sid: int) -> void:
	var s := _struct_checked(p, sid, false)
	if s.is_empty():
		return
	if String(s.type) == "bulto":
		return
	if String(s.owner) != p.account and not (int(s.perm) >= 1 and srv.social.same_group(p, String(s.owner))):
		srv.notify(p, "no_permission")
		return
	var c: Variant = ws.containers.get(ServerWorld.STRUCT_CONTAINER + sid)
	if c != null and (not (c.inv as Inventory).is_empty() or int(c.by) != 0):
		srv.notify(p, "not_empty")
		return
	_start(p, Protocol.T.DISMANTLE, sid, 3.0)
	srv.set_anim(p, Protocol.A.BUILD, 3.0)

func _finish_dismantle(p: ServerPlayer, a: Dictionary) -> void:
	var s: Variant = ws.structures.get(int(a.id))
	if s == null:
		return
	var def: Dictionary = GameData.structures.get(String(s.type), {})
	var back: Dictionary = {}
	for id: String in (def.get("frame_cost", {}) as Dictionary).keys():
		back[id] = int(def.frame_cost[id])
	if int(s.stage) >= 1:
		for id: String in (def.get("cost", {}) as Dictionary).keys():
			back[id] = int(back.get(id, 0)) + int(def.cost[id])
	ws.remove_structure(int(s.id))
	for id: String in back.keys():
		var n := int(back[id]) / 2
		if n > 0:
			give(p, id, n)
	srv.notify(p, "dismantled", {"type": s.type})

func on_build_perm(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var s: Variant = ws.structures.get(Guard.i(d[0], 0, 1 << 30, -1))
	if s == null or String(s.owner) != p.account:
		return
	s.perm = Guard.i(d[1], 0, 2, 1)
	ws.update_structure(s)
