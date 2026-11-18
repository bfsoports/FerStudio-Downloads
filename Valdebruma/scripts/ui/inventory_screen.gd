extends UiScreen
## InventoryScreen — inventario, equipo y contenedor abierto (panel doble).
##
## Responsabilidad: mostrar los huecos que envía el servidor y traducir los toques en
## PETICIONES (usar, equipar, soltar, dividir, mover entre inventario y contenedor, asignar a
## acceso rápido). Nunca cambia cantidades por su cuenta: espera el nuevo estado del servidor.
## Pensado para táctil: se toca un objeto para seleccionarlo y luego la acción; un segundo
## toque sobre el mismo objeto lo pasa al otro panel cuando hay un contenedor abierto.

const SLOT := 76.0
const EQUIP_SLOTS := ["cabeza", "cara", "torso", "espalda", "piernas", "pies", "mano"]
const EQUIP_ICONS := {"cabeza": "profile", "cara": "privacy", "torso": "equip", "espalda": "inventory", "piernas": "sit", "pies": "sprint", "mano": "interact"}

var _left: VBoxContainer
var _grid_box: VBoxContainer
var _details: VBoxContainer
var _sel_side := -1       # 0 inventario, 1 contenedor, 2 equipo
var _sel_index := -1
var _sel_slot := ""

func setup() -> void:
	frame(tr("INV_TITLE"), 0.5, 1220.0, "inventory")
	var h := UiKit.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	_left = UiKit.vbox(8)
	_left.custom_minimum_size = Vector2(300, 0)
	h.add_child(_left)
	h.add_child(UiKit.line(true))
	_grid_box = UiKit.vbox(8)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_grid_box)
	h.add_child(UiKit.line(true))
	_details = UiKit.vbox(8)
	_details.custom_minimum_size = Vector2(300, 0)
	h.add_child(_details)
	Session.inventory_changed.connect(refresh)
	Session.container_changed.connect(refresh)
	Session.container_closed.connect(refresh)
	Session.stats_changed.connect(_refresh_weight)

func on_close() -> void:
	Session.close_container()

func _refresh_weight() -> void:
	var l: Label = _grid_box.find_child("weight", true, false)
	if l != null:
		var w := float(Session.stats.get("w", 0.0))
		var wmax := float(Session.stats.get("wmax", 22.0))
		l.text = tr("INV_WEIGHT") % [w, wmax]
		l.add_theme_color_override("font_color", UiKit.C_BAD if w > wmax else UiKit.C_DIM)

func refresh() -> void:
	var has_container := Session.container_inv != null
	if _sel_side == 1 and not has_container:
		_sel_side = -1
	# ---- izquierda: contenedor abierto o equipo ----
	UiKit.clear(_left)
	if has_container:
		var hh := UiKit.hbox(8)
		hh.add_child(UiKit.icon_rect("material", 20, UiKit.C_ACCENT))
		var t := UiKit.caption(tr("INV_CONTAINER"), UiKit.C_ACCENT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(t)
		_left.add_child(hh)
		_left.add_child(UiKit.scroll(_make_grid(Session.container_inv, 1, 3)))
		var take := UiKit.button(tr("INV_TAKE_ALL"), "drop", _take_all)
		take.disabled = Session.container_inv.is_empty()
		_left.add_child(take)
	else:
		_left.add_child(UiKit.caption(tr("INV_EQUIPMENT")))
		for slot: String in EQUIP_SLOTS:
			_left.add_child(_equip_row(slot))
	# ---- centro: inventario ----
	UiKit.clear(_grid_box)
	var top := UiKit.hbox(8)
	var cap := UiKit.caption(tr("INV_BACKPACK") % [Session.inv.used(), Session.inv.size()])
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cap)
	var w := UiKit.label("", 15, UiKit.C_DIM, UiKit.f_medium)
	w.name = "weight"
	top.add_child(w)
	_grid_box.add_child(top)
	_grid_box.add_child(UiKit.scroll(_make_grid(Session.inv, 0, 6)))
	_refresh_weight()
	# accesos rápidos
	var q := UiKit.hbox(8)
	q.add_child(UiKit.label(tr("INV_QUICK"), 15, UiKit.C_DIM))
	for i in 4:
		var idx := i
		var id := String(Session.quick[i]) if i < Session.quick.size() else ""
		var b := Button.new()
		b.custom_minimum_size = Vector2(54, 54)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_BG, 0.8), 8, UiKit.C_LINE, 1))
		b.add_theme_stylebox_override("hover", UiKit.box(UiKit.C_PANEL3, 8, UiKit.C_ACCENT, 1))
		b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.C_PANEL3, 8, UiKit.C_ACCENT, 2))
		if id != "":
			var ic := TextureRect.new()
			ic.texture = UiKit.item_icon(id)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ic)
		var n := UiKit.label(str(i + 1), 12, UiKit.C_DIM, UiKit.f_semi)
		n.position = Vector2(5, 2)
		b.add_child(n)
		b.pressed.connect(func() -> void: _assign_quick(idx))
		q.add_child(b)
	_grid_box.add_child(q)
	_show_details()

