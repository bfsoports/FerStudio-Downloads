extends UiScreen
## BuildScreen — catálogo de estructuras del refugio (data/structures.json).
##
## Cada pieza muestra el coste del armazón (se paga al colocar) y el de la obra (se paga al
## terminarla interactuando con el armazón), la herramienta necesaria y para qué sirve.
## «Colocar» cierra el menú y activa BuildMode con la vista previa.

var _list: GridContainer

func setup() -> void:
	frame(tr("BUILD_TITLE"), 0.5, 1180.0, "build")
	body.add_child(UiKit.wrap_label(tr("BUILD_INFO"), 16, UiKit.C_DIM))
	_list = UiKit.grid(2, 10)
	body.add_child(UiKit.scroll(_list))
	Session.inventory_changed.connect(refresh)

func refresh() -> void:
	UiKit.clear(_list)
	for id: String in GameData.structures.keys():
		_list.add_child(_card(id, GameData.structures[id]))

func _costs(title_key: String, cost: Dictionary) -> HBoxContainer:
	var h := UiKit.hbox(8)
	h.add_child(UiKit.label(tr(title_key), 14, UiKit.C_DIM, UiKit.f_semi))
	for item: String in cost.keys():
		var have := Session.inv.count(item)
		var ic := TextureRect.new()
		ic.texture = UiKit.item_icon(item)
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.tooltip_text = GameData.item_name(item)
		h.add_child(ic)
		h.add_child(UiKit.label("%d/%d" % [have, int(cost[item])], 15, UiKit.C_GOOD if have >= int(cost[item]) else UiKit.C_BAD, UiKit.f_semi))
	return h

func _card(id: String, def: Dictionary) -> PanelContainer:
	var p := UiKit.panel("flat", 12.0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	var top := UiKit.hbox(10)
	var icon_name := "build"
	if def.has("station"):
		icon_name = "fire" if String(def.station) == "fire" else ("water" if String(def.station) == "water" else "craft")
	elif def.has("rest"):
		icon_name = "rest"
	elif def.has("container"):
		icon_name = "material"
	elif def.has("light"):
		icon_name = "light"
	top.add_child(UiKit.icon_rect(icon_name, 28, UiKit.C_ACCENT))
	var tv := UiKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiKit.label(GameData.text(def.get("name", id)), 19, UiKit.C_TEXT, UiKit.f_semi))
	tv.add_child(UiKit.wrap_label(GameData.text(def.get("desc", "")), 15, UiKit.C_DIM))
	top.add_child(tv)
	v.add_child(top)
	var frame_cost: Dictionary = def.get("frame_cost", {})
	if not frame_cost.is_empty():
		v.add_child(_costs("BUILD_FRAME", frame_cost))
	v.add_child(_costs("BUILD_COST", def.get("cost", {})))
	var foot := UiKit.hbox(8)
	var tool := String(def.get("tool", ""))
	var tl := UiKit.label(tr("CRAFT_TOOL") % GameData.item_name(tool) if tool != "" else "", 14, UiKit.C_DIM if (tool == "" or Session.has_item(tool)) else UiKit.C_BAD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(tl)
	var can := Session.inv.has_all(frame_cost) and (not bool(def.get("instant", false)) or Session.inv.has_all(def.get("cost", {})))
	var go := UiKit.button(tr("BUILD_PLACE"), "", func() -> void:
		Ui.close_all()
		if Ui.build_mode != null:
			Ui.build_mode.call("start", id), "primary" if can else "normal")
	go.custom_minimum_size = Vector2(130, 48)
	go.disabled = not can
	foot.add_child(go)
	v.add_child(foot)
	return p
