class_name ServerSurvival
extends RefCounted
## ServerSurvival — necesidades del personaje, estados y consecuencias (autoridad del servidor).
##
## Datos administrados: salud, hambre, sed, resistencia, confort térmico, fatiga, humedad y
## estados temporales de cada ServerPlayer. Tasas en TASAS (por segundo, dificultad normal).
## Lo llaman: GameServer (1 Hz por jugador), ServerActions (consumibles) y criaturas (golpes).
## Señales: ninguna (envía S.STATS / S.NOTIFY / S.DOWN). Sin conexión no hay desgaste.
## Prueba: tests/test_survival.gd.

const RATES := {"food": 0.030, "water": 0.042, "fatigue": 0.024, "sprint": 9.0, "swim": 6.0, "regen": 11.0, "regen_still": 14.0, "heal": 0.12}

var srv: GameServer

func _init(server: GameServer) -> void:
	srv = server

func diff(key: String) -> float:
	var d: Dictionary = (GameData.progression.get("difficulty", {}) as Dictionary).get(String(srv.options.difficulty), {})
	return float(d.get(key, 1.0))

func light_available(p: ServerPlayer) -> bool:
	var e: Variant = p.equip.get("mano")
	if e == null:
		return false
	var def: Dictionary = GameData.item(String(e.id))
	return (def.get("equip", {}) as Dictionary).has("light") and int(e.d) != 0

func mask_working(p: ServerPlayer) -> bool:
	var e: Variant = p.equip.get("cara")
	return e != null and bool((GameData.item(String(e.id)).get("equip", {}) as Dictionary).get("filter", false)) and int(e.d) > 0

