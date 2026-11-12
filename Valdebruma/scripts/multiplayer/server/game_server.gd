class_name GameServer
extends Node
## GameServer — servidor autoritativo de Valdebruma.
##
## Responsabilidad: mantener el estado oficial de la partida (jugadores, objetos del mundo,
## criaturas, tiempo y clima), validar TODAS las peticiones de los clientes y replicar por
## relevancia. Se ejecuta igual en modo dedicado (--server, sin ventana) y como anfitrión local.
## Datos: players (peer -> ServerPlayer) y subsistemas (ws, env, survival, actions, creatures,
## social, progress, store). Lo llama: Net (mensajes y conexiones). Persistencia: ServerPersistence.
## Prueba: tests/run_tests.sh (unitarias) y tests/net_session.sh (servidor + clientes reales).

const SAVE_PLAYER_EVERY_MS := 60000
const SAVE_WORLD_EVERY_MS := 120000
const SAVE_WORLD_DIRTY_MS := 15000       # si hubo cambios en objetos, se guarda antes

var world: WorldMap
var players: Dictionary = {}
var by_account: Dictionary = {}
var pending: Dictionary = {}
var options: Dictionary = {"name": "Valdebruma", "difficulty": "normal", "day_length": 2400.0, "global_chat": true,
	"max_structures": 1500, "max_structures_player": 30, "motd": ""}
var store: ServerPersistence
var ws: ServerWorld
var env: ServerEnvironment
var survival: ServerSurvival
var actions: ServerActions
var creatures: ServerCreatures
var social: ServerSocial
var progress: ServerProgress
var now_ms := 0
var unix := 0.0
var running := false
var _tick_acc := 0.0
var _snap_acc := 0.0
var _slow_acc := 0.0
var _creature_acc := 0.0
var _world_save_ms := 0
var _stat_tick := 0
var stats_msgs := 0
var world_dirty := false

func start(world_name: String, opts: Dictionary) -> void:
	world = GameData.world
	for k: String in opts.keys():
		options[k] = opts[k]
	now_ms = Time.get_ticks_msec()
	unix = Time.get_unix_time_from_system()
	store = ServerPersistence.new(world_name)
	ws = ServerWorld.new(self)
	env = ServerEnvironment.new(self)
	survival = ServerSurvival.new(self)
	actions = ServerActions.new(self)
	creatures = ServerCreatures.new(self)
	social = ServerSocial.new(self)
	progress = ServerProgress.new(self)
	var saved := store.load_world()
	ws.load_state(saved.get("objects", {}))
	env.load_state(saved.get("env", {}))
	if options.has("start_hour"):
		env.hour = clampf(float(options.start_hour), 0.0, 23.9)
	social.load_state(saved.get("social", {}))
	creatures.spawn_all()
	_world_save_ms = now_ms + SAVE_WORLD_EVERY_MS
	running = true
	print("[servidor] mundo '%s' listo: %d estructuras, %d criaturas, día %d %02d:%02d" % [world_name, ws.structures.size(), creatures.list.size(),
		int(env.day), int(env.hour), int(fmod(env.hour, 1.0) * 60.0)])

func shutdown() -> void:
	if not running:
		return
	running = false
	for p: ServerPlayer in players.values():
		store.save_player(p)
	save_world()
	print("[servidor] estado guardado y servidor detenido")

func save_world() -> void:
	world_dirty = false
	store.save_world({"objects": ws.save_state(), "env": env.save_state(), "social": social.save_state()})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		shutdown()

# ---- conexiones ------------------------------------------------------------------------------------
func peer_connected(id: int) -> void:
	pending[id] = Time.get_ticks_msec()

func peer_disconnected(id: int) -> void:
	pending.erase(id)
	if players.has(id):
		_remove_player(players[id], "left")

