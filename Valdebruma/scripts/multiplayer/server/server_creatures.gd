class_name ServerCreatures
extends RefCounted
## ServerCreatures — inteligencia artificial de las criaturas (simulada en el servidor).
##
## Estados: IDLE, PATROL, INVESTIGATE, ALERT, CHASE, SEARCH, RETREAT, RETURN, RECOVER, FLEE, CURL, DORMANT.
## Percepción: distancia, cono de visión, línea de visión contra edificios y estímulos
## abstractos (ruido del jugador, luz en mano de noche). Navegación: AStarGrid2D sobre la
## rejilla de 4 m de WorldMap + esquiva local; si una ruta falla, la criatura reacciona
## (tropiezo) y elige otro destino: no hay bucles infinitos.
## Coste: solo se actualizan las criaturas con jugadores cerca; a media distancia, 1 Hz.
## Sin daño gráfico: un Brumal embiste y aturde; un Farol suelta esporas que agotan.

enum St { IDLE, PATROL, INVESTIGATE, ALERT, CHASE, SEARCH, RETREAT, RETURN, RECOVER, FLEE, CURL, DORMANT }
const TYPES: Array[String] = ["brumal", "zarzo", "farol"]

var srv: GameServer
var list: Array = []
var astar := AStarGrid2D.new()
var _rng := RandomNumberGenerator.new()

func _init(server: GameServer) -> void:
	srv = server
	_rng.randomize()

