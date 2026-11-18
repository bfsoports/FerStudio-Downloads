class_name RecipeCard
extends RefCounted
## Tarjeta de receta reutilizable (pantalla de recetas del menú y panel de recetas durante la partida).
## De ancho fijo: la cabecera lleva el icono, el nombre y el precio; la composición y las reglas ocupan todo el ancho.

static func build(recipe_id: String, locked: bool, w: float = 470.0, is_new: bool = false) -> Control:
	var r := Catalog.recipe(recipe_id)
	var card := UIKit.card("PanelFlat")
	card.custom_minimum_size = Vector2(w, 0)
	var v := UIKit.vbox(6)
	card.add_child(v)
	var head := UIKit.hbox(12)
	v.add_child(head)
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(72, 72)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon_box.add_child(UIKit.icon_rect("lock", 52))
	else:
		icon_box.add_child(UIKit.burger_icon(Catalog.recipe_layers(recipe_id), 54))
	head.add_child(icon_box)
	var title_col := UIKit.vbox(2)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := UIKit.label(Catalog.name_of(r), "LabelHeader", 24)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(name_l)
	if is_new and not locked:
		title_col.add_child(UIKit.label(Loc.t("ui.new"), "LabelGold", 15))
	if locked:
		var lock_text := Loc.t("recipe.locked", [Util.to_int(r.get("unlock_level", 1))])
		if not GameState.recipe_upgrade_ok(recipe_id):
			var rd: Dictionary = r.get("requires_upgrade", {})
			var up_name := Catalog.name_of(Catalog.upgrades.get(str(rd.get("id", "")), {}))
			lock_text = Loc.t("recipe.locked_upgrade", [up_name, Util.to_int(rd.get("level", 1), 1)])
		var lock_l := UIKit.label(lock_text, "LabelMuted", 16)
		lock_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_col.add_child(lock_l)
	head.add_child(title_col)
	var side := UIKit.vbox(2)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(UIKit.coin_chip(Util.to_int(r.get("price", 0)), 26))
	var xp_l := UIKit.label(Loc.t("recipe.xp", [Util.to_int(r.get("xp", 0))]), "LabelMuted", 16)
	xp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(xp_l)
	head.add_child(side)
	if not locked:
		var comp := UIKit.label(_composition(r), "LabelLight", 17)
		comp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(comp)
		var extra := _rules(r)
		if extra != "":
			var rl := UIKit.label(extra, "LabelMuted", 15)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(rl)
	return card

