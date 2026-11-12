extends Node
## Cliente automático de pruebas de red (sin interfaz). Usa el MISMO transporte y protocolo
## que el juego: se conecta por ENet a un servidor real y registra lo que el servidor decide.
## Uso: godot --headless --path . -- --bot=<duo_a|duo_b|verify|reconnect> --connect=host:puerto --name=Nombre
## Cada línea "BOT|nombre|evento|json" la interpreta tests/net_session.sh.

const P := Vector3(262.0, 0.0, 1004.0)

var a: Dictionary = {}
var me := "bot"
var pos := Vector3.ZERO
var yaw := 0.0
var seq := 0
var corrections: Array = []
var notes: Array = []
var welcomed := false
var failed := false

func out(event: String, data: Variant = null) -> void:
	print("BOT|%s|%s|%s" % [me, event, JSON.stringify(data)])

func run(args: Dictionary) -> void:
	a = args
	me = String(a.get("name", "Bot"))
	Profile.use_test_identity(me, me)
	Session.welcomed.connect(func() -> void:
		welcomed = true
		pos = Session.spawn_pos)
	Session.rejected.connect(func(code: String) -> void:
		out("REJECTED", code)
		_quit(2))
	Session.corrected.connect(func(s: int, p: Vector3, why: String) -> void:
		corrections.append(why)
		pos = p)
	Session.notified.connect(func(code: String, params: Dictionary) -> void:
		notes.append(code)
		out("NOTE", {"c": code, "p": params}))
	Net.failed.connect(func(reason: String) -> void:
		out("CONNECT_FAILED", reason)
		_quit(3))
	var hp := String(a.get("connect", "127.0.0.1:24680")).split(":")
	Net.join(hp[0], int(hp[1]) if hp.size() > 1 else Protocol.DEFAULT_PORT)
	get_tree().create_timer(float(a.get("timeout", 70.0))).timeout.connect(func() -> void:
		out("TIMEOUT")
		_quit(4))
	await _until(func() -> bool: return welcomed, 15.0)
	if not welcomed:
		return
	out("WELCOME", {"id": Session.my_id, "pos": [pos.x, pos.y, pos.z], "first": Session.first_time, "inv": _inv(), "players": Session.roster.size()})
	match String(a.bot):
		"duo_a": await _duo_a()
		"duo_b": await _duo_b()
		"verify": await _verify()
		"reconnect": await _reconnect()
		_: out("UNKNOWN_SCENARIO")
	_quit(0 if not failed else 1)

func _quit(code: int) -> void:
	Net.leave()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(code)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		_idle_move()

var _idle_acc := 0.0
func _idle_move() -> void:
	_idle_acc += get_process_delta_time()
	if _idle_acc > 0.2 and Session.active:
		_idle_acc = 0.0
		_send_move(0)

func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
		_idle_move()
	return false

func _send_move(flags: int) -> void:
	seq += 1
	Net.send(Protocol.C.MOVE, [seq, pos.x, pos.y, pos.z, yaw, 0.0, flags | Protocol.F_ON_FLOOR], false)

func _walk_to(target: Vector3, speed := 3.2) -> void:
	var w := GameData.world
	var guard := 0
	while Vector2(target.x - pos.x, target.z - pos.z).length() > 0.3 and guard < 2000:
		guard += 1
		var dir := Vector2(target.x - pos.x, target.z - pos.z).normalized()
		var step := minf(speed / 15.0, Vector2(target.x - pos.x, target.z - pos.z).length())
		pos.x += dir.x * step
		pos.z += dir.y * step
		pos.y = w.ground(pos.x, pos.z)
		yaw = atan2(-dir.x, -dir.y)
		_send_move(0)
		await get_tree().create_timer(1.0 / 15.0).timeout

func _inv() -> Dictionary:
	var d: Dictionary = {}
	for s: Variant in Session.inv.slots:
		if s != null:
			d[String(s.id)] = int(d.get(String(s.id), 0)) + int(s.n)
	return d

func _slot_of(id: String) -> int:
	for i in Session.inv.size():
		var s: Variant = Session.inv.slots[i]
		if s != null and String(s.id) == id:
			return i
	return -1

func _struct_of(type: String, stage := -1) -> int:
	for id: int in Session.structs.keys():
		var s: Dictionary = Session.structs[id]
		if String(s.type) == type and (stage < 0 or int(s.stage) == stage):
			return id
	return -1

func _check(label: String, ok: bool, detail: Variant = null) -> void:
	out("CHECK", {"t": label, "ok": ok, "d": detail})
	if not ok:
		failed = true