func _make_grid(inv: Inventory, side: int, columns: int) -> GridContainer:
	var g := UiKit.grid(columns, 6)
	for i in inv.size():
		g.add_child(_slot(inv.get_slot(i), side, i))
	return g

func _slot(st: Variant, side: int, index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	var selected := side == _sel_side and index == _sel_index
	b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_BG, 0.75), 8, UiKit.C_ACCENT if selected else Color(UiKit.C_LINE, 0.8), 3 if selected else 1))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(UiKit.C_PANEL3, 0.9), 8, UiKit.C_ACCENT, 3 if selected else 1))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.C_PANEL3, 1.0), 8, UiKit.C_ACCENT, 3))
	if st != null:
		var id := String(st.id)
		var ic := TextureRect.new()
		ic.texture = UiKit.item_icon(id)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if int(st.n) > 1:
			var n := UiKit.label(str(int(st.n)), 15, UiKit.C_TEXT, UiKit.f_semi)
			n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
			n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			n.grow_vertical = Control.GROW_DIRECTION_BEGIN
			n.add_theme_constant_override("outline_size", 4)
			n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			b.add_child(n)
		var dur := float(GameData.item(id).get("dur", 0))
		if dur > 0.0 and int(st.d) >= 0:
			var bar := UiKit.bar(UiKit.C_GOOD if float(st.d) / dur > 0.3 else UiKit.C_BAD, 4.0)
			bar.value = clampf(float(st.d) / dur, 0.0, 1.0) * 100.0
			bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 5)
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
			bar.custom_minimum_size = Vector2(0, 4)
			b.add_child(bar)
	b.pressed.connect(func() -> void: _tap(side, index, st))
	return b

func _equip_row(slot: String) -> Control:
	var e: Variant = Session.equip.get(slot)
	var selected := _sel_side == 2 and _sel_slot == slot
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_BG, 0.7), 8, UiKit.C_ACCENT if selected else Color(UiKit.C_LINE, 0.8), 2 if selected else 1))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(UiKit.C_PANEL3, 0.9), 8, UiKit.C_ACCENT, 1))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.C_PANEL3, 1.0), 8, UiKit.C_ACCENT, 2))
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e is Array:
		var ic := TextureRect.new()
		ic.texture = UiKit.item_icon(String(e[0]))
		ic.custom_minimum_size = Vector2(42, 42)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	else:
		h.add_child(UiKit.icon_rect(String(EQUIP_ICONS[slot]), 26, Color(UiKit.C_DIM, 0.5)))
	var v := UiKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UiKit.label(tr("SLOT_" + slot.to_upper()), 13, UiKit.C_DIM, UiKit.f_semi))
	v.add_child(UiKit.label(GameData.item_name(String(e[0])) if e is Array else tr("INV_EMPTY"), 16, UiKit.C_TEXT if e is Array else Color(UiKit.C_DIM, 0.6)))
	h.add_child(v)
	b.add_child(h)
	b.pressed.connect(func() -> void:
		if e is Array:
			_sel_side = 2
			_sel_slot = slot
			_sel_index = -1
			refresh())
	return b

