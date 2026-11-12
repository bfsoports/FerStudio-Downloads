class_name ServerPlayer
extends RefCounted
## ServerPlayer — estado autoritativo de un jugador conectado (solo existe en el servidor).
##
## Datos: identidad de sesión, posición validada, necesidades, estados, inventario y equipo,
## progresión, grupo y contadores anti-abuso. Persistencia: to_save()/from_save() (JSON
## versionado). El cliente nunca envía estos valores: solo peticiones que el servidor valida.

const SAVE_VERSION := 2
const BASE_SLOTS := 12
const EQUIP_SLOTS: Array[String] = ["cabeza", "torso", "piernas", "pies", "espalda", "cara", "mano"]

var peer := 0
var account := ""
var name := "Superviviente"
var cosmetics: Dictionary = {"jacket": "chaqueta_oliva", "hat": "gorro_rojo"}
var pos := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var flags := 0
var anim := 0                    # acción visible para los demás (emote, recoger, construir…)
var anim_until := 0
var hp := 100.0
var food := 80.0
var water := 80.0
var stamina := 100.0
var temp := 0.0                  # confort térmico: -100 frío … 0 … +100 calor
var fatigue := 10.0
var wet := 0.0
var effects: Dictionary = {}     # id -> segundos restantes (-1 = mientras dure la condición)
var inv: Inventory = Inventory.new(BASE_SLOTS)
var equip: Dictionary = {}
var quick: Array = ["", "", "", ""]
var xp := 0
var places: Dictionary = {}
var docs: Dictionary = {}
var stats: Dictionary = {}
var done: Dictionary = {}
var contracts: Dictionary = {}   # id -> "active" | "done"
var unlocked: Dictionary = {}
var group := 0
var respawn_set := false
var respawn := Vector3.ZERO
var down := false
var down_ms := 0
var days_alive := 0.0
var hidden := false
var first_login := true
# ---- transitorio (no se guarda) ----
var container := -1
var action: Dictionary = {}
var sectors: Dictionary = {}
var last_sector := -1
var last_move_ms := 0
var move_budget := 2.0
var move_strikes := 0
var last_correct_ms := 0
var tokens := 30.0
var tokens_ms := 0
var strikes := 0
var last_chat_ms := 0
var chat_log: Array = []
var pending_offers: Dictionary = {}
var noise := 0.0                 # radio de ruido reciente (lo consumen las criaturas)
var indoors := -1
var sheltered := false
var near_fire := false
var joined_ms := 0
var dirty_inv := true
var dirty_stats := true
var save_due_ms := 0

func _init() -> void:
	for s in EQUIP_SLOTS:
		equip[s] = null

func equipped_id(slot: String) -> String:
	var e: Variant = equip.get(slot)
	return String(e.id) if e != null else ""

func equip_value(key: String) -> float:
	var total := 0.0
	for s in EQUIP_SLOTS:
		var e: Variant = equip.get(s)
		if e != null:
			total += float((GameData.item(String(e.id)).get("equip", {}) as Dictionary).get(key, 0.0))
	return total

func has_tool(tool_id: String) -> bool:
	if tool_id == "":
		return true
	if equipped_id("mano") == tool_id:
		return true
	return inv.count(tool_id) > 0

func level() -> int:
	return GameData.level_for_xp(xp)

func perk(key: String, def: float) -> float:
	var perks: Dictionary = GameData.progression.get("perks", {})
	var value := def
	for lvl: String in perks.keys():
		if level() >= int(lvl) and (perks[lvl] as Dictionary).has(key):
			value = float(perks[lvl][key])
	return value

func slot_count() -> int:
	return BASE_SLOTS + int(equip_value("slots")) + int(perk("slots", 0.0))

func carry_limit() -> float:
	return 22.0 + equip_value("carry")

func carried_weight() -> float:
	var w := inv.weight()
	for s in EQUIP_SLOTS:
		var e: Variant = equip.get(s)
		if e != null:
			w += GameData.item_weight(String(e.id)) * 0.5      # lo puesto pesa menos
	return w

func overloaded() -> bool:
	return carried_weight() > carry_limit()

func has_effect(id: String) -> bool:
	return effects.has(id)

func add_effect(id: String, seconds: float) -> void:
	if not GameData.effects.has(id):
		return
	var cur: float = float(effects.get(id, 0.0))
	if cur < 0.0 and seconds >= 0.0:
		return
	effects[id] = seconds if seconds < 0.0 else maxf(cur, seconds)
	dirty_stats = true

func clear_effect(id: String) -> void:
	if effects.erase(id):
		dirty_stats = true

