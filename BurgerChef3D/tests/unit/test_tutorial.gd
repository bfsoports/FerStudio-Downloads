extends RefCounted
## Tutorial (pasos, textos y aislamiento de estadísticas) y contenido de mejora (recetas nuevas y catálogo de decoración).

func run(t) -> void:
	GameState.reset_to_defaults()
	# pasos y textos
	t.ok(Tutorial.STEPS.size() >= 15, "el tutorial tiene todos sus pasos")
	t.eq(str(Tutorial.STEPS[Tutorial.KITCHEN_FIRST]), "patty_take", "la cocina empieza cogiendo la carne")
	t.eq(str(Tutorial.STEPS[Tutorial.KITCHEN_LAST]), "to_tray", "la cocina termina poniendo la hamburguesa en la bandeja")
	t.eq(str(Tutorial.STEPS[Tutorial.KITCHEN_LAST + 1]), "bell", "después de la bandeja se toca la campana")
	for id in Tutorial.STEPS:
		var key := "tut." + str(id)
		if id == "move" or id == "look":
			key = "tut.%s_touch" % id
		t.ok(Loc.t(key) != key, "hay texto para el paso %s" % id)
	t.ok(not Catalog.recipe(Tutorial.RECIPE).is_empty(), "la receta del tutorial existe")

	# en el tutorial nada cuenta para estadísticas ni paga
	GameState.tracking_enabled = false
	GameState.add_stat("burgers_made", 1)
	t.eq(GameState.stat("burgers_made"), 0, "en el tutorial no se cuentan estadísticas")
	GameState.tracking_enabled = true
	GameState.add_stat("burgers_made", 1)
	t.eq(GameState.stat("burgers_made"), 1, "fuera del tutorial sí")
	var shift := ShiftManager.new()
	shift.mode = Const.MODE_TUTORIAL
	t.eq(shift.mode_factor(), 0.0, "el tutorial no paga monedas por pedido")
	shift.mode = Const.MODE_FREE
	t.eq(shift.mode_factor(), 0.5, "el modo libre paga la mitad")
	shift.free()

	# recetas nuevas: dependen de la mejora y del progreso de la campaña
	t.ok(not GameState.recipe_upgrade_ok("veggie_cheese"), "sin la mejora la receta nueva está bloqueada")
	t.ok(GameState.recipe_upgrade_ok("classic"), "las recetas base no dependen de mejoras")
	GameState.highest_unlocked = 10
	t.ok(not GameState.unlocked_recipe_ids().has("veggie_cheese"), "sin la mejora no aparece en la carta")
	GameState.upgrades["recipe_book"] = 1
	t.ok(GameState.unlocked_recipe_ids().has("veggie_cheese"), "con la mejora nivel 1 aparece")
	t.ok(not GameState.unlocked_recipe_ids().has("double_bacon"), "las del nivel 2 de la mejora siguen bloqueadas")
	t.ok(GameState.campaign_recipes(6).has("classic_meal"), "las recetas de mejora entran en los niveles de campaña")
	t.ok(not GameState.campaign_recipes(4).has("veggie_cheese"), "pero no antes de su nivel")
	var fixed: Array = Catalog.level_def(6).get("recipes", [])
	t.ok(not fixed.has("classic_meal"), "la lista fija del nivel no cambia")
	t.ok(GameState.unseen_recipes().has("veggie_cheese"), "la receta nueva avisa como no vista")
	GameState.mark_recipes_seen()
	t.ok(GameState.unseen_recipes().is_empty(), "al abrir el libro se marca como vista")

	# catálogo de decoración
	GameState.coins = 10000
	GameState.level = 20
	t.eq(str(EconomyManager.can_buy_item("wall_coral")["reason"]), "shop.need_upgrade", "sin catálogo no se puede comprar")
	t.ok(not EconomyManager.unseen_items().has("wall_coral"), "lo que requiere mejora no avisa como nuevo")
	GameState.upgrades["decor_options"] = 1
	t.ok(bool(EconomyManager.can_buy_item("wall_coral")["ok"]), "con el catálogo se puede comprar")
	t.ok(EconomyManager.unseen_items().has("wall_coral"), "y avisa como nuevo")
	EconomyManager.mark_items_seen()
	t.ok(EconomyManager.unseen_items().is_empty(), "al abrir la tienda deja de avisar")
	GameState.upgrades["dishwasher"] = 2
	t.eq(EconomyManager.wash_speed(), 2.0, "el fregadero rápido al máximo lava el doble de rápido")

	# guardado de los campos nuevos
	GameState.tutorial_prompted = true
	var d := GameState.to_dict()
	GameState.from_dict(d)
	t.ok(GameState.tutorial_prompted, "se guarda que ya se ofreció el tutorial")
	t.ok(GameState.seen_recipes.has("veggie_cheese"), "se guardan las recetas vistas")
	d.erase("seen_recipes")
	GameState.from_dict(d)
	t.ok(GameState.unseen_recipes().is_empty(), "una partida antigua da por vistas las recetas ya desbloqueadas")
	GameState.reset_to_defaults()