## Tarjeta grande para el panel de recetas del turno: aprovecha todo el ancho disponible con los pasos numerados de
## abajo arriba (con el color de cada ingrediente y dónde se cocina) y la hamburguesa dibujada en grande al lado.
static func build_large(recipe_id: String, w: float) -> Control:
	var r := Catalog.recipe(recipe_id)
	var big := w >= 520.0
	var card := UIKit.card("PanelFlat")
	card.custom_minimum_size = Vector2(w, 0)
	var v := UIKit.vbox(10)
	card.add_child(v)
	# cabecera: nombre, reglas y precio
	var head := UIKit.hbox(14)
	v.add_child(head)
	var title_col := UIKit.vbox(2)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := UIKit.label(Catalog.name_of(r), "LabelHeader", 34 if big else 26)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_col.add_child(name_l)
	var rules := _rules(r)
	if rules != "":
		var rl := UIKit.label(rules, "LabelMuted", 18 if big else 16)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_col.add_child(rl)
	head.add_child(title_col)
	var side := UIKit.vbox(4)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(UIKit.coin_chip(Util.to_int(r.get("price", 0)), 34 if big else 28))
	var xp_l := UIKit.label(Loc.t("recipe.xp", [Util.to_int(r.get("xp", 0))]), "LabelMuted", 18)
	xp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(xp_l)
	head.add_child(side)
	v.add_child(UIKit.divider())
	# cuerpo: pasos a la izquierda y la hamburguesa grande a la derecha
	var body := UIKit.hbox(18)
	v.add_child(body)
	var steps := UIKit.vbox(8 if big else 6)
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(steps)
	steps.add_child(UIKit.label(Loc.t("recipe.how"), "LabelGold", 19 if big else 16))
	var layers: Array = Catalog.recipe_layers(recipe_id)
	var n := 1
	for i in layers.size():
		steps.add_child(_step_row(n, str(layers[i]), big))
		n += 1
	if str(r.get("kind", "")) == "combo":
		for c in r.get("components", []):
			var cd: Dictionary = c
			if str(cd.get("type", "")) == "item":
				steps.add_child(_step_row(n, str(cd.get("id", "")), big, true))
				n += 1
	var extras: Array = r.get("extras", [])
	if not extras.is_empty():
		var names: Array = []
		for id in extras:
			names.append(Catalog.ingredient_name(str(id)))
		var ex := UIKit.label(Loc.t("recipe.extras", [Util.to_int(r.get("max_extras", 0)), ", ".join(names)]), "LabelMuted", 17 if big else 15)
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		steps.add_child(ex)
	var art := CenterContainer.new()
	art.custom_minimum_size = Vector2(190.0 if big else 120.0, 0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(UIKit.burger_icon(layers, 150.0 if big else 96.0, 2.6 if big else 1.8))
	body.add_child(art)
	return card

## Una fila de paso: número, muestra de color del ingrediente, nombre y dónde se prepara.
static func _step_row(n: int, ingredient_id: String, big: bool, served_apart: bool = false) -> HBoxContainer:
	var row := UIKit.hbox(10)
	var num := UIKit.label(("+" if served_apart else str(n)), "LabelHeader", 22 if big else 18)
	num.custom_minimum_size = Vector2(30 if big else 24, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(num)
	var sw := Panel.new()
	sw.add_theme_stylebox_override("panel", UITheme.box(Catalog.ingredient_color(ingredient_id), UITheme.WIN_EDGE, 8, 2, false, 0))
	sw.custom_minimum_size = Vector2(44 if big else 34, 24 if big else 20)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sw)
	var name_l := UIKit.label(Catalog.ingredient_name(ingredient_id), "LabelLight", 23 if big else 19)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var where := ""
	var cook := Catalog.cook_config(ingredient_id)
	if not cook.is_empty():
		where = Loc.t("recipe.cook_fryer") if str(cook.get("station", "grill")) == "fryer" else Loc.t("recipe.cook_grill")
	elif ingredient_id == "drink":
		where = Loc.t("recipe.from_dispenser")
	if served_apart:
		where = (where + " · " if where != "" else "") + Loc.t("recipe.on_tray")
	if where != "":
		var wl := UIKit.label(where, "LabelMuted", 17 if big else 15)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(wl)
	return row

static func _composition(r: Dictionary) -> String:
	if str(r.get("kind", "")) == "combo":
		for c in r.get("components", []):
			if str(c.get("type", "")) == "recipe":
				return Loc.t("recipe.combo_desc", [Catalog.name_of(Catalog.recipe(str(c.get("id", ""))))])
		return ""
	var names: Array = []
	for id in r.get("ingredients", []):
		names.append(Catalog.ingredient_name(str(id)))
	return " + ".join(names)

static func _rules(r: Dictionary) -> String:
	if str(r.get("kind", "")) == "combo":
		return ""
	var parts: Array = []
	parts.append(Loc.t("recipe.order_strict") if str(r.get("order", "strict")) == "strict" else Loc.t("recipe.order_flexible"))
	var extras: Array = r.get("extras", [])
	if not extras.is_empty():
		var names: Array = []
		for id in extras:
			names.append(Catalog.ingredient_name(str(id)))
		parts.append(Loc.t("recipe.extras", [Util.to_int(r.get("max_extras", 0)), ", ".join(names)]))
	return "  |  ".join(parts)
