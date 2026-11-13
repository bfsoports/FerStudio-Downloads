class_name UiKit
extends RefCounted
## UiKit — identidad visual y piezas comunes de la interfaz.
##
## Responsabilidad: construir el tema (tipografías Barlow, colores del valle, cajas con borde
## y estados de botón) y ofrecer constructores cortos de etiquetas, botones, paneles, barras e
## iconos para que todas las pantallas compartan estilo y tamaños táctiles (mín. 56 px).
## El alto contraste (Config access/high_contrast) regenera el tema con fondos opacos.

const C_BG := Color("0c1412")
const C_PANEL := Color("15211e")
const C_PANEL2 := Color("1f2f29")
const C_PANEL3 := Color("2b4038")
const C_LINE := Color("3b5048")
const C_TEXT := Color("ece7d8")
const C_DIM := Color("9db0a5")
const C_ACCENT := Color("e2a84b")
const C_GOOD := Color("86c47f")
const C_BAD := Color("dd6f55")
const C_WATER := Color("6fb7dc")
const C_FOOD := Color("d9a35c")
const C_STA := Color("b9d66a")
const TOUCH := 56.0

static var _theme: Theme = null
static var _contrast := false
static var f_regular: Font
static var f_medium: Font
static var f_semi: Font
static var f_cond: Font
static var _icons: Dictionary = {}

static func _fonts() -> void:
	if f_regular != null:
		return
	f_regular = load("res://assets/fonts/Barlow-Regular.ttf")
	f_medium = load("res://assets/fonts/Barlow-Medium.ttf")
	f_semi = load("res://assets/fonts/Barlow-SemiBold.ttf")
	f_cond = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

static func box(bg: Color, radius := 10, border := Color(0, 0, 0, 0), border_w := 0, pad := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	if pad > 0.0:
		sb.set_content_margin_all(pad)
	return sb

static func theme(high_contrast := false) -> Theme:
	if _theme != null and high_contrast == _contrast:
		return _theme
	_fonts()
	_contrast = high_contrast
	var t := Theme.new()
	var text := Color.WHITE if high_contrast else C_TEXT
	var panel := Color(0.02, 0.04, 0.035, 1.0) if high_contrast else Color(C_PANEL, 0.94)
	var line := Color(0.75, 0.82, 0.78) if high_contrast else C_LINE
	t.default_font = f_regular
	t.default_font_size = 18
	# etiquetas
	t.set_color("font_color", "Label", text)
	t.set_font_size("font_size", "Label", 18)
	t.set_constant("line_spacing", "Label", 2)
	# botones
	var normal := box(Color(C_PANEL2, 1.0 if high_contrast else 0.96), 10, line, 1 if not high_contrast else 2, 12)
	var hover := box(C_PANEL3, 10, C_ACCENT, 1, 12)
	var pressed := box(Color(C_ACCENT, 0.9), 10, C_ACCENT, 1, 12)
	var disabled := box(Color(C_PANEL, 0.7), 10, Color(line, 0.4), 1, 12)
	for sb in [normal, hover, pressed, disabled]:
		sb.content_margin_left = 18
		sb.content_margin_right = 18
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 10, C_ACCENT, 2))
	t.set_font("font", "Button", f_semi)
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_BG)
	t.set_color("font_disabled_color", "Button", Color(C_DIM, 0.55))
	t.set_color("icon_normal_color", "Button", text)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", C_BG)
	t.set_color("icon_disabled_color", "Button", Color(C_DIM, 0.5))
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 28)
	# paneles
	t.set_stylebox("panel", "PanelContainer", box(panel, 14, line, 1, 16))
	t.set_stylebox("panel", "Panel", box(panel, 14, line, 1))
	# campos de texto
	var field := box(Color(C_BG, 0.95), 8, line, 1, 10)
	var field_f := box(Color(C_BG, 1.0), 8, C_ACCENT, 2, 10)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_f)
	t.set_stylebox("read_only", "LineEdit", box(Color(C_BG, 0.5), 8, Color(line, 0.5), 1, 10))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", Color(C_DIM, 0.7))
	t.set_color("caret_color", "LineEdit", C_ACCENT)
	t.set_font_size("font_size", "LineEdit", 19)
	t.set_constant("minimum_character_width", "LineEdit", 6)
	# barras de progreso
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), 5, Color(1, 1, 1, 0.12), 1))
	t.set_stylebox("fill", "ProgressBar", box(C_ACCENT, 5))
	t.set_font_size("font_size", "ProgressBar", 13)
	# deslizadores
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.6), 4, line, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(C_ACCENT, 4, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(C_ACCENT, 4, Color(0, 0, 0, 0), 0, 4))
	var knob := _disc(30, C_TEXT, C_BG)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _disc(34, C_ACCENT, C_BG))
	t.set_icon("grabber_disabled", "HSlider", knob)
	# casillas
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_icon("checked_disabled", "CheckButton", _switch(true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_pressed_color", "CheckButton", text)
	t.set_color("font_hover_color", "CheckButton", text)
	t.set_color("font_hover_pressed_color", "CheckButton", text)
	# desplazamiento
	var grab := box(Color(C_DIM, 0.45), 4)
	grab.content_margin_left = 4
	grab.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(C_ACCENT, 0.8), 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(C_ACCENT, 4))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.25), 4, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("scroll", "HScrollBar", box(Color(0, 0, 0, 0.25), 4, Color(0, 0, 0, 0), 0, 4))
	# texto enriquecido y desplegables
	t.set_color("default_color", "RichTextLabel", text)
	t.set_font("normal_font", "RichTextLabel", f_regular)
	t.set_font("bold_font", "RichTextLabel", f_semi)
	t.set_font("italics_font", "RichTextLabel", load("res://assets/fonts/Barlow-Italic.ttf"))
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_font_size("italics_font_size", "RichTextLabel", 18)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), 10, C_ACCENT, 2))
	t.set_stylebox("panel", "PopupMenu", box(Color(C_PANEL, 1.0), 8, line, 1, 6))
	t.set_stylebox("hover", "PopupMenu", box(C_PANEL3, 6))
	t.set_font_size("font_size", "PopupMenu", 19)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_stylebox("panel", "TooltipPanel", box(Color(C_BG, 0.97), 6, line, 1, 8))
	_theme = t
	return t

