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
	icon_box.custom_minimum_size = Vector2(84, 84)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon_box.add_child(UIKit.icon_rect("lock", 52))
	else:
		icon_box.add_child(UIKit.burger_stack(Catalog.recipe_layers(recipe_id), 64))
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

## Tarjeta grande para las recetas del turno (pantalla completa durante la partida). Simétrica: arriba el nombre con el
## precio y las reglas centrados; abajo, en dos mitades iguales, la hamburguesa dibujada con los iconos de sus
## ingredientes y los pasos numerados de abajo arriba, cada uno con su icono y dónde se prepara.
static func build_large(recipe_id: String, w: float, max_h: float = 440.0) -> Control:
	var r := Catalog.recipe(recipe_id)
	var big := w >= 700.0
	var card := UIKit.card("PanelFlat")
	card.custom_minimum_size = Vector2(w, 0)
	var body := UIKit.hbox(24)
	card.add_child(body)
	# mitad izquierda: nombre, precio, reglas y la hamburguesa «despiezada» con los iconos de sus ingredientes
	var left := UIKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(left)
	var name_l := UIKit.label(Catalog.name_of(r), "LabelTitle", 42 if big else 32)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(name_l)
	var chips := UIKit.hbox(12)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_child(UIKit.coin_chip(Util.to_int(r.get("price", 0)), 34 if big else 28))
	chips.add_child(UIKit.chip("star", Loc.t("recipe.xp", [Util.to_int(r.get("xp", 0))]), "LabelHeader", 30 if big else 26, 22 if big else 19))
	left.add_child(chips)
	var rules := _rules(r)
	if rules != "":
		var rl := UIKit.label(rules, "LabelMuted", 20 if big else 17)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(rl)
	var layers: Array = Catalog.recipe_layers(recipe_id)
	var spread := 0.4
	var art_h := maxf(150.0, max_h - 190.0)
	var art_w := clampf(art_h / (0.62 + spread * float(maxi(1, layers.size()) - 1)), 70.0, 150.0)
	var stack := UIKit.burger_stack(layers, art_w, spread)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(stack)
	# mitad derecha: los pasos numerados
	var steps := UIKit.vbox(8 if big else 6)
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.size_flags_stretch_ratio = 1.15
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(steps)
	steps.add_child(UIKit.label(Loc.t("recipe.how"), "LabelGold", 24 if big else 20))
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
	return card

## Una fila de paso: número en un círculo, icono del ingrediente, nombre y dónde se prepara.
static func _step_row(n: int, ingredient_id: String, big: bool, served_apart: bool = false) -> HBoxContainer:
	var row := UIKit.hbox(12)
	var badge := UIKit.card("PanelBadge")
	badge.add_theme_stylebox_override("panel", UITheme.box(Palette.MUSTARD, UITheme.OUTLINE, 99, 2, false, 2))
	var d := 40.0 if big else 34.0
	badge.custom_minimum_size = Vector2(d, d)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var num := UIKit.label(("+" if served_apart else str(n)), "LabelInkBold", 24 if big else 20)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	row.add_child(badge)
	var ic_name := UIKit.ingredient_icon(ingredient_id)
	if ic_name != "":
		var ic := UIKit.icon_rect(ic_name, 58.0 if big else 46.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var col := UIKit.vbox(0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UIKit.label(Catalog.ingredient_name(ingredient_id), "LabelHeader", 28 if big else 23)
	col.add_child(name_l)
	var where := ""
	var cook := Catalog.cook_config(ingredient_id)
	if not cook.is_empty():
		where = Loc.t("recipe.cook_fryer") if str(cook.get("station", "grill")) == "fryer" else Loc.t("recipe.cook_grill")
	elif ingredient_id == "drink":
		where = Loc.t("recipe.from_dispenser")
	if served_apart:
		where = (where + " · " if where != "" else "") + Loc.t("recipe.on_tray")
	if where != "":
		var wl := UIKit.label(where, "LabelMuted", 19 if big else 16)
		col.add_child(wl)
	row.add_child(col)
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
