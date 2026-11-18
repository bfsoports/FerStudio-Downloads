class_name RecipeValidator
extends RefCounted
## Valida una hamburguesa (lista de capas) o un ingrediente suelto contra su receta y calcula la calidad.
## Cada receta declara sus propias reglas: orden estricto/flexible, extras permitidos y número máximo de extras.

enum Status { CORRECT, VARIATION, INCOMPLETE, WRONG_INGREDIENTS, DUPLICATES, BAD_ORDER, BAD_COOKING, BURNT }

const QUALITY: Dictionary = {
	Status.CORRECT: 1.0, Status.VARIATION: 0.9, Status.BURNT: 0.4, Status.BAD_ORDER: 0.3,
	Status.BAD_COOKING: 0.25, Status.DUPLICATES: 0.25, Status.WRONG_INGREDIENTS: 0.2, Status.INCOMPLETE: 0.1,
}

static func is_ok(status: int) -> bool:
	return status == Status.CORRECT or status == Status.VARIATION

static func status_key(status: int) -> String:
	match status:
		Status.CORRECT:
			return "recipe.status.correct"
		Status.VARIATION:
			return "recipe.status.variation"
		Status.WRONG_INGREDIENTS:
			return "recipe.status.wrong"
		Status.DUPLICATES:
			return "recipe.status.duplicates"
		Status.BAD_ORDER:
			return "recipe.status.bad_order"
		Status.BAD_COOKING:
			return "recipe.status.bad_cooking"
		Status.BURNT:
			return "recipe.status.burnt"
	return "recipe.status.incomplete"

static func _res(status: int, perfect: bool = false) -> Dictionary:
	return {"status": status, "quality": float(QUALITY[status]), "perfect": perfect, "ok": is_ok(status)}

static func _counts(list: Array) -> Dictionary:
	var c: Dictionary = {}
	for id in list:
		c[str(id)] = int(c.get(str(id), 0)) + 1
	return c

## layers: [{"id": String, "state": int, "quality": float}] de abajo a arriba.
static func validate(recipe: Dictionary, layers: Array) -> Dictionary:
	if recipe.is_empty() or layers.is_empty():
		return _res(Status.INCOMPLETE)
	var req: Array = recipe.get("ingredients", [])
	var ids: Array = []
	for l in layers:
		ids.append(str(l["id"]))
	# 1) debe estar cerrada: pan inferior abajo y pan superior arriba
	if ids[0] != "bun_bottom" or ids[ids.size() - 1] != "bun_top":
		return _res(Status.INCOMPLETE)
	var extras_ok: Array = recipe.get("extras", [])
	var max_extras := Util.to_int(recipe.get("max_extras", 0))
	var need := _counts(req)
	var have := _counts(ids)
	# 2) ingredientes que la receta no contempla (solo se admiten los extras declarados)
	var extra_count := 0
	for id in have:
		if not need.has(id):
			if extras_ok.has(id):
				extra_count += int(have[id])
			else:
				return _res(Status.WRONG_INGREDIENTS)
	if extra_count > max_extras:
		return _res(Status.WRONG_INGREDIENTS)
	# 3) duplicados de ingredientes requeridos
	for id in need:
		if int(have.get(id, 0)) > int(need[id]):
			return _res(Status.DUPLICATES)
	# 4) ingredientes que faltan
	for id in need:
		if int(have.get(id, 0)) < int(need[id]):
			return _res(Status.INCOMPLETE)
	# 5) orden de montaje
	if str(recipe.get("order", "strict")) == "strict":
		var core: Array = []
		for id in ids:
			if need.has(id):
				core.append(id)
		if core != req:
			return _res(Status.BAD_ORDER)
	# 6) cocción
	var burnt := false
	var raw := false
	var doneness := 1.0
	for l in layers:
		if Catalog.cook_config(str(l["id"])).is_empty():
			continue
		var st := Util.to_int(l.get("state", 0))
		if st == FoodItem.State.BURNT:
			burnt = true
		elif st != FoodItem.State.COOKED:
			raw = true
		else:
			doneness = minf(doneness, Util.to_float(l.get("quality", 1.0), 1.0))
	if raw:
		return _res(Status.BAD_COOKING)
	if burnt:
		return _res(Status.BURNT)
	if extra_count > 0:
		return _res(Status.VARIATION)
	return _res(Status.CORRECT, doneness >= 0.99)

## Valida un ingrediente suelto del pedido (patatas, bebida).
static func validate_item(ingredient_id: String, state: int) -> Dictionary:
	if Catalog.cook_config(ingredient_id).is_empty():
		return _res(Status.CORRECT, true)
	if state == FoodItem.State.BURNT:
		return _res(Status.BURNT)
	if state != FoodItem.State.COOKED:
		return _res(Status.BAD_COOKING)
	return _res(Status.CORRECT, true)

## Combina los resultados de los componentes de un pedido: estado del peor, calidad media.
static func combine(results: Array) -> Dictionary:
	if results.is_empty():
		return _res(Status.INCOMPLETE)
	var worst: Dictionary = results[0]
	var total := 0.0
	var perfect := true
	var all_ok := true
	for r in results:
		total += float(r["quality"])
		if float(r["quality"]) < float(worst["quality"]):
			worst = r
		if not bool(r["perfect"]):
			perfect = false
		if not bool(r["ok"]):
			all_ok = false
	return {"status": int(worst["status"]), "quality": total / results.size(), "perfect": perfect and all_ok, "ok": all_ok}
