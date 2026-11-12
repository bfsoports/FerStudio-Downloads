class_name ServerSocial
extends RefCounted
## ServerSocial — cooperación entre jugadores: grupos, permisos compartidos, chat, emotes,
## señales, intercambio de objetos y reportes.
##
## Datos: groups (id -> {leader, members[cuentas]}), member_of (cuenta -> id). Persisten en
## world.json. El intercambio es una oferta que el receptor acepta: el servidor mueve el
## objeto solo si en ese instante sigue existiendo, hay sitio y ambos están cerca.
## El chat se limita en frecuencia y longitud; los reportes se anotan en reports.log.

const MAX_GROUP := 6
const OFFER_TTL_MS := 30000

var srv: GameServer
var groups: Dictionary = {}
var member_of: Dictionary = {}
var invites: Dictionary = {}       # peer invitado -> id de grupo
var next_group := 1
var next_offer := 1
var _pos_acc := 0.0

func _init(server: GameServer) -> void:
	srv = server

func same_group(p: ServerPlayer, account: String) -> bool:
	var g := int(member_of.get(p.account, 0))
	return g != 0 and g == int(member_of.get(account, 0))

## ¿Puede el jugador usar esta estructura? perm: 0 privado, 1 grupo, 2 público.
func may_use(p: ServerPlayer, s: Dictionary) -> bool:
	if String(s.owner) == p.account or int(s.perm) == 2:
		return true
	if String(s.type) == "bulto":
		return srv.unix - float(s.t) > 600.0 or same_group(p, String(s.owner))
	return int(s.perm) == 1 and same_group(p, String(s.owner))

func group_packet(p: ServerPlayer) -> Dictionary:
	var gid := int(member_of.get(p.account, 0))
	p.group = gid
	if gid == 0 or not groups.has(gid):
		return {"id": 0, "members": []}
	var g: Dictionary = groups[gid]
	var members: Array = []
	for acc: String in g.members:
		var o: ServerPlayer = srv.by_account.get(acc)
		members.append({"name": String((srv.store.accounts.get(acc, {}) as Dictionary).get("name", "?")) if o == null else o.name, "id": 0 if o == null else o.peer,
			"leader": acc == String(g.leader)})
	return {"id": gid, "members": members}

func _sync(gid: int) -> void:
	if not groups.has(gid):
		return
	for acc: String in (groups[gid] as Dictionary).members:
		var o: ServerPlayer = srv.by_account.get(acc)
		if o != null:
			srv.send(o, Protocol.S.GROUP, group_packet(o))
			srv.broadcast(Protocol.S.PLAYER_UPDATE, o.public_info())

