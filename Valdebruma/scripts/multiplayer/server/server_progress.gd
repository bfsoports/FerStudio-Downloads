class_name ServerProgress
extends RefCounted
## ServerProgress — progresión persistente: experiencia y nivel, lugares descubiertos,
## desafíos, logros, encargos del tablón (contratos de exploración) y cosméticos.
##
## Datos: ServerPlayer.xp/places/docs/stats/done/contracts. Todo se concede aquí, en el
## servidor, a partir de hechos validados (recoger, construir, descubrir…).

const MAX_CONTRACTS := 3

var srv: GameServer

func _init(server: GameServer) -> void:
	srv = server

func add_xp(p: ServerPlayer, amount: int) -> void:
	if amount <= 0:
		return
	var before := p.level()
	p.xp += amount
	if p.level() > before:
		srv.notify(p, "level_up", {"level": p.level()})
		var extra := p.inv.resize(p.slot_count())
		p.dirty_inv = true
		for st: Dictionary in extra:
			srv.ws.drop_item(String(st.id), int(st.n), int(st.d), p.pos)

## Suma a un contador y comprueba desafíos y logros ligados a él.
func count(p: ServerPlayer, key: String, amount := 1.0) -> void:
	p.stat_add(key, amount)
	_check(p, key)

func _check(p: ServerPlayer, key: String) -> void:
	var value := float(p.stats.get(key, 0.0))
	var changed := false
	for group: String in ["challenges", "achievements"]:
		var defs: Dictionary = GameData.progression.get(group, {})
		for id: String in defs.keys():
			var c: Dictionary = defs[id]
			if String(c.stat) == key and not p.done.has(id) and value >= float(c.goal):
				p.done[id] = true
				changed = true
				add_xp(p, int(c.get("xp", 25)))
				srv.notify(p, "challenge_done", {"id": id, "group": group})
	if changed:
		srv.send(p, Protocol.S.PROGRESS, p.progress_packet())

func on_login(p: ServerPlayer) -> void:
	count(p, "logins")
	srv.send(p, Protocol.S.PROGRESS, p.progress_packet())

func on_doc(p: ServerPlayer, doc_id: String) -> void:
	for id: String in p.contracts.keys():
		var c: Dictionary = (GameData.progression.contracts as Dictionary).get(id, {})
		if String(p.contracts[id]) == "active" and String(c.get("read", "")) == doc_id:
			p.contracts[id] = "ready"
			srv.notify(p, "contract_ready", {"id": id})
	srv.send(p, Protocol.S.PROGRESS, p.progress_packet())

func tick_player(p: ServerPlayer, _dt: float) -> void:
	if p.down:
		return
	var place := srv.world.place_at(p.pos.x, p.pos.z)
	if not place.is_empty():
		var id := String(place.id)
		if not p.places.has(id):
			p.places[id] = true
			p.stats["places"] = float(p.places.size())
			add_xp(p, int(place.get("xp", 20)))
			srv.notify(p, "place", {"id": id, "name": place.name, "secret": place.get("secret", false)})
			_check(p, "places")
			count(p, "place:" + id)
			if bool(place.get("secret", false)):
				count(p, "secrets")
			if p.group != 0:
				count(p, "group_places")
			srv.send(p, Protocol.S.PROGRESS, p.progress_packet())
		for cid: String in p.contracts.keys():
			var c: Dictionary = (GameData.progression.contracts as Dictionary).get(cid, {})
			if String(p.contracts[cid]) == "active" and String(c.get("visit", "")) == id:
				p.contracts[cid] = "ready"
				srv.notify(p, "contract_ready", {"id": cid})
				srv.send(p, Protocol.S.PROGRESS, p.progress_packet())
	var days := floorf(p.days_alive)
	if days > float(p.stats.get("days", 0.0)):
		p.stats["days"] = days
		_check(p, "days")
	if srv.env.is_night() and not p.sheltered:
		p.stats["night_acc"] = float(p.stats.get("night_acc", 0.0)) + _dt
		if float(p.stats.night_acc) > float(srv.options.day_length) * 0.36:
			p.stats["night_acc"] = 0.0
			count(p, "nights_out")
	elif not srv.env.is_night():
		p.stats["night_acc"] = 0.0
	if int(float(p.stats.get("distance", 0.0))) / 500 > int(float(p.stats.get("dist_mark", 0.0))):
		p.stats["dist_mark"] = float(int(float(p.stats.distance)) / 500)
		_check(p, "distance")

