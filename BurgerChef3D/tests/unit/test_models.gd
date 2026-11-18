extends RefCounted
## Modelos 3D reales (KayKit Restaurant Bits, Kenney Food Kit y los propios de assets/models/custom/): todos los ingredientes tienen modelo, todos los
## modelos de la tabla se importan e instancian, y la comida cambia de modelo al cocinarse.
## Requiere que el editor de Godot haya importado ya assets/models/ (abrir el proyecto una vez).

func run(t) -> void:
	for id in Catalog.ingredient_order:
		t.ok(FoodModels.has_model(str(id)), "el ingrediente %s tiene modelo 3D real" % str(id))
		if Catalog.ingredient(str(id)).get("stackable", true):
			t.ok(FoodModels.layer_height(str(id)) > 0.01, "la capa %s tiene un grosor real" % str(id))
	for key in ModelTable.MODELS.keys():
		var path: String = ModelLib.ROOT + str((ModelTable.MODELS[key] as Array)[0])
		t.ok(ResourceLoader.exists(path), "existe e está importado el modelo %s" % path)
		var node := ModelLib.spawn(str(key))
		t.ok(node.get_child_count() > 0, "el modelo %s se instancia" % str(key))
		node.free()
	var cfg := Catalog.cook_config("patty")
	var cook_t := Util.to_float(cfg.get("cook_time", 8.0), 8.0)
	var burn_t := Util.to_float(cfg.get("burn_time", 8.0), 8.0)
	t.eq(FoodModels.cook_variant("patty", 0.0), "raw", "la carne cruda usa el modelo crudo")
	t.eq(FoodModels.cook_variant("patty", cook_t + 0.1), "done", "la carne cocinada usa el modelo cocinado")
	t.eq(FoodModels.cook_variant("patty", cook_t + burn_t), "burnt", "la carne quemada usa el modelo quemado")
	for id in ["patty", "veggie_patty", "bacon", "fries"]:
		var item := FoodModels.build_item(id, 0.0)
		var holder := item.get_meta("cook_holder") as Node3D
		t.ok(holder != null and holder.get_child_count() == 1, "%s crudo tiene un único modelo" % id)
		var ct := Util.to_float(Catalog.cook_config(id).get("cook_time", 8.0), 8.0)
		FoodModels.apply_cook_color(item, id, ct + 0.1)
		t.eq(str(holder.get_meta("cook_variant")), "done", "%s pasa al modelo cocinado" % id)
		t.eq(holder.get_child_count(), 1, "%s no acumula modelos al cambiar de fase" % id)
		item.free()
