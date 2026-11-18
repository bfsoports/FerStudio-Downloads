class_name ShiftRules
extends RefCounted
## Reglas de victoria, derrota y estrellas de un turno (funciones puras sobre las estadísticas del turno).

static func avg_satisfaction(stats: Dictionary) -> float:
	var n := Util.to_int(stats.get("sat_count", 0))
	if n <= 0:
		return 100.0
	return Util.to_float(stats.get("sat_sum", 0.0)) / n * 100.0

static func net_income(stats: Dictionary) -> int:
	return maxi(0, Util.to_int(stats.get("income", 0)) - Util.to_int(stats.get("penalties", 0)))

## Lista de objetivos con su progreso: [{"key", "current", "target", "done", "recipe_id"}]
static func objective_progress(win: Dictionary, stats: Dictionary) -> Array:
	var out: Array = []
	for key in win:
		var k := str(key)
		var e := {"key": k, "current": 0, "target": 0, "done": false, "recipe_id": ""}
		match k:
			"orders":
				e["target"] = Util.to_int(win[key])
				e["current"] = Util.to_int(stats.get("orders_ok", 0))
			"customers":
				e["target"] = Util.to_int(win[key])
				e["current"] = Util.to_int(stats.get("customers", 0))
			"income":
				e["target"] = Util.to_int(win[key])
				e["current"] = net_income(stats)
			"satisfaction":
				e["target"] = Util.to_int(win[key])
				e["current"] = int(avg_satisfaction(stats))
			"no_burnt":
				e["target"] = 1
				e["current"] = 1 if Util.to_int(stats.get("burnt", 0)) == 0 else 0
			"recipe":
				var rc: Dictionary = win[key]
				e["recipe_id"] = str(rc.get("id", ""))
				e["target"] = Util.to_int(rc.get("count", 1))
				e["current"] = Util.to_int(stats.get("recipe_counts", {}).get(e["recipe_id"], 0))
		e["done"] = int(e["current"]) >= int(e["target"])
		out.append(e)
	return out

static func is_won(win: Dictionary, stats: Dictionary) -> bool:
	for e in objective_progress(win, stats):
		if not bool(e["done"]):
			return false
	return not win.is_empty()

static func has_lost(lose: Dictionary, stats: Dictionary) -> bool:
	var max_failed := Util.to_int(lose.get("max_failed", 0))
	return max_failed > 0 and Util.to_int(stats.get("failed", 0)) > max_failed

## 1 estrella por ganar, +1 y +1 al alcanzar los ingresos netos de star_income. 0 si se pierde.
static func stars(cfg: Dictionary, stats: Dictionary, won: bool) -> int:
	if not won:
		return 0
	var s := 1
	var thresholds: Array = cfg.get("star_income", [])
	var income := net_income(stats)
	if thresholds.size() >= 2:
		if income >= Util.to_int(thresholds[0]):
			s += 1
		if income >= Util.to_int(thresholds[1]):
			s += 1
	return s