func spawn_all() -> void:
	var w := srv.world
	astar.region = Rect2i(0, 0, WorldMap.CELLS, WorldMap.CELLS)
	astar.cell_size = Vector2(WorldMap.CELL, WorldMap.CELL)
	astar.offset = Vector2(WorldMap.CELL, WorldMap.CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.jumping_enabled = true
	astar.update()
	for j in WorldMap.CELLS:
		for i in WorldMap.CELLS:
			if (w.cells[j * WorldMap.CELLS + i] & (WorldMap.F_BUILDING | WorldMap.F_WATER | WorldMap.F_STEEP)) != 0:
				astar.set_point_solid(Vector2i(i, j), true)
	var mult: float = srv.survival.diff("creatures")
	for zone: Dictionary in w.info.get("creatures", []):
		var type := String(zone.type)
		var def: Dictionary = GameData.creatures.get(type, {})
		if def.is_empty():
			continue
		var n := maxi(1, int(round(float(zone.count) * mult)))
		for k in n:
			var home := Vector3(float(zone.center[0]), 0, float(zone.center[1]))
			var pos := _random_point(home, float(zone.radius), float(def.get("float", 0.0)) > 0.0)
			list.append({"id": list.size() + 1, "type": type, "tidx": TYPES.find(type), "def": def, "pos": pos, "yaw": _rng.randf() * TAU, "state": St.IDLE,
				"t": _rng.randf_range(1.0, 6.0), "home": home, "home_r": float(zone.radius), "target": 0, "goal": pos, "seen": pos, "path": PackedVector2Array(),
				"pi": 0, "stuck": 0.0, "cool": 0.0, "night": bool(zone.get("night_only", false)), "acc": 0.0, "moving": 0, "lost": 0.0, "chase": 0.0})

func _random_point(center: Vector3, radius: float, floats: bool) -> Vector3:
	for tries in 24:
		var a := _rng.randf() * TAU
		var r := radius * sqrt(_rng.randf())
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		if not srv.world.in_bounds(x, z, 4.0):
			continue
		if floats or (srv.world.walkable(x, z) and not srv.world.in_safe_zone(x, z)):
			return Vector3(x, _height(x, z, floats), z)
	return Vector3(center.x, _height(center.x, center.z, floats), center.z)

func _height(x: float, z: float, floats: bool) -> float:
	var g := srv.world.ground(x, z)
	return maxf(g, srv.world.water_level) + 1.9 if floats else g

# ---- bucle ------------------------------------------------------------------------------------------------
func tick(dt: float) -> void:
	if srv.players.is_empty():
		return
	for c: Dictionary in list:
		var near := 1e9
		for p: ServerPlayer in srv.players.values():
			near = minf(near, Vector2(p.pos.x - c.pos.x, p.pos.z - c.pos.z).length())
		if near > 210.0:
			continue
		c.acc = float(c.acc) + dt
		if near > Protocol.CREATURE_RELEVANCE + 20.0 and float(c.acc) < 1.0:
			continue
		var step: float = c.acc
		c.acc = 0.0
		_update(c, step)

func _update(c: Dictionary, dt: float) -> void:
	c.t = float(c.t) - dt
	c.cool = maxf(0.0, float(c.cool) - dt)
	c.moving = 0
	if bool(c.night):
		var night: bool = srv.env.is_night()
		if not night and int(c.state) != St.DORMANT:
			_enter(c, St.DORMANT, 0.0)
		elif night and int(c.state) == St.DORMANT:
			_enter(c, St.IDLE, 2.0)
	if int(c.state) == St.DORMANT:
		return
	match String(c.def.behavior):
		"stalker": _stalker(c, dt)
		"skittish": _skittish(c, dt)
		"drifter": _drifter(c, dt)

func _enter(c: Dictionary, state: int, time: float) -> void:
	c.state = state
	c.t = time
	c.stuck = 0.0
	if state != St.CHASE:
		c.chase = 0.0

# ---- percepción -----------------------------------------------------------------------------------------------
## Devuelve {player, seen: bool, heard: bool, dist} del estímulo más relevante o vacío.
func _sense(c: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var def: Dictionary = c.def
	var night: bool = srv.env.is_night()
	for p: ServerPlayer in srv.players.values():
		if p.down or srv.world.in_safe_zone(p.pos.x, p.pos.z):
			continue
		var to := p.pos - (c.pos as Vector3)
		var d := Vector2(to.x, to.z).length()
		var sight := float(def.sight) * (0.55 if (p.flags & Protocol.F_CROUCH) != 0 else 1.0)
		var lit := (p.flags & Protocol.F_LIGHT) != 0
		if night:
			sight *= 1.35 if lit else 0.6
		sight *= 1.0 - 0.5 * srv.env.fog
		var heard := p.noise * float(def.hear) >= d and d < 60.0
		var seen := false
		if d <= sight:
			var facing := Vector3(sin(float(c.yaw)), 0, cos(float(c.yaw)))
			var ang := rad_to_deg(facing.angle_to(Vector3(to.x, 0, to.z).normalized())) if d > 0.5 else 0.0
			if ang <= float(def.fov) * 0.5 or d < 4.0:
				seen = not srv.world.segment_blocked((c.pos as Vector3) + Vector3(0, 1.1, 0), srv.eye(p), srv.door_open)
		if (seen or heard) and (best.is_empty() or (seen and not bool(best.seen)) or d < float(best.dist)):
			best = {"player": p, "seen": seen, "heard": heard, "dist": d, "lit": lit}
	return best

# ---- movimiento ---------------------------------------------------------------------------------------------------
func _go(c: Dictionary, goal: Vector3, speed: float, dt: float, floats := false) -> bool:
	# Devuelve true al llegar. Usa ruta A* para destinos lejanos y esquiva local.
	var pos: Vector3 = c.pos
	var flat := Vector2(goal.x - pos.x, goal.z - pos.z)
	if flat.length() < 1.2:
		return true
	var target := Vector2(goal.x, goal.z)
	if not floats and flat.length() > 14.0:
		if (c.path as PackedVector2Array).is_empty() or (c.goal as Vector3).distance_to(goal) > 6.0:
			var a := Vector2i(clampi(int(pos.x / WorldMap.CELL), 0, WorldMap.CELLS - 1), clampi(int(pos.z / WorldMap.CELL), 0, WorldMap.CELLS - 1))
			var b := Vector2i(clampi(int(goal.x / WorldMap.CELL), 0, WorldMap.CELLS - 1), clampi(int(goal.z / WorldMap.CELL), 0, WorldMap.CELLS - 1))
			c.goal = goal
			c.pi = 1
			c.path = astar.get_point_path(a, b, true) if not astar.is_point_solid(a) else PackedVector2Array()
		var path: PackedVector2Array = c.path
		if path.size() > 1:
			var pi: int = mini(int(c.pi), path.size() - 1)
			if Vector2(pos.x, pos.z).distance_to(path[pi]) < 2.5 and pi < path.size() - 1:
				pi += 1
				c.pi = pi
			target = path[pi]
	var dir := (target - Vector2(pos.x, pos.z)).normalized()
	var moved := false
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var dd := dir.rotated(turn)
		var nx := pos.x + dd.x * speed * dt
		var nz := pos.z + dd.y * speed * dt
		var probe_x := pos.x + dd.x * maxf(1.5, speed * dt)
		var probe_z := pos.z + dd.y * maxf(1.5, speed * dt)
		if floats or (srv.world.walkable(probe_x, probe_z) and not srv.world.in_safe_zone(probe_x, probe_z)):
			c.pos = Vector3(nx, _height(nx, nz, floats), nz)
			c.yaw = lerp_angle(float(c.yaw), atan2(dd.x, dd.y), clampf(dt * 6.0, 0.0, 1.0))
			moved = true
			break
	if moved:
		c.stuck = maxf(0.0, float(c.stuck) - dt)
		c.moving = 2 if speed > float(c.def.walk) * 1.5 else 1
	else:
		c.stuck = float(c.stuck) + dt
		c.path = PackedVector2Array()
	return false

func _face(c: Dictionary, at: Vector3, dt: float) -> void:
	var to := at - (c.pos as Vector3)
	c.yaw = lerp_angle(float(c.yaw), atan2(to.x, to.z), clampf(dt * 5.0, 0.0, 1.0))

# ---- Brumal: acechador ----------------------------------------------------------------------------------------------
func _stalker(c: Dictionary, dt: float) -> void:
	var def: Dictionary = c.def
	var s := _sense(c)
	var st := int(c.state)
	if float(c.stuck) > 2.0 and st != St.RECOVER:            # ruta bloqueada: tropieza y cambia de plan
		_enter(c, St.RECOVER, 1.2)
		c.goal = c.home
		return
	if st in [St.IDLE, St.PATROL, St.INVESTIGATE, St.SEARCH, St.RETURN] and not s.is_empty() and float(c.cool) <= 0.0:
		if bool(s.seen):
			c.target = (s.player as ServerPlayer).peer
			c.seen = (s.player as ServerPlayer).pos
			_enter(c, St.ALERT, 1.6)
			srv.send_near(c.pos, 70.0, Protocol.S.EMOTE, [-int(c.id), 1])
			return
		elif st != St.INVESTIGATE:
			c.seen = (s.player as ServerPlayer).pos
			_enter(c, St.INVESTIGATE, 14.0)
	match st:
		St.IDLE:
			if float(c.t) <= 0.0:
				c.goal = _random_point(c.home, float(c.home_r), false)
				_enter(c, St.PATROL, 30.0)
		St.PATROL:
			if _go(c, c.goal, float(def.walk), dt) or float(c.t) <= 0.0:
				_enter(c, St.IDLE, _rng.randf_range(3.0, 9.0))
		St.INVESTIGATE:
			if _go(c, c.seen, float(def.walk) * 1.3, dt) or float(c.t) <= 0.0:
				_enter(c, St.SEARCH, 5.0)
		St.ALERT:
			var p: ServerPlayer = srv.players.get(int(c.target))
			if p == null:
				_enter(c, St.IDLE, 2.0)
				return
			_face(c, p.pos, dt)
			if float(c.t) <= 0.0:
				var d := p.pos.distance_to(c.pos)
				# quien se agacha y se queda quieto a distancia pasa desapercibido
				if (p.flags & Protocol.F_CROUCH) != 0 and p.noise < 1.0 and d > 7.0:
					_enter(c, St.SEARCH, 4.0)
				else:
					_enter(c, St.CHASE, 0.0)
		St.CHASE:
			var p: ServerPlayer = srv.players.get(int(c.target))
			c.chase = float(c.chase) + dt
			if p == null or p.down or srv.world.in_safe_zone(p.pos.x, p.pos.z) or float(c.chase) > 18.0 or (c.pos as Vector3).distance_to(c.home) > float(def.leash):
				_enter(c, St.RETURN, 40.0)
				c.cool = 6.0
				return
			var d := p.pos.distance_to(c.pos)
			var visible := not s.is_empty() and (s.player as ServerPlayer).peer == p.peer and bool(s.seen)
			if visible:
				c.seen = p.pos
				c.lost = 0.0
			else:
				c.lost = float(c.lost) + dt
				if float(c.lost) > 3.0 or p.indoors >= 0:
					_enter(c, St.SEARCH, 7.0)
					return
			if srv.ws.fire_near(c.pos) > 0.2 or (bool(def.get("fear_light", false)) and srv.env.is_night() and (p.flags & Protocol.F_LIGHT) != 0 and d < 11.0 and _rng.randf() < 0.5 * dt):
				_retreat(c, p.pos)
				srv.progress.count(p, "deterred")
				return
			if d <= float(def.contact):
				_hit(c, p)
				return
			_go(c, c.seen, float(def.run), dt)
		St.SEARCH:
			if not _go(c, c.seen, float(def.walk), dt):
				pass
			if float(c.t) <= 0.0:
				_enter(c, St.RETURN, 40.0)
		St.RETREAT:
			if _go(c, c.goal, float(def.run), dt) or float(c.t) <= 0.0:
				_enter(c, St.RECOVER, 5.0)
		St.RETURN:
			if _go(c, c.home, float(def.walk) * 1.2, dt) or float(c.t) <= 0.0 or (c.pos as Vector3).distance_to(c.home) < float(c.home_r) * 0.5:
				_enter(c, St.IDLE, 3.0)
		St.RECOVER:
			if float(c.t) <= 0.0:
				_enter(c, St.RETURN, 40.0)

func _hit(c: Dictionary, p: ServerPlayer) -> void:
	var hit: Dictionary = c.def.get("hit", {})
	srv.survival.damage(p, float(hit.get("health", 0.0)), String(c.type))
	p.stamina = maxf(0.0, p.stamina - float(hit.get("stamina", 0.0)))
	var eff: Variant = hit.get("effect")
	if eff is Array:
		p.add_effect(String(eff[0]), float(eff[1]))
	p.dirty_stats = true
	srv.notify(p, "creature_hit", {"type": c.type})
	_enter(c, St.RECOVER, 6.0)
	c.cool = 10.0

func _retreat(c: Dictionary, from: Vector3) -> void:
	var away := ((c.pos as Vector3) - from)
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	var g := (c.pos as Vector3) + away * 30.0
	c.goal = Vector3(g.x, 0, g.z)
	c.path = PackedVector2Array()
	c.cool = 14.0
	_enter(c, St.RETREAT, 7.0)
	srv.send_near(c.pos, 70.0, Protocol.S.EMOTE, [-int(c.id), 2])

## El jugador hace ruido con el espantador: las criaturas cercanas se retiran.
func deter(p: ServerPlayer, radius: float) -> void:
	var n := 0
	for c: Dictionary in list:
		if (c.pos as Vector3).distance_to(p.pos) <= radius and int(c.state) != St.DORMANT:
			if String(c.def.behavior) == "stalker":
				_retreat(c, p.pos)
				n += 1
			elif String(c.def.behavior) == "skittish":
				c.seen = p.pos
				_enter(c, St.FLEE, 6.0)
	if n > 0:
		srv.progress.count(p, "deterred")

# ---- Zarzo: asustadizo -----------------------------------------------------------------------------------------------
func _skittish(c: Dictionary, dt: float) -> void:
	var def: Dictionary = c.def
	var s := _sense(c)
	var st := int(c.state)
	if not s.is_empty() and st != St.CURL:
		var d := float(s.dist)
		if d < 2.2 and st != St.FLEE:
			_enter(c, St.CURL, 6.0)
			return
		if d < 9.0 or bool(s.heard):
			c.seen = (s.player as ServerPlayer).pos
			if st != St.FLEE:
				_enter(c, St.FLEE, 5.0)
	match int(c.state):
		St.IDLE:
			if float(c.t) <= 0.0:
				c.goal = _random_point(c.home, float(c.home_r), false)
				_enter(c, St.PATROL, 20.0)
		St.PATROL:
			if _go(c, c.goal, float(def.walk), dt) or float(c.t) <= 0.0 or float(c.stuck) > 1.5:
				_enter(c, St.IDLE, _rng.randf_range(4.0, 12.0))
		St.FLEE:
			var away := (c.pos as Vector3) - (c.seen as Vector3)
			away.y = 0
			var g := (c.pos as Vector3) + (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)) * 12.0
			_go(c, g, float(def.run), dt)
			if float(c.t) <= 0.0 or float(c.stuck) > 1.0:
				_enter(c, St.IDLE, 3.0)
		St.CURL:
			if float(c.t) <= 0.0:
				_enter(c, St.FLEE, 4.0)

# ---- Farol: flotador del marjal ---------------------------------------------------------------------------------------------
func _drifter(c: Dictionary, dt: float) -> void:
	var def: Dictionary = c.def
	var s := _sense(c)
	var st := int(c.state)
	if st in [St.IDLE, St.PATROL, St.INVESTIGATE] and not s.is_empty() and float(c.cool) <= 0.0:
		var p: ServerPlayer = s.player
		c.seen = p.pos
		c.target = p.peer
		if float(s.dist) <= float(def.contact):
			_enter(c, St.ALERT, 1.4)
			srv.send_near(c.pos, 50.0, Protocol.S.EMOTE, [-int(c.id), 3])
			return
		if st != St.INVESTIGATE and (bool(s.lit) or float(s.dist) < float(def.sight) * 0.6):
			_enter(c, St.INVESTIGATE, 20.0)
	match int(c.state):
		St.IDLE:
			if float(c.t) <= 0.0:
				c.goal = _random_point(c.home, float(c.home_r), true)
				_enter(c, St.PATROL, 40.0)
		St.PATROL:
			if _go(c, c.goal, float(def.walk), dt, true) or float(c.t) <= 0.0:
				_enter(c, St.IDLE, _rng.randf_range(2.0, 6.0))
		St.INVESTIGATE:
			if s.is_empty() or float(c.t) <= 0.0 or (c.pos as Vector3).distance_to(c.home) > float(def.leash):
				_enter(c, St.RETURN, 30.0)
			else:
				_go(c, c.seen, float(def.run), dt, true)
		St.ALERT:
			if float(c.t) <= 0.0:
				for p: ServerPlayer in srv.players.values():
					if p.pos.distance_to(c.pos) <= float(def.contact) + 1.2 and not p.down:
						if srv.survival.mask_working(p):
							srv.notify(p, "spores_blocked")
						else:
							var eff: Array = (def.hit as Dictionary).effect
							p.add_effect(String(eff[0]), float(eff[1]))
							p.stamina = maxf(0.0, p.stamina - 25.0)
							srv.notify(p, "creature_hit", {"type": c.type})
				var away := (c.pos as Vector3) - (c.seen as Vector3)
				away.y = 0
				c.goal = (c.pos as Vector3) + (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)) * 16.0
				c.cool = 22.0 + 20.0 * srv.env.rain
				_enter(c, St.RETREAT, 8.0)
		St.RETREAT:
			if _go(c, c.goal, float(def.run), dt, true) or float(c.t) <= 0.0:
				_enter(c, St.RECOVER, 10.0)
		St.RECOVER:
			if float(c.t) <= 0.0:
				_enter(c, St.RETURN, 30.0)
		St.RETURN:
			if _go(c, c.home, float(def.walk), dt, true) or float(c.t) <= 0.0 or (c.pos as Vector3).distance_to(c.home) < float(c.home_r):
				_enter(c, St.IDLE, 2.0)
	var y := _height(c.pos.x, c.pos.z, true) + 0.25 * sin(float(srv.now_ms) * 0.0012 + float(c.id))
	c.pos = Vector3(c.pos.x, y, c.pos.z)

func snapshot_for(p: ServerPlayer) -> Array:
	var out: Array = []
	var r2 := Protocol.CREATURE_RELEVANCE * Protocol.CREATURE_RELEVANCE
	for c: Dictionary in list:
		if int(c.state) == St.DORMANT:
			continue
		var pos: Vector3 = c.pos
		if pos.distance_squared_to(p.pos) < r2:
			out.append([int(c.id), int(c.tidx), snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01), snappedf(float(c.yaw), 0.01), int(c.state), int(c.moving)])
	return out
