extends UiScreen
## CraftScreen — fabricación por recetas (data/recipes.json).
##
## Lista filtrable de recetas con su estado orientativo (nivel, herramienta, materiales) y
## detalle con ingredientes «tienes/necesitas», estación requerida (hoguera o banco) y tiempo.
## «Fabricar» envía la petición; el servidor valida estación cercana, materiales y espacio.

const CATS := ["all", "cocina", "salud", "util", "material", "ropa"]

var _cat := "all"
var _sel := ""
var _count := 1
var _cat_row: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer

func setup() -> void:
	frame(tr("CRAFT_TITLE"), 0.5, 1180.0, "craft")
	_cat_row = UiKit.hbox(6)
	body.add_child(_cat_row)
	var h := UiKit.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	_list = UiKit.vbox(6)
	var sc := UiKit.scroll(_list)
	sc.custom_minimum_size = Vector2(470, 0)
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	h.add_child(UiKit.line(true))
	_detail = UiKit.vbox(10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_detail)
	Session.inventory_changed.connect(refresh)
	Session.progress_changed.connect(refresh)

func refresh() -> void:
	UiKit.clear(_cat_row)
	for c: String in CATS:
		var cid := c
		var b := UiKit.button(tr("RCAT_" + c.to_upper()), "", func() -> void:
			_cat = cid
			refresh())
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if c == _cat else Color(UiKit.C_PANEL2, 0.96), 10, UiKit.C_ACCENT if c == _cat else UiKit.C_LINE, 1, 10))
		_cat_row.add_child(b)
	UiKit.clear(_list)
	var ids: Array = GameData.recipes.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ba := Session.recipe_block(GameData.recipes[a]) == ""
		var bb := Session.recipe_block(GameData.recipes[b]) == ""
		return ba and not bb if ba != bb else GameData.text(GameData.recipes[a].name) < GameData.text(GameData.recipes[b].name))
	for id: String in ids:
		var r: Dictionary = GameData.recipes[id]
		if _cat != "all" and String(r.get("cat", "")) != _cat:
			continue
		if _sel == "":
			_sel = id
		_list.add_child(_row(id, r))
	_show_detail()

func _row(id: String, r: Dictionary) -> Button:
	var block := Session.recipe_block(r)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	var selected := id == _sel
	b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_BG, 0.7), 8, UiKit.C_ACCENT if selected else Color(UiKit.C_LINE, 0.7), 2 if selected else 1))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(UiKit.C_PANEL3, 0.9), 8, UiKit.C_ACCENT, 1))
	b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.C_PANEL3, 8, UiKit.C_ACCENT, 2))
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UiKit.item_icon(String(r.out))
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate.a = 1.0 if block == "" else 0.55
	h.add_child(ic)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UiKit.label(GameData.text(r.name), 18, UiKit.C_TEXT if block == "" else UiKit.C_DIM, UiKit.f_semi))
	var st := String(r.get("station", ""))
	var sub := tr("STATION_" + st.to_upper()) if st != "" else tr("STATION_NONE")
	v.add_child(UiKit.label(sub if block == "" else tr("WHY_" + block.to_upper()), 14, UiKit.C_DIM if block == "" else UiKit.C_BAD))
	h.add_child(v)
	if block == "":
		h.add_child(UiKit.icon_rect("check", 20, UiKit.C_GOOD))
	b.add_child(h)
	b.pressed.connect(func() -> void:
		_sel = id
		_count = 1
		refresh())
	return b

func _show_detail() -> void:
	UiKit.clear(_detail)
	var r: Dictionary = GameData.recipes.get(_sel, {})
	if r.is_empty():
		return
	var out_id := String(r.out)
	var head := UiKit.hbox(12)
	var ic := TextureRect.new()
	ic.texture = UiKit.item_icon(out_id)
	ic.custom_minimum_size = Vector2(92, 92)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(ic)
	var hv := UiKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UiKit.label("%s  ×%d" % [GameData.item_name(out_id), int(r.get("n", 1))], 23, UiKit.C_TEXT, UiKit.f_semi))
	hv.add_child(UiKit.wrap_label(GameData.text(GameData.item(out_id).get("desc", "")), 16, UiKit.C_DIM))
	head.add_child(hv)
	_detail.add_child(head)
	_detail.add_child(UiKit.caption(tr("CRAFT_NEEDS")))
	var need: Dictionary = r.get("in", {})
	for id: String in need.keys():
		var have := Session.inv.count(id)
		var want := int(need[id]) * _count
		var row := UiKit.hbox(10)
		var ii := TextureRect.new()
		ii.texture = UiKit.item_icon(id)
		ii.custom_minimum_size = Vector2(36, 36)
		ii.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ii.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ii)
		var nm := UiKit.label(GameData.item_name(id), 17)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UiKit.label("%d / %d" % [have, want], 17, UiKit.C_GOOD if have >= want else UiKit.C_BAD, UiKit.f_semi))
		_detail.add_child(row)
	var facts := UiKit.vbox(4)
	var st := String(r.get("station", ""))
	facts.add_child(_fact("fire" if st == "fire" else "craft", tr("STATION_" + st.to_upper()) if st != "" else tr("STATION_NONE")))
	var tool := String(r.get("tool", ""))
	if tool != "":
		facts.add_child(_fact("tool", tr("CRAFT_TOOL") % GameData.item_name(tool), Session.has_item(tool)))
	if int(r.get("level", 0)) > 1:
		facts.add_child(_fact("star", tr("CRAFT_LEVEL") % int(r.level), int(Session.progress.get("level", 1)) >= int(r.level)))
	facts.add_child(_fact("clock", tr("CRAFT_TIME") % (float(r.get("time", 3.0)) * float(_count))))
	_detail.add_child(facts)
	_detail.add_child(UiKit.spacer(true))
	var foot := UiKit.hbox(10)
	foot.add_child(UiKit.icon_button("minus", func() -> void:
		_count = maxi(1, _count - 1)
		_show_detail()))
	var cl := UiKit.label("×%d" % _count, 22, UiKit.C_TEXT, UiKit.f_semi)
	cl.custom_minimum_size = Vector2(54, 0)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(cl)
	foot.add_child(UiKit.icon_button("plus", func() -> void:
		_count = mini(5, _count + 1)
		_show_detail()))
	var go := UiKit.button(tr("CRAFT_GO"), "craft", func() -> void:
		Session.request_craft(_sel, _count)
		Ui.close_all(), "primary")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scaled: Dictionary = {}
	for id: String in need.keys():
		scaled[id] = int(need[id]) * _count
	var r2 := r.duplicate()
	r2["in"] = scaled
	go.disabled = Session.recipe_block(r2) != ""
	foot.add_child(go)
	_detail.add_child(foot)

func _fact(icon_name: String, text: String, ok := true) -> HBoxContainer:
	var h := UiKit.hbox(8)
	h.add_child(UiKit.icon_rect(icon_name, 20, UiKit.C_ACCENT if ok else UiKit.C_BAD))
	h.add_child(UiKit.wrap_label(text, 16, UiKit.C_TEXT if ok else UiKit.C_BAD))
	return h