# ------------------------------------------------------------------------------------------- jugador A
func _duo_a() -> void:
	var w := GameData.world
	await _walk_to(Vector3(P.x, 0, P.z))
	_check("a_walk_sin_correcciones", corrections.is_empty(), corrections)
	var seen := [false]
	Session.snapshot.connect(func(_ms: int, players: Array, _cr: Array) -> void:
		for pl: Array in players:
			if Vector3(pl[1], pl[2], pl[3]).distance_to(pos) < 12.0:
				seen[0] = true)
	_check("a_ve_a_b_sincronizado", await _until(func() -> bool: return seen[0], 25.0))
	# fabricación: 5 fibras -> 1 cuerda
	var before := _inv()
	Session.request_craft("r_cuerda", 1)
	await _until(func() -> bool: return "crafted" in notes, 8.0)
	await _wait(1.2)
	var after := _inv()
	_check("a_fabrica_cuerda", int(after.get("cuerda", 0)) == int(before.get("cuerda", 0)) + 1 and int(after.get("fibra", 0)) == int(before.get("fibra", 0)) - 5, after)
	# carrera por el mismo objeto: A lo suelta y ambos lo piden a la vez
	var known := Session.pickups.keys()
	Session.request_drop(_slot_of("galletas"), 1)
	var new_id := [-1]
	await _until(func() -> bool:
		for id: int in Session.pickups.keys():
			if not (id in known) and String(Session.pickups[id].item) == "galletas":
				new_id[0] = id
				return true
		return false, 5.0)
	out("DROPPED", new_id[0])
	Session.request_interact(Protocol.I.PICKUP, new_id[0])
	await _wait(1.5)
	out("AFTER_RACE", _inv())
	# recolección cronometrada del nodo más cercano
	var best := -1
	var bd := 1e9
	for hn: Dictionary in w.harvest_nodes:
		var d := (hn.pos as Vector3).distance_to(pos)
		if d < bd and w.walkable(hn.pos.x, hn.pos.z):
			bd = d
			best = int(hn.id)
	out("HARVEST_TARGET", {"id": best, "dist": bd})
	# construcción: arcón (armazón + terminar) y permisos
	var spot := Vector3(P.x + 2.5, w.ground(P.x + 2.5, P.z + 1.0), P.z + 1.0)
	Net.send(Protocol.C.BUILD_PLACE, ["arcon", spot.x, spot.y, spot.z, 0.0])
	_check("a_coloca_armazon", await _until(func() -> bool: return _struct_of("arcon", 0) >= 0, 5.0), notes)
	var sid := _struct_of("arcon")
	Net.send(Protocol.C.BUILD_ADVANCE, sid)
	_check("a_termina_arcon", await _until(func() -> bool: return _struct_of("arcon", 1) >= 0, 8.0), notes)
	Session.request_interact(Protocol.I.CONTAINER, ServerWorld.STRUCT_CONTAINER + sid)
	_check("a_abre_arcon", await _until(func() -> bool: return Session.container_key >= 0, 4.0))
	Session.request_move_item(0, _slot_of("venda"), 1, -1, 1)
	await _wait(1.0)
	_check("a_guarda_venda", Session.container_inv != null and Session.container_inv.count("venda") == 1 and Session.inv.count("venda") == 0, _inv())
	out("PHASE", "privado")
	await _wait(3.5)                       # B intenta abrir: sin permiso
	Net.send(Protocol.C.BUILD_PERM, [sid, 2])
	out("PHASE", "publico_ocupado")
	await _wait(3.5)                       # B intenta abrir: ocupado por A
	Session.close_container()
	out("PHASE", "libre")
	await _wait(5.0)                       # B abre y se lleva la venda
	# hoguera
	var fire := Vector3(P.x - 2.5, w.ground(P.x - 2.5, P.z + 1.5), P.z + 1.5)
	Net.send(Protocol.C.BUILD_PLACE, ["hoguera", fire.x, fire.y, fire.z, 0.0])
	await _until(func() -> bool: return _struct_of("hoguera", 0) >= 0, 5.0)
	Net.send(Protocol.C.BUILD_ADVANCE, _struct_of("hoguera"))
	_check("a_enciende_hoguera", await _until(func() -> bool:
		var h := _struct_of("hoguera", 1)
		return h >= 0 and bool(Session.structs[h].lit), 8.0), notes)
	await _wait(2.5)
	out("FINAL", {"inv": _inv(), "pos": [pos.x, pos.y, pos.z], "structs": Session.structs.size(), "stats": Session.stats, "level": Session.progress.get("level", 0)})