func _remove_player(p: ServerPlayer, why: String) -> void:
	actions.cancel_action(p, true)
	ws.close_container(p)
	social.on_leave(p)
	store.save_player(p)
	players.erase(p.peer)
	by_account.erase(p.account)
	broadcast(Protocol.S.PLAYER_LEAVE, {"id": p.peer, "why": why})
	if players.is_empty() and world_dirty:
		save_world()
	print("[servidor] sale %s (%s). Conectados: %d" % [p.name, why, players.size()])

# ---- bucle ---------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not running:
		return
	now_ms = Time.get_ticks_msec()
	unix = Time.get_unix_time_from_system()
	_tick_acc += delta
	_snap_acc += delta
	_slow_acc += delta
	_creature_acc += delta
	if _tick_acc >= 1.0 / float(Protocol.TICK_HZ):
		var dt := _tick_acc
		_tick_acc = 0.0
		actions.tick(dt)
	if _creature_acc >= 0.1:
		creatures.tick(_creature_acc)
		_creature_acc = 0.0
	if _snap_acc >= 1.0 / float(Protocol.SNAPSHOT_HZ):
		_snap_acc = 0.0
		_send_snapshots()
	if _slow_acc >= 1.0:
		var dt := _slow_acc
		_slow_acc = 0.0
		_slow_tick(dt)

func _slow_tick(dt: float) -> void:
	env.tick(dt)
	ws.tick(dt)
	social.tick(dt)
	_stat_tick += 1
	for p: ServerPlayer in players.values():
		survival.tick_player(p, dt)
		progress.tick_player(p, dt)
		_update_interest(p)
		if p.dirty_stats or _stat_tick % 2 == 0:
			send(p, Protocol.S.STATS, p.stats_packet())
			p.dirty_stats = false
		if p.dirty_inv:
			send(p, Protocol.S.INV, p.inv_packet())
			p.dirty_inv = false
		if now_ms >= p.save_due_ms:
			p.save_due_ms = now_ms + SAVE_PLAYER_EVERY_MS
			store.save_player(p)
	for id: int in pending.keys():           # conexiones que no se presentan a tiempo
		if now_ms - int(pending[id]) > 10000:
			pending.erase(id)
			Net.kick(id)
	if now_ms >= _world_save_ms or (world_dirty and now_ms >= _world_save_ms - SAVE_WORLD_EVERY_MS + SAVE_WORLD_DIRTY_MS):
		_world_save_ms = now_ms + SAVE_WORLD_EVERY_MS
		save_world()
	# parada ordenada del servidor dedicado: crear el archivo <datos>/<mundo>/stop
	if Net.is_dedicated and FileAccess.file_exists(store.root + "/stop"):
		DirAccess.remove_absolute(store.root + "/stop")
		print("[servidor] archivo 'stop' detectado: parada ordenada")
		shutdown()
		get_tree().quit(0)

# ---- envío -----------------------------------------------------------------------------------------------
func send(p: ServerPlayer, id: int, data: Variant = null, reliable := true) -> void:
	stats_msgs += 1
	Net.send_to(p.peer, id, data, reliable)

func notify(p: ServerPlayer, code: String, params: Dictionary = {}) -> void:
	send(p, Protocol.S.NOTIFY, {"c": code, "p": params})

func broadcast(id: int, data: Variant, except := 0) -> void:
	for p: ServerPlayer in players.values():
		if p.peer != except:
			send(p, id, data)

func send_near(pos: Vector3, radius: float, id: int, data: Variant, except := 0) -> void:
	for p: ServerPlayer in players.values():
		if p.peer != except and p.pos.distance_to(pos) <= radius:
			send(p, id, data)

## Envía a los jugadores cuyo conjunto de interés incluye el sector.
func send_sector(sector: int, id: int, data: Variant) -> void:
	for p: ServerPlayer in players.values():
		if p.sectors.has(sector):
			send(p, id, data)

func obj_event(pos: Vector3, kind: int, oid: int, state: Variant) -> void:
	world_dirty = true
	send_sector(WorldMap.sector_key(pos.x, pos.z), Protocol.S.OBJ_EVENT, [kind, oid, state])

