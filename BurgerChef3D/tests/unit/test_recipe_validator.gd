extends RefCounted
## Validación de recetas: correcta, variaciones, incompleta, ingredientes incorrectos, duplicados, orden y cocción.

const S = RecipeValidator.Status

func _l(id: String, state: int = 0) -> Dictionary:
	return {"id": id, "state": state, "quality": 1.0}

func _status(recipe_id: String, layers: Array) -> int:
	return int(RecipeValidator.validate(Catalog.recipe(recipe_id), layers)["status"])

func run(t) -> void:
	var cooked := FoodItem.State.COOKED
	var classic: Array = [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("tomato"), _l("bun_top")]
	t.eq(_status("classic", classic), S.CORRECT, "clásica correcta")
	t.ok(bool(RecipeValidator.validate(Catalog.recipe("classic"), classic)["perfect"]), "la clásica bien hecha es perfecta")
	t.eq(_status("classic", [_l("bun_bottom"), _l("tomato"), _l("patty", cooked), _l("lettuce"), _l("bun_top")]), S.CORRECT, "orden libre entre panes")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("tomato"), _l("onion"), _l("bun_top")]), S.VARIATION, "un extra permitido")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("tomato"), _l("onion"), _l("onion"), _l("bun_top")]), S.WRONG_INGREDIENTS, "demasiados extras")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("cheese"), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.WRONG_INGREDIENTS, "ingrediente no permitido")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("tomato")]), S.INCOMPLETE, "sin pan superior")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("bun_top")]), S.INCOMPLETE, "falta el tomate")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", cooked), _l("lettuce"), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.DUPLICATES, "lechuga duplicada")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", FoodItem.State.RAW), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.BAD_COOKING, "carne cruda")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", FoodItem.State.COOKING), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.BAD_COOKING, "carne a medio cocinar")
	t.eq(_status("classic", [_l("bun_bottom"), _l("patty", FoodItem.State.BURNT), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.BURNT, "carne quemada")
	t.eq(_status("cheese", [_l("bun_bottom"), _l("patty", cooked), _l("cheese"), _l("bun_top")]), S.CORRECT, "con queso correcta")
	t.eq(_status("cheese", [_l("bun_bottom"), _l("cheese"), _l("patty", cooked), _l("bun_top")]), S.BAD_ORDER, "orden estricto incumplido")
	t.eq(_status("double", [_l("bun_bottom"), _l("patty", cooked), _l("patty", cooked), _l("cheese"), _l("bun_top")]), S.CORRECT, "doble correcta")
	t.eq(_status("double", [_l("bun_bottom"), _l("patty", cooked), _l("cheese"), _l("bun_top")]), S.INCOMPLETE, "doble con una sola carne")
	t.eq(_status("bacon", [_l("bun_bottom"), _l("patty", cooked), _l("bacon", cooked), _l("cheese"), _l("bun_top")]), S.CORRECT, "con bacon correcta")
	t.eq(_status("veggie", [_l("bun_bottom"), _l("veggie_patty", cooked), _l("lettuce"), _l("tomato"), _l("bun_top")]), S.CORRECT, "vegetal correcta")
	t.eq(_status("classic", []), S.INCOMPLETE, "hamburguesa vacía")
	t.ok(float(RecipeValidator.validate(Catalog.recipe("classic"), classic)["quality"]) > float(RecipeValidator.QUALITY[S.BURNT]), "la calidad correcta supera a la quemada")
	t.eq(int(RecipeValidator.validate_item("fries", FoodItem.State.COOKED)["status"]), S.CORRECT, "patatas fritas correctas")
	t.eq(int(RecipeValidator.validate_item("fries", FoodItem.State.RAW)["status"]), S.BAD_COOKING, "patatas crudas")
	t.eq(int(RecipeValidator.validate_item("fries", FoodItem.State.BURNT)["status"]), S.BURNT, "patatas quemadas")
	t.eq(int(RecipeValidator.validate_item("drink", FoodItem.State.RAW)["status"]), S.CORRECT, "la bebida no se cocina")
	var combo := RecipeValidator.combine([RecipeValidator.validate(Catalog.recipe("classic"), classic), RecipeValidator.validate_item("fries", FoodItem.State.BURNT)])
	t.eq(int(combo["status"]), S.BURNT, "el combinado toma el peor estado")
	t.ok(not bool(combo["ok"]), "un componente quemado hace el pedido no válido")
