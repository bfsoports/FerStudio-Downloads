extends UiScreen
## DocScreen — lectura de un documento encontrado en el mundo (pistas e historia del valle).

func setup() -> void:
	var id := String(args.get("id", ""))
	var d: Dictionary = GameData.documents.get(id, {})
	frame(GameData.text(d.get("title", tr("DOC_TITLE"))), 0.6, 760.0, "doc")
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiKit.box(Color("e7dfc8"), 6, Color("8a7d5e"), 1, 26))
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t := RichTextLabel.new()
	t.bbcode_enabled = false
	t.fit_content = true
	t.text = GameData.text(d.get("text", ""))
	t.add_theme_color_override("default_color", Color("2c2a22"))
	t.add_theme_font_override("normal_font", load("res://assets/fonts/Barlow-Italic.ttf"))
	t.add_theme_font_size_override("normal_font_size", 21)
	t.add_theme_constant_override("line_separation", 8)
	t.custom_minimum_size = Vector2(640, 0)
	paper.add_child(t)
	body.add_child(UiKit.scroll(paper))
	var where := String(d.get("where", ""))
	var place := GameData.world.place(where)
	if not place.is_empty():
		body.add_child(UiKit.label(tr("DOC_FOUND") % String(place.name), 15, UiKit.C_DIM))
	var ok := UiKit.button(tr("BTN_CLOSE"), "check", func() -> void: Ui.close_top(), "primary")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.custom_minimum_size.x = 200
	body.add_child(ok)