func log_anomaly(p: ServerPlayer, what: String) -> void:
	store.append_log("anomalies.log", "%s cuenta=%s nombre=%s %s" % [Time.get_datetime_string_from_system(), p.account.left(8), p.name, what])

# ---- geometría de validación ---------------------------------------------------------------------------------
func door_open(bi: int, door_id: int) -> bool:
	return ws.doors.get(Protocol.door_key(bi, door_id), false)

func eye(p: ServerPlayer) -> Vector3:
	return p.pos + Vector3(0, 1.0 if (p.flags & Protocol.F_CROUCH) != 0 else 1.6, 0)

## Alcance + línea de visión hasta un punto (acortando el final para no chocar con el propio objeto).
func can_reach(p: ServerPlayer, target: Vector3, extra := 0.0) -> bool:
	var e := eye(p)
	var d := e.distance_to(target)
	if d > Protocol.REACH + 1.4 + extra:
		return false
	if d < 0.9:
		return true
	var end := target + (e - target).normalized() * minf(0.55, d * 0.5)
	return not world.segment_blocked(e, end, door_open)

# ---- entrada de mensajes ------------------------------------------------------------------------------------------
func handle_message(peer: int, id: int, data: Variant) -> void:
	if not running:
		return
	if id == Protocol.C.HELLO:
		_on_hello(peer, Guard.dict(data))
		return
	var p: ServerPlayer = players.get(peer)
	if p == null:
		return
	if id == Protocol.C.NET_PING:
		Net.send_to(peer, Protocol.S.NET_PONG, data, false)
		return
	# cubo de fichas: limita la frecuencia total de peticiones por jugador
	var t := Time.get_ticks_msec()
	p.tokens = minf(40.0, p.tokens + float(t - p.tokens_ms) * 0.02)
	p.tokens_ms = t
	var cost := 0.4 if id == Protocol.C.MOVE else 1.0
	if p.tokens < cost:
		p.strikes += 1
		if p.strikes == 200:
			log_anomaly(p, "exceso de peticiones")
			Net.kick(peer)
		return
	p.tokens -= cost
	if p.down and not (id in [Protocol.C.RESPAWN, Protocol.C.CHAT, Protocol.C.GROUP]):
		return
	match id:
		Protocol.C.MOVE: _on_move(p, Guard.arr(data, 7))
		Protocol.C.INTERACT: actions.on_interact(p, Guard.arr(data, 2))
		Protocol.C.INV_MOVE: actions.on_inv_move(p, Guard.arr(data, 5))
		Protocol.C.INV_USE: actions.on_inv_use(p, Guard.i(data, 0, 255, -1))
		Protocol.C.INV_EQUIP: actions.on_equip(p, Guard.i(data, 0, 255, -1))
		Protocol.C.INV_UNEQUIP: actions.on_unequip(p, Guard.s(data, 12))
		Protocol.C.INV_DROP: actions.on_drop(p, Guard.arr(data, 2))
		Protocol.C.INV_SPLIT: actions.on_split(p, Guard.arr(data, 2))
		Protocol.C.QUICK_SET: actions.on_quick_set(p, Guard.arr(data, 2))
		Protocol.C.CRAFT: actions.on_craft(p, Guard.arr(data, 1))
		Protocol.C.BUILD_PLACE: actions.on_build_place(p, Guard.arr(data, 5))
		Protocol.C.BUILD_ADVANCE: actions.on_build_advance(p, Guard.i(data, 0, 1 << 30, -1))
		Protocol.C.BUILD_DISMANTLE: actions.on_build_dismantle(p, Guard.i(data, 0, 1 << 30, -1))
		Protocol.C.BUILD_PERM: actions.on_build_perm(p, Guard.arr(data, 2))
		Protocol.C.ACTION_CANCEL: actions.cancel_action(p, false)
		Protocol.C.CONTAINER_CLOSE: ws.close_container(p)
		Protocol.C.GROUP: social.on_group(p, Guard.arr(data, 1))
		Protocol.C.CHAT: social.on_chat(p, Guard.arr(data, 2))
		Protocol.C.EMOTE: social.on_emote(p, Guard.i(data, 1, 16, 0))
		Protocol.C.MARK: social.on_mark(p, Guard.arr(data, 3))
		Protocol.C.REPORT: social.on_report(p, Guard.arr(data, 2))
		Protocol.C.TRADE: social.on_trade(p, Guard.arr(data, 2))
		Protocol.C.CONTRACT: progress.on_contract(p, Guard.arr(data, 2))
		Protocol.C.PRIVACY:
			p.hidden = bool(Guard.i(data, 0, 1, 0))
			broadcast(Protocol.S.PLAYER_UPDATE, p.public_info())
		Protocol.C.COSMETIC: progress.on_cosmetic(p, Guard.arr(data, 2))
		Protocol.C.RESPAWN: survival.on_respawn(p)
		_: p.strikes += 1