# ------------------------------------------------------------------------------------------- jugador B
func _duo_b() -> void:
	var w := GameData.world
	var raced := [false]
	Session.object_event.connect(func(kind: int, id: int, state: Variant) -> void:
		if kind == Protocol.O_PICKUP and state != null and String(state[0]) == "galletas" and not raced[0]:
			raced[0] = true
			Session.request_interact(Protocol.I.PICKUP, id))
	await _walk_to(Vector3(P.x, 0, P.z + 2.0))
	_check("b_walk_sin_correcciones", corrections.is_empty(), corrections)
	await _until(func() -> bool: return raced[0], 40.0)
	await _wait(1.5)
	out("AFTER_RACE", _inv())
	# trampas: nada de esto debe cambiar el estado
	var inv0 := _inv()
	var real := pos
	pos = pos + Vector3(70, 0, 0)
	_send_move(Protocol.F_SPRINT)
	await _wait(0.8)
	_check("b_teletransporte_corregido", not corrections.is_empty() and pos.distance_to(real) < 2.0, corrections)
	pos = real
	Session.request_use(200)
	Session.request_craft("r_inexistente", 3)
	Session.request_interact(Protocol.I.PICKUP, 987654)
	Session.request_interact(Protocol.I.DOOR, 5 * 64 + 0)          # puerta a cientos de metros
	Net.send(Protocol.C.INV_MOVE, [1, 0, 0, -1, 99])               # contenedor que no tiene abierto
	Net.send(Protocol.C.BUILD_PLACE, ["hoguera", 900.0, 14.0, 300.0, 0.0])   # fuera de alcance
	Net.send(Protocol.C.MOVE, "basura", false)
	Net.send(Protocol.C.CRAFT, {"x": NAN})
	await _wait(1.5)
	_check("b_peticiones_invalidas_sin_efecto", _inv() == inv0 and Session.open_doors.is_empty() and _struct_of("hoguera") < 0, {"inv": _inv(), "notes": notes})
	# arcón de A: primero privado, luego ocupado, luego libre
	_check("b_ve_arcon", await _until(func() -> bool: return _struct_of("arcon", 1) >= 0, 40.0))
	var sid := _struct_of("arcon", 1)
	var key := ServerWorld.STRUCT_CONTAINER + sid
	var results: Array = []
	for attempt in 12:
		notes.clear()
		Session.request_interact(Protocol.I.CONTAINER, key)
		await _wait(1.0)
		if Session.container_key == key:
			results.append("abierto")
			break
		results.append("no_permission" if "no_permission" in notes else ("busy" if "busy" in notes else "nada"))
	out("ARCON_INTENTOS", results)
	_check("b_arcon_privado_rechazado", "no_permission" in results)
	_check("b_arcon_ocupado_rechazado", "busy" in results)
	_check("b_arcon_abierto_al_final", results.back() == "abierto")
	notes.clear()
	Net.send(Protocol.C.BUILD_DISMANTLE, sid)
	await _wait(0.8)
	_check("b_no_puede_desmontar_ajeno", "no_permission" in notes or "not_empty" in notes, notes)
	if Session.container_inv != null and Session.container_inv.count("venda") > 0:
		for i in Session.container_inv.size():
			var s: Variant = Session.container_inv.slots[i]
			if s != null and String(s.id) == "venda":
				Session.request_move_item(1, i, 0, -1, 1)
	await _wait(1.0)
	Session.close_container()
	await _wait(0.6)
	_check("b_recibe_venda_de_a", Session.inv.count("venda") == 2, _inv())
	await _until(func() -> bool:
		var h := _struct_of("hoguera", 1)
		return h >= 0, 25.0)
	await _wait(1.0)
	out("FINAL", {"inv": _inv(), "pos": [pos.x, pos.y, pos.z], "structs": Session.structs.size()})

# ------------------------------------------------------------------------- tras reiniciar el servidor
func _verify() -> void:
	await _wait(1.5)
	var want_pos := String(a.get("pos", "")).split(",")
	if want_pos.size() == 3:
		var wp := Vector3(float(want_pos[0]), float(want_pos[1]), float(want_pos[2]))
		_check("posicion_restaurada", Session.spawn_pos.distance_to(wp) < 1.5, [Session.spawn_pos.x, Session.spawn_pos.y, Session.spawn_pos.z])
	_check("no_es_personaje_nuevo", not Session.first_time)
	var arcon := _struct_of("arcon", 1)
	var hog := _struct_of("hoguera", 1)
	_check("estructuras_persisten", arcon >= 0 and hog >= 0, Session.structs.keys())
	out("FINAL", {"inv": _inv(), "structs": Session.structs.size(), "level": Session.progress.get("level", 0), "places": Session.progress.get("places", [])})

func _reconnect() -> void:
	await _walk_to(Vector3(P.x + 6.0, 0, P.z - 4.0))
	await _wait(0.5)
	var left := pos
	out("LEAVING", [pos.x, pos.y, pos.z])
	welcomed = false
	Net.leave()
	await get_tree().create_timer(1.5).timeout
	Net.join(String(a.connect).split(":")[0], int(String(a.connect).split(":")[1]))
	await _until(func() -> bool: return welcomed, 12.0)
	_check("reconexion_aceptada", welcomed)
	_check("reconexion_misma_posicion", Session.spawn_pos.distance_to(left) < 1.5, [Session.spawn_pos.x, Session.spawn_pos.z])
	_check("reconexion_no_es_nuevo", not Session.first_time)
	out("FINAL", {"inv": _inv()})