func on_group(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var op := Guard.s(d[0], 12)
	var target := Guard.i(d[1], 0, 1 << 30, 0) if d.size() > 1 else 0
	var gid := int(member_of.get(p.account, 0))
	match op:
		"create":
			if gid == 0:
				gid = next_group
				next_group += 1
				groups[gid] = {"leader": p.account, "members": [p.account]}
				member_of[p.account] = gid
				_sync(gid)
		"invite":
			var o: ServerPlayer = srv.players.get(target)
			if o == null or o.peer == p.peer:
				return
			if gid == 0:
				on_group(p, ["create"])
				gid = int(member_of.get(p.account, 0))
			if (groups[gid].members as Array).size() >= MAX_GROUP:
				srv.notify(p, "group_full")
				return
			if int(member_of.get(o.account, 0)) != 0:
				srv.notify(p, "already_grouped")
				return
			invites[o.peer] = gid
			srv.send(o, Protocol.S.GROUP, {"invite": gid, "from": p.name})
			srv.notify(p, "invite_sent", {"name": o.name})
		"accept":
			var want := int(invites.get(p.peer, 0))
			invites.erase(p.peer)
			if want == 0 or not groups.has(want) or gid != 0 or (groups[want].members as Array).size() >= MAX_GROUP:
				return
			(groups[want].members as Array).append(p.account)
			member_of[p.account] = want
			_sync(want)
		"decline":
			invites.erase(p.peer)
		"leave":
			_leave(p.account)
			srv.send(p, Protocol.S.GROUP, group_packet(p))
			srv.broadcast(Protocol.S.PLAYER_UPDATE, p.public_info())
		"kick":
			var o: ServerPlayer = srv.players.get(target)
			if o != null and gid != 0 and String(groups[gid].leader) == p.account and int(member_of.get(o.account, 0)) == gid and o.peer != p.peer:
				_leave(o.account)
				srv.send(o, Protocol.S.GROUP, group_packet(o))
				srv.broadcast(Protocol.S.PLAYER_UPDATE, o.public_info())

func _leave(account: String) -> void:
	var gid := int(member_of.get(account, 0))
	member_of.erase(account)
	if gid == 0 or not groups.has(gid):
		return
	var g: Dictionary = groups[gid]
	(g.members as Array).erase(account)
	if (g.members as Array).is_empty():
		groups.erase(gid)
		return
	if String(g.leader) == account:
		g.leader = g.members[0]
	_sync(gid)

func on_leave(p: ServerPlayer) -> void:
	invites.erase(p.peer)
	var gid := int(member_of.get(p.account, 0))
	if gid != 0:
		_sync.call_deferred(gid)

func tick(dt: float) -> void:
	_pos_acc += dt
	if _pos_acc < 2.0:
		return
	_pos_acc = 0.0
	for gid: int in groups.keys():            # posiciones de compañeros para mapa y HUD
		var online: Array = []
		for acc: String in (groups[gid] as Dictionary).members:
			var o: ServerPlayer = srv.by_account.get(acc)
			if o != null:
				online.append(o)
		if online.size() < 2:
			continue
		var pts: Array = []
		for o: ServerPlayer in online:
			pts.append([o.peer, snappedf(o.pos.x, 0.1), snappedf(o.pos.y, 0.1), snappedf(o.pos.z, 0.1), snappedf(o.hp, 1.0)])
		for o: ServerPlayer in online:
			srv.send(o, Protocol.S.GROUP, {"pos": pts}, false)

# ---- chat, emotes, señales, reportes ---------------------------------------------------------------------
func on_chat(p: ServerPlayer, d: Array) -> void:
	if d.is_empty() or srv.now_ms - p.last_chat_ms < 1200:
		return
	var channel := Guard.i(d[0], 0, 2, 0)
	var text := Guard.s(d[1], 140).strip_edges()
	if text == "":
		return
	p.last_chat_ms = srv.now_ms
	p.chat_log.append("%s [%d] %s" % [Time.get_time_string_from_system(), channel, text])
	if p.chat_log.size() > 12:
		p.chat_log.pop_front()
	var msg: Array = [channel, p.peer, p.name, text]
	match channel:
		0: srv.send_near(p.pos, 45.0, Protocol.S.CHAT, msg)
		1:
			var gid := int(member_of.get(p.account, 0))
			if gid == 0:
				srv.send(p, Protocol.S.CHAT, msg)
				return
			for acc: String in (groups[gid] as Dictionary).members:
				var o: ServerPlayer = srv.by_account.get(acc)
				if o != null:
					srv.send(o, Protocol.S.CHAT, msg)
		2:
			if bool(srv.options.global_chat):
				srv.broadcast(Protocol.S.CHAT, msg)

func on_emote(p: ServerPlayer, code: int) -> void:
	if code == 0:
		return
	var anims := {1: Protocol.A.WAVE, 2: Protocol.A.POINT, 3: Protocol.A.SIT}
	srv.set_anim(p, int(anims.get(code, Protocol.A.WAVE)), 600.0 if code == 3 else 1.6)
	srv.send_near(p.pos, 60.0, Protocol.S.EMOTE, [p.peer, code])

func on_mark(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var v: Variant = Guard.v3(d[0], d[1], d[2])
	if v == null or (v as Vector3).distance_to(p.pos) > 400.0:
		return
	var msg: Array = [p.peer, p.name, v.x, v.y, v.z]
	var gid := int(member_of.get(p.account, 0))
	if gid == 0:
		srv.send(p, Protocol.S.MARK, msg)
		return
	for acc: String in (groups[gid] as Dictionary).members:
		var o: ServerPlayer = srv.by_account.get(acc)
		if o != null:
			srv.send(o, Protocol.S.MARK, msg)

func on_report(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var o: ServerPlayer = srv.players.get(Guard.i(d[0], 0, 1 << 30, 0))
	if o == null or o.peer == p.peer:
		return
	srv.store.append_log("reports.log", "%s denuncia=%s(%s) denunciado=%s(%s) motivo=\"%s\" chat=%s" % [Time.get_datetime_string_from_system(), p.name, p.account.left(8),
		o.name, o.account.left(8), Guard.s(d[1], 120), JSON.stringify(o.chat_log)])
	srv.notify(p, "report_sent")

# ---- intercambio validado -------------------------------------------------------------------------------------
func on_trade(p: ServerPlayer, d: Array) -> void:
	if d.is_empty():
		return
	var op := Guard.s(d[0], 10)
	match op:
		"offer":
			if d.size() < 4:
				return
			var o: ServerPlayer = srv.players.get(Guard.i(d[1], 0, 1 << 30, 0))
			var slot := Guard.i(d[2], 0, 255, -1)
			var st: Variant = p.inv.get_slot(slot)
			if o == null or o.peer == p.peer or o.down or st == null:
				return
			if o.pos.distance_to(p.pos) > 5.0 or srv.world.segment_blocked(srv.eye(p), srv.eye(o), srv.door_open):
				srv.notify(p, "too_far")
				return
			var n: int = mini(Guard.i(d[3], 1, 999, 1), int(st.n))
			var oid := next_offer
			next_offer += 1
			o.pending_offers[oid] = {"from": p.peer, "account": p.account, "slot": slot, "item": String(st.id), "n": n, "t": srv.now_ms}
			srv.send(o, Protocol.S.TRADE, {"op": "offer", "id": oid, "from": p.name, "item": String(st.id), "n": n})
			srv.notify(p, "offer_sent", {"name": o.name})
		"accept":
			var oid := Guard.i(d[1], 0, 1 << 30, 0)
			var of: Variant = p.pending_offers.get(oid)
			p.pending_offers.erase(oid)
			if of == null or srv.now_ms - int(of.t) > OFFER_TTL_MS:
				srv.notify(p, "offer_expired")
				return
			var giver: ServerPlayer = srv.players.get(int(of.from))
			if giver == null or giver.account != String(of.account) or giver.pos.distance_to(p.pos) > 6.0:
				srv.notify(p, "offer_expired")
				return
			var st: Variant = giver.inv.get_slot(int(of.slot))
			if st == null or String(st.id) != String(of.item) or int(st.n) < int(of.n):
				srv.notify(p, "offer_expired")
				return
			if not Inventory.transfer(giver.inv, int(of.slot), p.inv, -1, int(of.n)):
				srv.notify(p, "no_room")
				srv.notify(giver, "offer_failed")
				return
			giver.dirty_inv = true
			p.dirty_inv = true
			srv.notify(p, "got", {"item": of.item, "n": of.n})
			srv.notify(giver, "offer_done", {"name": p.name})
			srv.progress.count(p, "trades")
			srv.progress.count(giver, "trades")
		"decline":
			p.pending_offers.erase(Guard.i(d[1], 0, 1 << 30, 0))

func save_state() -> Dictionary:
	var g: Dictionary = {}
	for gid: int in groups.keys():
		g[str(gid)] = groups[gid]
	return {"groups": g, "next": next_group}

func load_state(d: Dictionary) -> void:
	var g: Dictionary = d.get("groups", {})
	for ks: String in g.keys():
		var e: Dictionary = g[ks]
		if e.get("members") is Array and not (e.members as Array).is_empty():
			groups[int(ks)] = {"leader": String(e.get("leader", e.members[0])), "members": e.members}
			for acc: Variant in e.members:
				member_of[String(acc)] = int(ks)
	next_group = maxi(1, int(d.get("next", 1)))