# ---- presentación y entrada al mundo -------------------------------------------------------------------------------
func _on_hello(peer: int, d: Dictionary) -> void:
	if players.has(peer):
		return
	pending.erase(peer)
	if Guard.i(d.get("v"), 0, 1 << 20, -1) != Protocol.VERSION:
		Net.send_to(peer, Protocol.S.REJECT, {"c": Protocol.R_VERSION, "need": Protocol.VERSION})
		return
	if players.size() >= Protocol.MAX_PLAYERS:
		Net.send_to(peer, Protocol.S.REJECT, {"c": Protocol.R_FULL})
		return
	var account := Guard.s(d.get("account"), 40)
	var token := Guard.s(d.get("token"), 80)
	var pname := Guard.s(d.get("name"), 16).strip_edges()
	if account.length() < 16 or token.length() < 16:
		Net.send_to(peer, Protocol.S.REJECT, {"c": Protocol.R_AUTH})
		return
	if not Protocol.name_ok(pname):
		Net.send_to(peer, Protocol.S.REJECT, {"c": Protocol.R_NAME})
		return
	var auth := store.authenticate(account, token, pname)
	if auth != "":
		Net.send_to(peer, Protocol.S.REJECT, {"c": auth})
		return
	if by_account.has(account):              # sesión anterior colgada: se sustituye
		var old: ServerPlayer = by_account[account]
		Net.send_to(old.peer, Protocol.S.REJECT, {"c": Protocol.R_DUPLICATE})
		var old_peer := old.peer
		_remove_player(old, "replaced")
		Net.kick(old_peer)
	var p := ServerPlayer.new()
	p.peer = peer
	p.account = account
	var saved := store.load_player(account)
	if not saved.is_empty():
		p.from_save(saved)
	p.name = _unique_name(pname)
	var cos := Guard.dict(d.get("cos"))
	if p.first_login:
		_new_character(p)
	progress.sanitize_cosmetics(p, cos)
	if not world.in_bounds(p.pos.x, p.pos.z) or p.pos.y < world.height(p.pos.x, p.pos.z) - 3.0:
		p.pos = _spawn_point(p)
	p.inv.resize(p.slot_count())
	p.joined_ms = now_ms
	p.last_move_ms = now_ms
	p.tokens_ms = now_ms
	p.save_due_ms = now_ms + SAVE_PLAYER_EVERY_MS
	players[peer] = p
	by_account[account] = p
	var roster: Array = []
	for o: ServerPlayer in players.values():
		roster.append(o.public_info())
	send(p, Protocol.S.WELCOME, {"v": Protocol.VERSION, "id": peer, "server": options.name, "motd": options.motd, "difficulty": options.difficulty,
		"pos": [p.pos.x, p.pos.y, p.pos.z], "yaw": p.yaw, "env": env.packet(), "roster": roster, "stats": p.stats_packet(), "inv": p.inv_packet(),
		"progress": p.progress_packet(), "first": p.first_login, "name": p.name, "cos": p.cosmetics, "group": social.group_packet(p), "global_chat": options.global_chat})
	broadcast(Protocol.S.PLAYER_JOIN, p.public_info(), peer)
	p.sectors.clear()
	p.last_sector = -1
	_update_interest(p)
	progress.on_login(p)
	p.dirty_inv = false
	print("[servidor] entra %s (peer %d, %s). Conectados: %d" % [p.name, peer, "nuevo" if p.first_login else "recuperado", players.size()])