func _tap(side: int, index: int, st: Variant) -> void:
	if st == null:
		# hueco vacío: si hay algo seleccionado en el mismo panel, lo mueve aquí
		if _sel_side == side and _sel_index >= 0:
			Session.request_move_item(side, _sel_index, side, index, 999)
			_sel_side = -1
		elif _sel_side in [0, 1] and _sel_side != side and _sel_index >= 0:
			Session.request_move_item(_sel_side, _sel_index, side, index, 999)
			_sel_side = -1
		refresh()
		return
	if _sel_side == side and _sel_index == index and Session.container_inv != null:
		Session.request_move_item(side, index, 1 - side, -1, 999)      # segundo toque: al otro panel
		_sel_side = -1
		AudioDirector.play_ui("pickup", -6.0)
		return
	_sel_side = side
	_sel_index = index
	_sel_slot = ""
	refresh()

func _take_all() -> void:
	if Session.container_inv == null:
		return
	for i in Session.container_inv.size():
		if Session.container_inv.get_slot(i) != null:
			Session.request_move_item(1, i, 0, -1, 999)
	AudioDirector.play_ui("pickup", -6.0)

func _assign_quick(index: int) -> void:
	var id := ""
	if _sel_side == 0 and _sel_index >= 0:
		var st: Variant = Session.inv.get_slot(_sel_index)
		if st != null:
			id = String(st.id)
	elif _sel_side == 2 and _sel_slot != "":
		id = Session.equipped(_sel_slot)
	if id != "":
		var def := GameData.item(id)
		if not (def.has("use") or String((def.get("equip", {}) as Dictionary).get("slot", "")) == "mano"):
			Ui.toast(tr("INV_QUICK_BAD"), "bad", "warn")
			return
	Net.send(Protocol.C.QUICK_SET, [index, id])

func _selected() -> Variant:
	if _sel_side == 0:
		return Session.inv.get_slot(_sel_index)
	if _sel_side == 1 and Session.container_inv != null:
		return Session.container_inv.get_slot(_sel_index)
	if _sel_side == 2:
		var e: Variant = Session.equip.get(_sel_slot)
		return {"id": String(e[0]), "n": int(e[1]), "d": int(e[2])} if e is Array else null
	return null