func tick_player(p: ServerPlayer, dt: float) -> void:
	if p.down:
		return
	var w := srv.world
	var needs := diff("needs") * p.perk("needs", 1.0)
	var sprinting := (p.flags & Protocol.F_SPRINT) != 0
	var swimming := (p.flags & Protocol.F_SWIM) != 0
	var moving := srv.now_ms - p.last_move_ms < 400 and p.noise > 0.0
	p.indoors = w.building_at(p.pos + Vector3(0, 0.6, 0))
	p.sheltered = p.indoors >= 0 or srv.ws.shelter_near(p.pos)
	var fire := srv.ws.fire_near(p.pos)
	p.near_fire = fire > 0.05
	# ---- humedad ----
	var depth := w.water_depth(p.pos.x, p.pos.z) if p.pos.y < w.water_level + 0.2 else 0.0
	if depth > 0.25:
		p.wet = maxf(p.wet, clampf(0.4 + depth * 0.5, 0.0, 1.0))
	elif srv.env.rain > 0.2 and not p.sheltered:
		p.wet = minf(1.0, p.wet + 0.02 * srv.env.rain * (1.0 - clampf(p.equip_value("wet"), 0.0, 0.95)) * dt)
	else:
		p.wet = maxf(0.0, p.wet - (0.04 if p.near_fire else (0.012 if p.sheltered else 0.004)) * dt)
	_cond(p, "mojado", p.wet > 0.35)
	_cond(p, "a_cubierto", p.sheltered)
	_cond(p, "junto_al_fuego", p.near_fire)
	# ---- temperatura ----
	var felt := srv.env.ambient(p.pos) + p.equip_value("warmth") * 0.45 - p.wet * 6.0
	if p.sheltered:
		felt += 4.0
	else:
		felt -= srv.env.wind * 2.5
	felt += fire * 16.0
	if p.has_effect("abrigado"):
		felt += 6.0
	if sprinting:
		felt += 2.0
	var target := clampf((felt - 15.0) * 7.0, -100.0, 100.0)
	p.temp = lerpf(p.temp, target, clampf(0.035 * dt, 0.0, 1.0))
	_cond(p, "frio", p.temp < -45.0)
	_cond(p, "hipotermia", p.temp < -80.0)
	_cond(p, "calor", p.temp > 70.0)
	# ---- hambre, sed, fatiga ----
	p.food = maxf(0.0, p.food - RATES.food * needs * (1.3 if sprinting else 1.0) * dt)
	var wmul := (1.4 if sprinting else 1.0) * (1.6 if p.has_effect("calor") else 1.0)
	p.water = maxf(0.0, p.water - RATES.water * needs * wmul * dt)
	if p.has_effect("malestar"):
		p.water = maxf(0.0, p.water - 0.12 * dt)
	var fmul := (2.2 if sprinting else 1.0) * (0.7 if p.has_effect("descansado") else 1.0) * (1.5 if p.overloaded() else 1.0)
	if p.anim == Protocol.A.SIT and srv.now_ms < p.anim_until:
		fmul = -2.0
	p.fatigue = clampf(p.fatigue + RATES.fatigue * needs * fmul * dt, 0.0, 100.0)
	_cond(p, "hambriento", p.food <= 20.0)
	_cond(p, "sediento", p.water <= 20.0)
	_cond(p, "agotado", p.fatigue >= 85.0)
	# ---- bruma y esporas ----
	var mist := w.hazard_at(p.pos.x, p.pos.z)
	if mist > 0.2:
		if mask_working(p):
			var e: Dictionary = p.equip["cara"]
			if randf() < 0.05 * dt * mist:
				e.d = int(e.d) - 1
				p.dirty_inv = true
				if int(e.d) <= 0:
					srv.notify(p, "filter_spent")
			if not p.stats.has("mist_masked"):
				srv.progress.count(p, "mist_masked")
		else:
			p.add_effect("esporas", 20.0)
			if mist > 0.6:
				damage(p, 0.14 * mist * dt, "esporas")
	if p.has_effect("esporas"):
		p.fatigue = minf(100.0, p.fatigue + 0.1 * dt)
	# ---- resistencia ----
	if swimming:
		p.stamina = maxf(0.0, p.stamina - RATES.swim * dt)
		if p.stamina <= 0.0:
			damage(p, 1.2 * dt, "agua")
	elif sprinting:
		p.stamina = maxf(0.0, p.stamina - RATES.sprint * p.perk("sprint", 1.0) * (1.0 - p.equip_value("stamina")) * (1.35 if p.overloaded() else 1.0) * dt)
	else:
		var r: float = RATES.regen_still if not moving else RATES.regen
		for bad: String in ["hambriento", "sediento", "frio", "agotado"]:
			if p.has_effect(bad):
				r *= 0.6
		if p.has_effect("esporas"):
			r *= 0.5
		if p.has_effect("bien_alimentado"):
			r *= 1.25
		p.stamina = minf(100.0, p.stamina + r * dt)
	# ---- salud ----
	if p.food <= 0.0:
		damage(p, 0.22 * dt, "hambre")
	if p.water <= 0.0:
		damage(p, 0.3 * dt, "sed")
	if p.has_effect("hipotermia"):
		damage(p, 0.3 * dt, "frio")
	if p.hp > 0.0 and p.food > 40.0 and p.water > 40.0 and not p.has_effect("hipotermia") and not p.has_effect("esporas"):
		p.hp = minf(100.0, p.hp + RATES.heal * (2.0 if p.has_effect("bien_alimentado") else 1.0) * dt)
	if p.has_effect("alivio"):
		p.hp = minf(100.0, p.hp + 0.25 * dt)
	# ---- estados con duración ----
	for id: String in p.effects.keys():
		var left: float = float(p.effects[id])
		if left > 0.0:
			left -= dt
			if left <= 0.0:
				p.effects.erase(id)
				p.dirty_stats = true
			else:
				p.effects[id] = left
	# ---- luz en mano gasta carga ----
	if (p.flags & Protocol.F_LIGHT) != 0 and light_available(p):
		var h: Dictionary = p.equip["mano"]
		if randf() < 0.1 * dt:
			h.d = int(h.d) - 1
			p.dirty_inv = true
			if int(h.d) <= 0:
				srv.notify(p, "light_spent")
	p.days_alive += dt / maxf(120.0, float(srv.options.day_length))
	p.noise = maxf(0.0, p.noise - 12.0 * dt)
	if p.hp <= 0.0:
		_go_down(p)

