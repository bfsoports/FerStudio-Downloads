class_name DataValidator
extends RefCounted
## Valida los datos de contenido (JSON) para detectar errores de configuración antes de jugar.
## Devuelve una lista de textos de error; vacía = datos correctos. Hay una versión equivalente en tools/validate_data.py.

const KNOWN_STATS: Array = ["burgers_made", "customers_served", "orders_correct", "coins_earned", "no_burn_shifts",
	"perfect_burgers", "recipes_unlocked", "upgrades_bought", "levels_completed", "best_streak", "patties_cooked",
	"combos_served", "stars_total", "items_bought", "player_level", "shifts_played", "three_star_levels", "trays_washed"]
const WIN_KEYS: Array = ["orders", "income", "satisfaction", "no_burnt", "customers", "recipe"]

static func validate_all(db: Dictionary) -> Array:
	var errors: Array = []
	var ings: Dictionary = db.get("ingredients", {})
	var recs: Dictionary = db.get("recipes", {})
	var levels: Array = db.get("levels", [])
	_check_ingredients(ings, errors)
	_check_recipes(ings, recs, levels.size(), errors)
	_check_levels(recs, levels, errors)
	_check_missions(db.get("missions", []), errors)
	_check_upgrades(db.get("upgrades", {}), errors)
	_check_shop(db.get("shop_items", []), db.get("shop_categories", []), errors)
	_check_upgrade_content(recs, levels, db.get("upgrades", {}), db.get("shop_items", []), errors)
	return errors

## Contenido que depende de una mejora: recetas de «Recetas nuevas» y artículos del «Catálogo de decoración».
static func _check_upgrade_content(recs: Dictionary, levels: Array, upgrades: Dictionary, items: Array, errors: Array) -> void:
	for rid in recs:
		var ru: Variant = recs[rid].get("requires_upgrade", null)
		if ru == null:
			continue
		var rd: Dictionary = ru if ru is Dictionary else {}
		var uid := str(rd.get("id", ""))
		var ulv := Util.to_int(rd.get("level", 0))
		if not upgrades.has(uid) or ulv < 1 or ulv > Util.to_int(upgrades[uid].get("max_level", 0)):
			errors.append("receta %s: requires_upgrade inválido" % rid)
		for lv in levels:
			var pool: Array = lv.get("recipes", [])
			if pool.has(rid):
				errors.append("nivel %s: %s depende de una mejora y no puede estar en la lista fija" % [lv.get("id", "?"), rid])
	for it in items:
		if it.has("requires_upgrade") and not upgrades.has(str(it["requires_upgrade"])):
			errors.append("artículo %s: requires_upgrade inválido" % it.get("id", "?"))

static func _check_ingredients(ings: Dictionary, errors: Array) -> void:
	if ings.is_empty():
		errors.append("ingredients.json vacío")
	for id in ings:
		var d: Dictionary = ings[id]
		if not str(d.get("color", "")).is_valid_html_color():
			errors.append("ingrediente %s: color inválido" % id)
		var cook: Variant = d.get("cook", null)
		if cook != null:
			if not (cook is Dictionary) or Util.to_float(cook.get("cook_time", 0)) <= 0.0 or Util.to_float(cook.get("burn_time", 0)) <= 0.0:
				errors.append("ingrediente %s: configuración de cocción inválida" % id)

static func _check_recipes(ings: Dictionary, recs: Dictionary, level_count: int, errors: Array) -> void:
	for rid in recs:
		var r: Dictionary = recs[rid]
		var kind := str(r.get("kind", ""))
		if Util.to_int(r.get("price", 0)) <= 0:
			errors.append("receta %s: precio inválido" % rid)
		var ul := Util.to_int(r.get("unlock_level", 0))
		if ul < 1 or ul > level_count:
			errors.append("receta %s: nivel de desbloqueo fuera de rango" % rid)
		if kind == "burger":
			var list: Array = r.get("ingredients", [])
			if list.size() < 3 or str(list[0]) != "bun_bottom" or str(list[list.size() - 1]) != "bun_top":
				errors.append("receta %s: debe empezar con bun_bottom y acabar con bun_top" % rid)
			for i in list:
				if not ings.has(str(i)):
					errors.append("receta %s: ingrediente desconocido %s" % [rid, i])
				elif not bool(ings[str(i)].get("stackable", false)):
					errors.append("receta %s: %s no es apilable" % [rid, i])
			for x in r.get("extras", []):
				if not ings.has(str(x)) or not bool(ings[str(x)].get("stackable", false)):
					errors.append("receta %s: extra inválido %s" % [rid, x])
			if not ["strict", "flexible"].has(str(r.get("order", ""))):
				errors.append("receta %s: order debe ser strict o flexible" % rid)
		elif kind == "combo":
			var comps: Array = r.get("components", [])
			if comps.is_empty():
				errors.append("receta %s: combo sin componentes" % rid)
			for c in comps:
				var ctype := str(c.get("type", ""))
				var cid := str(c.get("id", ""))
				if ctype == "recipe":
					if not recs.has(cid) or str(recs[cid].get("kind", "")) != "burger":
						errors.append("receta %s: componente de receta inválido %s" % [rid, cid])
				elif ctype == "item":
					if not ings.has(cid):
						errors.append("receta %s: componente desconocido %s" % [rid, cid])
				else:
					errors.append("receta %s: tipo de componente inválido" % rid)
		else:
			errors.append("receta %s: kind desconocido" % rid)