static func _disc(size: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(size * 0.5 - d, 0.0, 1.0)
			var col := fill if d < size * 0.5 - 3.0 else edge
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

static func _switch(on: bool) -> ImageTexture:
	var w := 58
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := C_ACCENT if on else Color(0.2, 0.27, 0.25)
	var kx := float(w - h * 0.5) if on else h * 0.5
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, h * 0.5, w - h * 0.5)
			var d := px.distance_to(Vector2(cx, h * 0.5))
			var a := clampf(h * 0.5 - d, 0.0, 1.0)
			var col := track
			if px.distance_to(Vector2(kx, h * 0.5)) < h * 0.5 - 4.0:
				col = C_BG if on else C_TEXT
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

# ---- constructores -----------------------------------------------------------------------------
static func icon(icon_name: String) -> Texture2D:
	if _icons.has(icon_name):
		return _icons[icon_name]
	var path := "res://assets/icons/ui/%s.svg" % icon_name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[icon_name] = tex
	return tex

static func item_icon(id: String) -> Texture2D:
	var key := "item:" + id
	if _icons.has(key):
		return _icons[key]
	var path := "res://assets/icons/items/%s.png" % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[key] = tex
	return tex

static func label(text: String, size := 18, color := C_TEXT, font: Font = null) -> Label:
	_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap_label(text: String, size := 18, color := C_TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func title(text: String, size := 30, color := C_TEXT) -> Label:
	_fonts()
	var l := label(text.to_upper(), size, color, f_cond)
	l.add_theme_constant_override("outline_size", 0)
	return l

static func caption(text: String, color := C_DIM) -> Label:
	_fonts()
	return label(text.to_upper(), 14, color, f_semi)

static func icon_rect(icon_name: String, size := 24.0, color := C_TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## kind: "normal", "primary" (acento), "danger", "ghost" (sin fondo).
static func button(text: String, icon_name := "", cb := Callable(), kind := "normal") -> Button:
	_fonts()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = false
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", _btn(C_ACCENT, C_ACCENT))
			b.add_theme_stylebox_override("hover", _btn(C_ACCENT.lightened(0.15), Color.WHITE))
			b.add_theme_stylebox_override("pressed", _btn(C_ACCENT.darkened(0.2), C_ACCENT))
			for k in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
				b.add_theme_color_override(k, C_BG)
		"danger":
			b.add_theme_stylebox_override("normal", _btn(Color(C_BAD, 0.22), C_BAD))
			b.add_theme_stylebox_override("hover", _btn(Color(C_BAD, 0.45), C_BAD))
			b.add_theme_stylebox_override("pressed", _btn(C_BAD, C_BAD))
		"ghost":
			b.add_theme_stylebox_override("normal", _btn(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
			b.add_theme_stylebox_override("hover", _btn(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0)))
			b.add_theme_stylebox_override("pressed", _btn(Color(C_ACCENT, 0.9), C_ACCENT))
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			AudioDirector.play_ui("ui_click", -6.0)
			cb.call())
	return b

static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := box(bg, 10, border, 1, 12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb

static func icon_button(icon_name: String, cb := Callable(), size := TOUCH, kind := "normal", tip := "") -> Button:
	var b := button("", icon_name, cb, kind)
	b.custom_minimum_size = Vector2(size, size)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.add_theme_constant_override("icon_max_width", int(size * 0.5))
	return b

static func panel(kind := "panel", pad := 16.0) -> PanelContainer:
	var p := PanelContainer.new()
	match kind:
		"flat":
			p.add_theme_stylebox_override("panel", box(Color(C_PANEL2, 0.7), 10, Color(C_LINE, 0.6), 1, pad))
		"dark":
			p.add_theme_stylebox_override("panel", box(Color(C_BG, 0.82), 10, Color(C_LINE, 0.5), 1, pad))
		"hud":
			p.add_theme_stylebox_override("panel", box(Color(0.03, 0.06, 0.05, 0.55), 10, Color(1, 1, 1, 0.08), 1, pad))
		"accent":
			p.add_theme_stylebox_override("panel", box(Color(C_ACCENT, 0.14), 10, Color(C_ACCENT, 0.7), 1, pad))
		_:
			if pad != 16.0:
				p.add_theme_stylebox_override("panel", box(Color(C_PANEL, 0.94), 14, C_LINE, 1, pad))
	return p

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grid(columns: int, sep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g

static func margin(child: Control, l := 16, t := 16, r := 16, b := 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	if child != null:
		m.add_child(child)
	return m

static func spacer(expand := true, min_size := Vector2.ZERO) -> Control:
	var s := Control.new()
	s.custom_minimum_size = min_size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

static func scroll(child: Control, horizontal := false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_AUTO
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func bar(color: Color, height := 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(60, height)
	b.max_value = 100.0
	b.add_theme_stylebox_override("fill", box(color, int(height * 0.5)))
	b.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.55), int(height * 0.5), Color(1, 1, 1, 0.1), 1))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func line(vertical := false) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(C_LINE, 0.7)
	r.custom_minimum_size = Vector2(1, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

static func field(placeholder := "", text := "", max_len := 32) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = max_len
	e.custom_minimum_size = Vector2(120, TOUCH)
	e.context_menu_enabled = false
	e.select_all_on_focus = true
	return e

## Fila "Etiqueta ........ control" usada en ajustes y formularios.
static func row(text: String, control: Control, hint := "") -> HBoxContainer:
	var h := hbox(14)
	var v := vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(label(text, 19))
	if hint != "":
		v.add_child(wrap_label(hint, 14, C_DIM))
	h.add_child(v)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return h

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Hora de juego "07:45".
static func clock(hour: float) -> String:
	var h := int(floor(hour)) % 24
	var m := int(floor((hour - floor(hour)) * 60.0))
	return "%02d:%02d" % [h, m]
