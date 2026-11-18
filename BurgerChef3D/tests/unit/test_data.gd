extends RefCounted
## Datos de contenido y localización.

func run(t) -> void:
	t.eq(Catalog.load_errors.size(), 0, "el catálogo no tiene errores de datos: %s" % str(Catalog.load_errors))
	t.eq(Catalog.levels.size(), 30, "hay 30 niveles")
	t.eq(Catalog.recipe_order.size(), 14, "hay 14 recetas (4 con la mejora «Recetas nuevas»)")
	t.eq(Catalog.ingredient_order.size(), 11, "hay 11 ingredientes (solo los que tienen modelo 3D real)")
	t.eq(Catalog.missions.size(), 41, "hay 41 misiones, desafíos y logros")
	t.ok(DataValidator.validate_all({}).size() > 0, "el validador detecta un catálogo vacío")
	var bad_levels: Array = [{"id": 5, "duration": 100, "spawn_interval": 10, "patience": 50, "recipes": ["classic"],
		"win": {"orders": 99}, "star_income": [10, 5], "lose": {"max_failed": 0}}]
	var errs := DataValidator.validate_all({"ingredients": Catalog.ingredients, "recipes": Catalog.recipes, "levels": bad_levels})
	t.ok(errs.size() >= 3, "el validador detecta niveles imposibles o mal numerados")
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		t.ok(Loc.t("menu.play") != "menu.play", "existe la traducción de menu.play en %s" % lang)
		for rid in Catalog.recipe_order:
			t.ok(Catalog.name_of(Catalog.recipe(rid)) != "", "la receta %s tiene nombre en %s" % [rid, lang])
	Loc.set_language("es")
	t.eq(Loc.t("menu.play"), "JUGAR", "el español es el idioma por defecto")