func _unique_name(base: String) -> String:
	var n := base
	var k := 2
	var taken := true
	while taken:
		taken = false
		for o: ServerPlayer in players.values():
			if o.name.to_lower() == n.to_lower():
				taken = true
				n = "%s %d" % [base.left(13), k]
				k += 1
				break
	return n

func _new_character(p: ServerPlayer) -> void:
	p.pos = _spawn_point(p)
	p.equip["torso"] = Inventory.make_stack("chaqueta_campo", 1)
	p.equip["piernas"] = Inventory.make_stack("pantalon_monte", 1)
	p.inv.resize(p.slot_count())
	p.inv.add("agua_potable", 1)
	p.inv.add("galletas", 1)
	p.inv.add("venda", 1)
	if bool(options.get("test_kit", false)):          # solo pruebas automáticas (--test-kit)
		for e: Array in [["piedra", 8], ["palo", 12], ["tablon", 8], ["clavos", 12], ["fibra", 10], ["tela", 6], ["martillo", 1], ["botella_vacia", 1]]:
			p.inv.add(String(e[0]), int(e[1]))

func _spawn_point(p: ServerPlayer) -> Vector3:
	var spawns: Array = world.info.get("spawns", [[256, 1000]])
	var s: Array = spawns[absi(hash(p.account)) % spawns.size()]
	return Vector3(float(s[0]), world.height(float(s[0]), float(s[1])) + 0.2, float(s[1]))

# ---- movimiento: predicción en cliente, validación y corrección en servidor -------------------------------------------
func max_speed(p: ServerPlayer, fl: int) -> float:
	var v := 3.7
	if (fl & Protocol.F_SWIM) != 0:
		v = 1.9
	elif (fl & Protocol.F_CROUCH) != 0:
		v = 1.7
	elif (fl & Protocol.F_SPRINT) != 0 and p.stamina > 0.5 and not p.has_effect("agotado"):
		v = 6.6
	if p.has_effect("aturdido"):
		v *= 0.6
	if p.overloaded():
		v *= 0.7
	return v