func _cond(p: ServerPlayer, id: String, on: bool) -> void:
	if on:
		if not p.effects.has(id):
			p.effects[id] = -1.0
			p.dirty_stats = true
			if bool((GameData.effects.get(id, {}) as Dictionary).get("bad", false)):
				srv.notify(p, "effect", {"id": id})
	elif p.effects.has(id) and float(p.effects[id]) < 0.0:
		p.effects.erase(id)
		p.dirty_stats = true

func damage(p: ServerPlayer, amount: float, _cause: String) -> void:
	if p.down or amount <= 0.0:
		return
	p.hp = maxf(0.0, p.hp - amount * diff("damage"))
	p.dirty_stats = true

## Aplica los efectos "use" de un objeto consumible. Devuelve false si no hace nada.
func apply_use(p: ServerPlayer, use: Dictionary) -> bool:
	if use.is_empty():
		return false
	p.hp = clampf(p.hp + float(use.get("health", 0.0)), 0.0, 100.0)
	p.food = clampf(p.food + float(use.get("food", 0.0)), 0.0, 100.0)
	p.water = clampf(p.water + float(use.get("water", 0.0)), 0.0, 100.0)
	p.stamina = clampf(p.stamina + float(use.get("stamina", 0.0)), 0.0, 100.0)
	p.temp = clampf(p.temp + float(use.get("temp", 0.0)), -100.0, 100.0)
	for c: String in use.get("cure", []):
		p.clear_effect(c)
	var eff: Variant = use.get("effect")
	if eff is Array and (eff as Array).size() >= 3 and randf() <= float(eff[2]):
		p.add_effect(String(eff[0]), float(eff[1]))
	p.dirty_stats = true
	return true

func _go_down(p: ServerPlayer) -> void:
	p.down = true
	p.down_ms = srv.now_ms
	p.flags |= Protocol.F_DOWN
	srv.actions.cancel_action(p, true)
	srv.ws.close_container(p)
	# lo que llevaba en el inventario queda en un bulto recuperable (lo equipado se conserva)
	if not p.inv.is_empty():
		var s := srv.ws.add_structure("bulto", Vector3(p.pos.x, srv.world.ground(p.pos.x, p.pos.z), p.pos.z), p.yaw, p.account, 1)
		var c := {"inv": Inventory.new(maxi(p.inv.size(), 12)), "gen": srv.unix, "by": 0, "table": ""}
		for st: Variant in p.inv.slots:
			if st != null:
				(c.inv as Inventory).add(String(st.id), int(st.n), int(st.d))
		srv.ws.containers[ServerWorld.STRUCT_CONTAINER + int(s.id)] = c
		p.inv = Inventory.new(p.slot_count())
		p.dirty_inv = true
	p.stat_add("collapses")
	p.days_alive = 0.0
	srv.send(p, Protocol.S.DOWN, {"wait": 4.0})
	srv.send(p, Protocol.S.STATS, p.stats_packet())

func on_respawn(p: ServerPlayer) -> void:
	if not p.down or srv.now_ms - p.down_ms < 3500:
		return
	p.down = false
	p.flags &= ~Protocol.F_DOWN
	p.hp = 60.0
	p.food = maxf(p.food, 40.0)
	p.water = maxf(p.water, 40.0)
	p.stamina = 80.0
	p.fatigue = minf(p.fatigue, 30.0)
	p.temp = 0.0
	p.wet = 0.0
	p.effects.clear()
	var dest := p.respawn if p.respawn_set else srv._spawn_point(p)
	if p.respawn_set:
		var ok := false
		for s: Dictionary in srv.ws.structures_near(p.respawn, 3.0):
			if bool((GameData.structures.get(String(s.type), {}) as Dictionary).get("respawn", false)) and int(s.stage) >= 1:
				ok = true
		if not ok:
			p.respawn_set = false
			dest = srv._spawn_point(p)
	srv.teleport(p, dest + Vector3(0, 0.3, 0))
	srv.send(p, Protocol.S.RESPAWNED, {"pos": [dest.x, dest.y, dest.z]})
	p.dirty_stats = true
	p.dirty_inv = true