static func _check_levels(recs: Dictionary, levels: Array, errors: Array) -> void:
	if levels.size() < 30:
		errors.append("se requieren al menos 30 niveles (hay %d)" % levels.size())
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var lid := Util.to_int(lv.get("id", 0))
		if lid != i + 1:
			errors.append("nivel %d: id no secuencial (%d)" % [i + 1, lid])
		var duration := Util.to_float(lv.get("duration", 0))
		var spawn := Util.to_float(lv.get("spawn_interval", 0))
		if duration <= 0.0 or spawn <= 0.0 or Util.to_float(lv.get("patience", 0)) <= 0.0:
			errors.append("nivel %d: duración, ritmo o paciencia inválidos" % lid)
			continue
		var pool: Array = lv.get("recipes", [])
		if pool.is_empty():
			errors.append("nivel %d: sin recetas" % lid)
		for rid in pool:
			if not recs.has(str(rid)):
				errors.append("nivel %d: receta desconocida %s" % [lid, rid])
			elif Util.to_int(recs[str(rid)].get("unlock_level", 999)) > lid:
				errors.append("nivel %d: usa %s antes de desbloquearla" % [lid, rid])
		var win: Dictionary = lv.get("win", {})
		if win.is_empty():
			errors.append("nivel %d: sin condición de victoria" % lid)
		for k in win:
			if not WIN_KEYS.has(str(k)):
				errors.append("nivel %d: condición desconocida %s" % [lid, k])
		var cap := (duration / spawn + 1.0) * 0.8
		if Util.to_float(win.get("orders", 0)) > cap or Util.to_float(win.get("customers", 0)) > cap:
			errors.append("nivel %d: objetivo de pedidos imposible para su duración" % lid)
		var rc: Variant = win.get("recipe", null)
		if rc is Dictionary and not pool.has(str(rc.get("id", ""))):
			errors.append("nivel %d: la receta objetivo no está en su lista" % lid)
		var si: Array = lv.get("star_income", [])
		if si.size() != 2 or Util.to_int(si[0]) >= Util.to_int(si[1]):
			errors.append("nivel %d: star_income inválido" % lid)
		elif win.has("income") and Util.to_int(win["income"]) > Util.to_int(si[0]):
			errors.append("nivel %d: la meta de ingresos supera la primera estrella" % lid)
		var lose: Dictionary = lv.get("lose", {})
		if Util.to_int(lose.get("max_failed", 0)) < 1:
			errors.append("nivel %d: lose.max_failed debe ser >= 1" % lid)

static func _check_missions(missions: Array, errors: Array) -> void:
	var seen: Dictionary = {}
	for m in missions:
		var id := str(m.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("misión con id vacío o repetido: %s" % id)
		seen[id] = true
		if not KNOWN_STATS.has(str(m.get("stat", ""))):
			errors.append("misión %s: estadística desconocida" % id)
		if Util.to_int(m.get("target", 0)) <= 0:
			errors.append("misión %s: objetivo inválido" % id)
		if not ["mission", "challenge", "achievement"].has(str(m.get("kind", ""))):
			errors.append("misión %s: kind inválido" % id)

static func _check_upgrades(upgrades: Dictionary, errors: Array) -> void:
	var stats_seen: Dictionary = {}
	for id in upgrades:
		var u: Dictionary = upgrades[id]
		var costs: Array = u.get("costs", [])
		if costs.size() != Util.to_int(u.get("max_level", 0)) or costs.is_empty():
			errors.append("mejora %s: costs debe tener max_level elementos" % id)
		var stat_key := str(u.get("effect", {}).get("stat", ""))
		if stat_key == "" or stats_seen.has(stat_key):
			errors.append("mejora %s: efecto vacío o repetido" % id)
		stats_seen[stat_key] = true

static func _check_shop(items: Array, categories: Array, errors: Array) -> void:
	var first_free: Dictionary = {}
	for it in items:
		var cat := str(it.get("category", ""))
		if not categories.has(cat):
			errors.append("artículo %s: categoría desconocida" % it.get("id", "?"))
		if Util.to_int(it.get("price", -1)) < 0:
			errors.append("artículo %s: precio inválido" % it.get("id", "?"))
		if not first_free.has(cat):
			first_free[cat] = Util.to_int(it.get("price", -1)) == 0
	for cat in categories:
		if not first_free.get(cat, false):
			errors.append("categoría %s: el primer artículo debe ser gratuito" % cat)