func _show_details() -> void:
	UiKit.clear(_details)
	var st: Variant = _selected()
	if st == null:
		_sel_side = -1 if _sel_side != 2 else _sel_side
		_details.add_child(UiKit.spacer(true))
		var hint := UiKit.wrap_label(tr("INV_HINT_CONTAINER") if Session.container_inv != null else tr("INV_HINT"), 16, UiKit.C_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_details.add_child(hint)
		_details.add_child(UiKit.spacer(true))
		return
	var id := String(st.id)
	var def := GameData.item(id)
	var head := UiKit.hbox(10)
	var ic := TextureRect.new()
	ic.texture = UiKit.item_icon(id)
	ic.custom_minimum_size = Vector2(84, 84)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(ic)
	var hv := UiKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UiKit.wrap_label(GameData.item_name(id), 21, [UiKit.C_TEXT, UiKit.C_GOOD, UiKit.C_WATER, UiKit.C_ACCENT][clampi(int(def.get("rarity", 0)), 0, 3)])
	nm.add_theme_font_override("font", UiKit.f_semi)
	hv.add_child(nm)
	hv.add_child(UiKit.caption(tr("CAT_" + String(def.get("cat", "material")).to_upper())))
	hv.add_child(UiKit.label("%.2f kg  ·  ×%d" % [GameData.item_weight(id) * float(st.n), int(st.n)], 15, UiKit.C_DIM))
	head.add_child(hv)
	_details.add_child(head)
	_details.add_child(UiKit.wrap_label(GameData.text(def.get("desc", "")), 16, UiKit.C_TEXT))
	for line: String in _facts(def, st):
		_details.add_child(UiKit.wrap_label("•  " + line, 15, UiKit.C_DIM))
	_details.add_child(UiKit.spacer(true))
	# ---- acciones ----
	if _sel_side == 2:
		_details.add_child(UiKit.button(tr("INV_UNEQUIP"), "equip", func() -> void:
			Session.request_unequip(_sel_slot)
			_sel_side = -1))
		return
	var i := _sel_index
	if _sel_side == 1:
		_details.add_child(UiKit.button(tr("INV_TAKE"), "drop", func() -> void:
			Session.request_move_item(1, i, 0, -1, 999)
			_sel_side = -1, "primary"))
		if int(st.n) > 1:
			_details.add_child(UiKit.button(tr("INV_TAKE_ONE"), "", func() -> void: Session.request_move_item(1, i, 0, -1, 1)))
		return
	if def.has("use"):
		_details.add_child(UiKit.button(tr("INV_USE_" + String(def.get("cat", "food")).to_upper()) if String(def.get("cat", "")) in ["food", "drink", "medical"] else tr("INV_USE"), "use",
			func() -> void: Session.request_use(i), "primary"))
	if def.has("equip"):
		_details.add_child(UiKit.button(tr("INV_EQUIP"), "equip", func() -> void:
			Session.request_equip(i)
			_sel_side = -1, "primary"))
	if Session.container_inv != null:
		_details.add_child(UiKit.button(tr("INV_STORE"), "material", func() -> void:
			Session.request_move_item(0, i, 1, -1, 999)
			_sel_side = -1))
	var row := UiKit.hbox(8)
	var drop := UiKit.button(tr("INV_DROP"), "drop", func() -> void:
		Session.request_drop(i, 999)
		_sel_side = -1)
	drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(drop)
	if int(st.n) > 1:
		row.add_child(UiKit.button(tr("INV_DROP_ONE"), "", func() -> void: Session.request_drop(i, 1)))
		_details.add_child(row)
		_details.add_child(UiKit.button(tr("INV_SPLIT"), "split", func() -> void: Session.request_split(i, int(st.n) / 2)))
	else:
		_details.add_child(row)

## Datos útiles del objeto en texto llano (qué hace al usarlo o al llevarlo puesto).
func _facts(def: Dictionary, st: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	var use: Dictionary = def.get("use", {})
	for key: String in ["food", "water", "health", "stamina", "rest", "temp"]:
		if use.has(key):
			out.append(tr("FACT_" + key.to_upper()) % int(use[key]))
	if use.has("effect"):
		var e: Dictionary = GameData.effects.get(String(use.effect[0]), {})
		out.append(tr("FACT_EFFECT") % GameData.text(e.get("name", "")))
	if use.has("cure"):
		out.append(tr("FACT_CURE"))
	if use.has("deter"):
		out.append(tr("FACT_DETER"))
	var eq: Dictionary = def.get("equip", {})
	if eq.has("warmth"):
		out.append(tr("FACT_WARMTH") % int(eq.warmth))
	if eq.has("wet"):
		out.append(tr("FACT_WET") % int(float(eq.wet) * 100.0))
	if eq.has("slots"):
		out.append(tr("FACT_SLOTS") % int(eq.slots))
	if eq.has("carry"):
		out.append(tr("FACT_CARRY") % int(eq.carry))
	if eq.has("stamina"):
		out.append(tr("FACT_BOOTS"))
	if eq.has("light"):
		out.append(tr("FACT_LIGHT"))
	if eq.has("filter"):
		out.append(tr("FACT_FILTER"))
	var dur := int(def.get("dur", 0))
	if dur > 0 and st != null and int(st.d) >= 0:
		out.append(tr("FACT_DUR") % [int(st.d), dur])
	if String(def.get("fuel", "")) != "":
		out.append(tr("FACT_FUEL") % GameData.item_name(String(def.fuel)))
	if String(def.get("gives", "")) != "":
		out.append(tr("FACT_GIVES") % GameData.item_name(String(def.gives)))
	return out