# ---- encargos del tablón ------------------------------------------------------------------------------------
func send_board(p: ServerPlayer) -> void:
	if not srv.ws.station_near(p, "contracts"):
		return
	srv.notify(p, "board", {"contracts": p.contracts})

func on_contract(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var op := Guard.s(d[0], 10)
	var id := Guard.s(d[1], 32)
	var defs: Dictionary = GameData.progression.get("contracts", {})
	var c: Dictionary = defs.get(id, {})
	if c.is_empty():
		return
	if not srv.ws.station_near(p, "contracts"):
		srv.notify(p, "need_board")
		return
	var state := String(p.contracts.get(id, ""))
	match op:
		"accept":
			var active := 0
			for k: String in p.contracts.keys():
				if String(p.contracts[k]) in ["active", "ready"]:
					active += 1
			if state != "" or active >= MAX_CONTRACTS:
				srv.notify(p, "contract_limit")
				return
			p.contracts[id] = "active"
			if c.has("visit") and p.places.has(String(c.visit)) and srv.world.place_at(p.pos.x, p.pos.z).get("id", "") == c.visit:
				p.contracts[id] = "ready"
			if c.has("read") and p.docs.has(String(c.read)):
				p.contracts[id] = "ready"
		"abandon":
			if state in ["active", "ready"]:
				p.contracts.erase(id)
		"turnin":
			if not (state in ["active", "ready"]):
				return
			if c.has("deliver"):
				if not p.inv.remove_all(c.deliver):
					srv.notify(p, "contract_missing")
					return
			elif state != "ready":
				srv.notify(p, "contract_missing")
				return
			p.contracts[id] = "done"
			for item: String in (c.get("reward", {}) as Dictionary).keys():
				srv.actions.give(p, item, int(c.reward[item]))
			p.dirty_inv = true
			add_xp(p, int(c.get("xp", 30)))
			count(p, "contracts")
			srv.notify(p, "contract_done", {"id": id})
	srv.send(p, Protocol.S.PROGRESS, p.progress_packet())
	srv.notify(p, "board", {"contracts": p.contracts})

# ---- cosméticos -------------------------------------------------------------------------------------------------
func cosmetic_ok(p: ServerPlayer, id: String, kind: String) -> bool:
	var c: Dictionary = (GameData.progression.get("cosmetics", {}) as Dictionary).get(id, {})
	if c.is_empty() or not c.has("color" if kind == "jacket" else "hat"):
		return false
	var unlock := String(c.get("unlock", ""))
	return unlock == "" or p.done.has(unlock)

func sanitize_cosmetics(p: ServerPlayer, wanted: Dictionary) -> void:
	for kind: String in ["jacket", "hat"]:
		var id := Guard.s(wanted.get(kind), 32)
		if id != "" and cosmetic_ok(p, id, kind):
			p.cosmetics[kind] = id
		elif not cosmetic_ok(p, String(p.cosmetics.get(kind, "")), kind):
			p.cosmetics[kind] = "chaqueta_oliva" if kind == "jacket" else "gorro_rojo"

func on_cosmetic(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var kind := Guard.s(d[0], 8)
	var id := Guard.s(d[1], 32)
	if kind in ["jacket", "hat"] and cosmetic_ok(p, id, kind):
		p.cosmetics[kind] = id
		srv.broadcast(Protocol.S.PLAYER_UPDATE, p.public_info())