func stat_add(key: String, amount := 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + amount

func visible_equipment() -> Dictionary:
	var pack := 0
	if equipped_id("espalda") == "mochila_pequena":
		pack = 1
	elif equipped_id("espalda") == "mochila_grande":
		pack = 2
	return {"hat": equipped_id("cabeza") != "", "pack": pack, "mask": equipped_id("cara") != "", "held": equipped_id("mano"), "rain": equipped_id("torso") == "impermeable"}

func public_info() -> Dictionary:
	return {"id": peer, "name": name, "cos": cosmetics, "eq": visible_equipment(), "group": group, "level": level(), "hide": hidden}

func stats_packet() -> Dictionary:
	var eff: Array = []
	for id: String in effects.keys():
		eff.append([id, snappedf(float(effects[id]), 1.0)])
	return {"hp": snappedf(hp, 0.1), "food": snappedf(food, 0.1), "water": snappedf(water, 0.1), "sta": snappedf(stamina, 0.1), "temp": snappedf(temp, 0.1),
		"fat": snappedf(fatigue, 0.1), "wet": snappedf(wet, 0.01), "eff": eff, "w": snappedf(carried_weight(), 0.01), "wmax": carry_limit(), "down": down}

func inv_packet() -> Dictionary:
	var eq: Dictionary = {}
	for s in EQUIP_SLOTS:
		var e: Variant = equip.get(s)
		eq[s] = null if e == null else [String(e.id), int(e.n), int(e.d)]
	return {"slots": inv.to_data(), "equip": eq, "quick": quick}

func progress_packet() -> Dictionary:
	return {"xp": xp, "level": level(), "places": places.keys(), "docs": docs.keys(), "stats": stats, "done": done.keys(), "contracts": contracts,
		"respawn": [respawn.x, respawn.y, respawn.z] if respawn_set else null, "days": snappedf(days_alive, 0.01)}

func to_save() -> Dictionary:
	var eq: Dictionary = {}
	for s in EQUIP_SLOTS:
		var e: Variant = equip.get(s)
		eq[s] = null if e == null else [String(e.id), int(e.n), int(e.d)]
	var eff: Dictionary = {}
	for id: String in effects.keys():
		if float(effects[id]) > 0.0:
			eff[id] = effects[id]
	return {"v": SAVE_VERSION, "account": account, "name": name, "cos": cosmetics, "pos": [pos.x, pos.y, pos.z], "yaw": yaw,
		"hp": hp, "food": food, "water": water, "sta": stamina, "temp": temp, "fat": fatigue, "wet": wet, "eff": eff,
		"inv": inv.to_data(), "equip": eq, "quick": quick, "xp": xp, "places": places.keys(), "docs": docs.keys(), "stats": stats,
		"done": done.keys(), "contracts": contracts, "respawn": [respawn.x, respawn.y, respawn.z] if respawn_set else null,
		"down": down, "days": days_alive, "hidden": hidden, "saved": Time.get_unix_time_from_system()}

## Carga tolerante: cualquier campo ausente o inválido conserva su valor por defecto.
func from_save(d: Dictionary) -> void:
	var v := int(d.get("v", 1))
	first_login = false
	name = String(d.get("name", name))
	if d.get("cos") is Dictionary:
		cosmetics = d.cos
	var p: Variant = d.get("pos")
	if p is Array and (p as Array).size() == 3:
		pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	yaw = float(d.get("yaw", 0.0))
	hp = clampf(float(d.get("hp", 100.0)), 0.0, 100.0)
	food = clampf(float(d.get("food", 80.0)), 0.0, 100.0)
	water = clampf(float(d.get("water", 80.0)), 0.0, 100.0)
	stamina = clampf(float(d.get("sta", 100.0)), 0.0, 100.0)
	temp = clampf(float(d.get("temp", 0.0)), -100.0, 100.0)
	fatigue = clampf(float(d.get("fat", 10.0)), 0.0, 100.0)
	wet = clampf(float(d.get("wet", 0.0)), 0.0, 1.0)
	if d.get("eff") is Dictionary:
		for id: String in (d.eff as Dictionary).keys():
			if GameData.effects.has(id):
				effects[id] = float(d.eff[id])
	var eq: Variant = d.get("equip")
	if eq is Dictionary:
		for s in EQUIP_SLOTS:
			var e: Variant = (eq as Dictionary).get(s)
			if e is Array and (e as Array).size() >= 2 and GameData.has_item(String(e[0])):
				equip[s] = {"id": String(e[0]), "n": 1, "d": int(e[2]) if (e as Array).size() > 2 else -1}
	inv = Inventory.from_data(d.get("inv"), slot_count())
	var q: Variant = d.get("quick")
	if q is Array:
		for i in mini(4, (q as Array).size()):
			quick[i] = String(q[i])
	xp = maxi(0, int(d.get("xp", 0)))
	for k: Variant in d.get("places", []) as Array:
		places[String(k)] = true
	for k: Variant in d.get("docs", []) as Array:
		docs[String(k)] = true
	for k: Variant in d.get("done", []) as Array:
		done[String(k)] = true
	if d.get("stats") is Dictionary:
		stats = d.stats
	if d.get("contracts") is Dictionary:
		contracts = d.contracts
	var r: Variant = d.get("respawn")
	if r is Array and (r as Array).size() == 3:
		respawn = Vector3(float(r[0]), float(r[1]), float(r[2]))
		respawn_set = true
	down = bool(d.get("down", false))
	days_alive = float(d.get("days", 0.0))
	hidden = bool(d.get("hidden", false))
	if v < 2:      # migración v1 -> v2: la fatiga pasó de 0..1 a 0..100
		if fatigue <= 1.0:
			fatigue *= 100.0