func _on_move(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var np: Variant = Guard.v3(d[1], d[2], d[3])
	if np == null:
		return
	var new_pos: Vector3 = np
	var seq := Guard.i(d[0], 0, 1 << 30, 0)
	var fl := Guard.i(d[6], 0, 63, 0)
	var t := Time.get_ticks_msec()
	var dt := clampf(float(t - p.last_move_ms) / 1000.0, 0.0, 1.0)
	p.last_move_ms = t
	var old := p.pos
	var flat := Vector2(new_pos.x - old.x, new_pos.z - old.z).length()
	p.move_budget = minf(4.5, p.move_budget + max_speed(p, fl) * dt * 1.25)
	var ok := flat <= p.move_budget + 0.05
	var why := "velocidad"
	if ok:
		var g := world.ground(new_pos.x, new_pos.z)
		var top := g + 3.4
		if world.cell_flags(new_pos.x, new_pos.z) & WorldMap.F_BUILDING != 0:
			top = g + 9.0
		if new_pos.y > top or new_pos.y < g - 2.6:
			ok = false
			why = "altura"
	if ok and not world.in_bounds(new_pos.x, new_pos.z, -8.0):
		ok = false
		why = "limite"
	if ok and flat > 0.02 and world.segment_blocked(old + Vector3(0, 0.9, 0), new_pos + Vector3(0, 0.9, 0), door_open):
		ok = false
		why = "muro"
	if not ok:
		p.move_strikes += 1
		if p.move_strikes == 60:
			log_anomaly(p, "movimiento rechazado repetidamente (%s) en %s" % [why, str(old.snapped(Vector3.ONE))])
		if t - p.last_correct_ms > 180:
			p.last_correct_ms = t
			send(p, Protocol.S.CORRECT, [seq, old.x, old.y, old.z, why])
		return
	p.move_budget -= flat
	p.move_strikes = maxi(0, p.move_strikes - 1)
	p.pos = new_pos
	p.yaw = Guard.f(d[4], -10.0, 10.0, 0.0)
	p.pitch = Guard.f(d[5], -1.6, 1.6, 0.0)
	if (fl & Protocol.F_SPRINT) != 0 and (p.stamina <= 0.5 or p.has_effect("agotado")):
		fl &= ~Protocol.F_SPRINT
	if (fl & Protocol.F_LIGHT) != 0 and not survival.light_available(p):
		fl &= ~Protocol.F_LIGHT
	p.flags = (fl & ~Protocol.F_DOWN) | (Protocol.F_DOWN if p.down else 0)
	if flat > 0.0:
		p.stat_add("distance", flat)
		var speed := flat / maxf(dt, 0.03)
		var nz := 0.0
		if speed > 4.6:
			nz = 22.0
		elif speed > 2.2 and (fl & Protocol.F_CROUCH) == 0:
			nz = 9.0
		p.noise = maxf(p.noise, nz)
		if p.action.has("pos") and (p.action.pos as Vector3).distance_to(new_pos) > 1.6:
			actions.cancel_action(p, false)

func teleport(p: ServerPlayer, pos: Vector3) -> void:
	p.pos = pos
	p.move_budget = 2.0
	send(p, Protocol.S.CORRECT, [-1, pos.x, pos.y, pos.z, "teleport"])
	_update_interest(p)

# ---- interés por sectores y fotos de estado ------------------------------------------------------------------------------
func _update_interest(p: ServerPlayer) -> void:
	var s := WorldMap.sector_of(p.pos.x, p.pos.z)
	var key := WorldMap.key_of(s)
	if key == p.last_sector:
		return
	p.last_sector = key
	var want: Dictionary = {}
	var r := Protocol.OBJECT_SECTORS
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var c := Vector2i(s.x + di, s.y + dj)
			if c.x >= 0 and c.y >= 0 and c.x < WorldMap.SECTORS and c.y < WorldMap.SECTORS:
				want[WorldMap.key_of(c)] = true
	var batch: Array = []
	for k: int in want.keys():
		if not p.sectors.has(k):
			batch.append(ws.sector_packet(k))
	p.sectors = want
	if not batch.is_empty():
		send(p, Protocol.S.OBJECTS, {"sectors": batch, "keep": want.keys()})

func _send_snapshots() -> void:
	if players.is_empty():
		return
	var t := now_ms
	for p: ServerPlayer in players.values():
		var pl: Array = []
		for o: ServerPlayer in players.values():
			if o.peer != p.peer and o.pos.distance_squared_to(p.pos) < Protocol.RELEVANCE * Protocol.RELEVANCE:
				var a := o.anim if t < o.anim_until else 0
				pl.append([o.peer, snappedf(o.pos.x, 0.01), snappedf(o.pos.y, 0.01), snappedf(o.pos.z, 0.01), snappedf(o.yaw, 0.01), snappedf(o.pitch, 0.02), o.flags, a])
		var cr: Array = creatures.snapshot_for(p)
		if pl.is_empty() and cr.is_empty():
			continue
		send(p, Protocol.S.SNAPSHOT, [t, pl, cr], false)

func set_anim(p: ServerPlayer, code: int, seconds: float) -> void:
	p.anim = code
	p.anim_until = now_ms + int(seconds * 1000.0)
