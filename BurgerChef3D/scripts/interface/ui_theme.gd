class_name UITheme
extends RefCounted
## Tema visual único de la interfaz (ver docs/style_guide.md), a juego con el menú principal: tipografía Fredoka
## redondeada para títulos y botones (Poppins para textos largos), ventanas chocolate con borde caramelo y contorno
## oscuro, botones tipo pastilla con contorno oscuro y relieve inferior. Los iconos 3D propios se cargan desde UIKit.

static var WIN_BG := Color.html("#3a2016")
static var WIN_EDGE := Color.html("#b0643a")
static var OUTLINE := Color.html("#1e0c06")
static var CARD := Color.html("#4e2c1e")
static var CARD_HI := Color.html("#6a3a26")
static var CARD_EDGE := Color.html("#8a5034")
static var MUTED := Color.html("#cdb79a")
static var INK := Color.html("#2a1c18")
static var CLEAR := Color(0, 0, 0, 0)

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null

## Caja plana con borde, esquinas redondeadas y sombra opcional (la usan paneles, barras y puntos de nivel).
static func box(bg: Color, border: Color, radius: int = 16, border_w: int = 2, shadow: bool = false, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 5)
	return sb

## Fondo de los avisos emergentes: oscuro con el borde del color del tipo de aviso.
static func toast_box(kind: String) -> StyleBoxFlat:
	var border := Palette.CREAM
	if kind == "success":
		border = Palette.LETTUCE
	elif kind == "warn":
		border = Palette.KETCHUP
	var sb := box(Color(0.1, 0.06, 0.05, 0.94), border, 18, 2, false, 10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 18.0
	return sb

static func _knob(fill: Color, border: Color, px: int = 44) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	var r := px * 0.5 - 1.0
	for y in px:
		for x in px:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := border if d > r - 5.0 else fill
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

static func _label_variant(t: Theme, variant: String, font: Font, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(variant, "Label")
	if font != null:
		t.set_font("font", variant, font)
	t.set_font_size("font_size", variant, size)
	t.set_color("font_color", variant, color)
	if outline > 0:
		t.set_color("font_outline_color", variant, Palette.BROWN)
		t.set_constant("outline_size", variant, outline)

## Caja de botón: color plano con un relieve (borde inferior) de lift píxeles.
static func _btn_box(bg: Color, edge: Color, lift: int, radius: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	# contorno oscuro alrededor de todo el botón (como los botones del menú principal)
	sb.shadow_color = OUTLINE
	sb.shadow_size = 3
	sb.shadow_offset = Vector2.ZERO
	sb.anti_aliasing_size = 1.2
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 8.0 + float(lift)
	if lift > 0:
		sb.border_color = edge
		sb.border_width_bottom = lift
	return sb

## Botones gruesos: borde inferior de 9 px que da relieve y que se hunde al pulsar.
static func _button_variant(t: Theme, variant: String, bg: Color, edge: Color, text: Color, font: Font, size: int = 26, outline: int = 0) -> void:
	if variant != "Button":
		t.set_type_variation(variant, "Button")
	t.set_stylebox("normal", variant, _btn_box(bg, edge, 9))
	t.set_stylebox("hover", variant, _btn_box(bg.lightened(0.08), edge, 9))
	var pressed := _btn_box(bg.darkened(0.1), edge, 3)
	pressed.content_margin_top = 16.0
	t.set_stylebox("pressed", variant, pressed)
	t.set_stylebox("hover_pressed", variant, pressed)
	t.set_stylebox("disabled", variant, _btn_box(Color(0.27, 0.19, 0.16), Color(0.2, 0.14, 0.12), 4))
	t.set_stylebox("focus", variant, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, variant, text)
	t.set_color("font_disabled_color", variant, Color(0.6, 0.52, 0.45))
	t.set_color("icon_disabled_color", variant, Color(1, 1, 1, 0.4))
	t.set_font_size("font_size", variant, size)
	if font != null:
		t.set_font("font", variant, font)
	if outline > 0:
		t.set_color("font_outline_color", variant, OUTLINE)
		t.set_constant("outline_size", variant, outline)

## Botón sin fondo (solo el icono), con un ligero oscurecimiento al pulsar.
static func _icon_variant(t: Theme, variant: String, bg: Color) -> void:
	t.set_type_variation(variant, "Button")
	var sb: StyleBox = StyleBoxEmpty.new()
	if bg.a > 0.0:
		sb = box(bg, CLEAR, 99, 0, false, 8)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(s, variant, sb)
	t.set_color("icon_pressed_color", variant, Color(0.74, 0.74, 0.74))
	t.set_color("icon_hover_pressed_color", variant, Color(0.74, 0.74, 0.74))
	t.set_color("icon_disabled_color", variant, Color(1, 1, 1, 0.4))

static func _build() -> Theme:
	var t := Theme.new()
	var bold := _font("res://assets/fonts/Fredoka-Bold.ttf")
	if bold == null:
		bold = _font("res://assets/fonts/Poppins-Bold.ttf")
	var medium := _font("res://assets/fonts/Poppins-Medium.ttf")
	if medium == null:
		medium = bold
	if medium != null:
		t.default_font = medium
	t.default_font_size = 22
	# etiquetas
	t.set_color("font_color", "Label", Palette.CREAM)
	_label_variant(t, "LabelTitle", bold, 52, Palette.CREAM, 9)
	_label_variant(t, "LabelHeader", bold, 30, Palette.CREAM, 4)
	_label_variant(t, "LabelMuted", medium, 18, MUTED, 0)
	_label_variant(t, "LabelOutlined", bold, 28, Palette.CREAM, 7)
	_label_variant(t, "LabelLight", medium, 22, Palette.CREAM, 0)
	_label_variant(t, "LabelGold", bold, 30, Palette.MUSTARD, 6)
	_label_variant(t, "LabelValue", bold, 28, Palette.MUSTARD, 0)
	_label_variant(t, "LabelInk", medium, 19, INK, 0)
	_label_variant(t, "LabelInkBold", bold, 20, INK, 0)
	# botones
	_button_variant(t, "Button", Palette.MUSTARD, Palette.MUSTARD_DARK, INK, bold)
	_button_variant(t, "ButtonPrimary", Palette.MUSTARD, Palette.MUSTARD_DARK, INK, bold)
	_button_variant(t, "ButtonSecondary", Color.html("#7a3f27"), Color.html("#4a2214"), Palette.CREAM, bold, 26, 6)
	_button_variant(t, "ButtonDanger", Palette.KETCHUP, Palette.KETCHUP_DARK, Palette.CREAM, bold, 26, 6)
	_button_variant(t, "ButtonSuccess", Color.html("#7ed321"), Color.html("#3f8a12"), INK, bold)
	_button_variant(t, "ButtonDark", CARD_HI, Color.html("#3a1c10"), Palette.CREAM, bold, 26, 6)
	_button_variant(t, "ButtonToggle", CARD, Color.html("#2e170e"), MUTED, bold)
	var on := _btn_box(Palette.MUSTARD, Palette.MUSTARD_DARK, 4)
	t.set_stylebox("pressed", "ButtonToggle", on)
	t.set_stylebox("hover_pressed", "ButtonToggle", on)
	t.set_color("font_pressed_color", "ButtonToggle", INK)
	t.set_color("font_hover_pressed_color", "ButtonToggle", INK)
	# casillas de nivel
	_button_variant(t, "ButtonTile", CARD_HI, Color.html("#3a1c10"), Palette.CREAM, bold, 30, 6)
	_button_variant(t, "ButtonTileDone", Color.html("#6b4a22"), Palette.MUSTARD_DARK, Palette.CREAM, bold, 30)
	_button_variant(t, "ButtonTileLocked", Color.html("#2f211c"), Color.html("#241814"), MUTED, bold, 30)
	# botones de solo icono: sin fondo (cierre, volver) o sobre un círculo oscuro translúcido (HUD)
	_icon_variant(t, "ButtonIcon", CLEAR)
	_icon_variant(t, "ButtonRound", Color(0.1, 0.06, 0.05, 0.74))
	t.set_constant("h_separation", "Button", 10)
	# paneles
	var win := box(WIN_BG, WIN_EDGE, 30, 5, false, 18)
	win.shadow_color = OUTLINE
	win.shadow_size = 4
	t.set_stylebox("panel", "PanelContainer", win)
	_panel(t, "PanelFlat", box(CARD, CARD_EDGE, 16, 2, false, 12))
	_panel(t, "PanelHi", box(CARD_HI, Palette.MUSTARD, 16, 3, false, 12))
	_panel(t, "PanelChip", box(Color(0.1, 0.06, 0.05, 0.74), CLEAR, 20, 0, false, 8))
	_panel(t, "PanelDark", box(Color(0.1, 0.06, 0.05, 0.78), Color(1, 1, 1, 0.14), 18, 2, false, 10))
	_panel(t, "PanelTicket", box(Palette.CREAM, Palette.BROWN_LIGHT, 12, 3, false, 8))
	_panel(t, "PanelToast", toast_box("info"))
	_panel(t, "PanelDim", box(Color(0, 0, 0, 0.62), CLEAR, 0, 0, false, 0))
	_panel(t, "PanelBadge", box(Palette.KETCHUP, Palette.CREAM, 99, 2, false, 3))
	_panel(t, "PanelBanner", box(CARD_HI, Palette.MUSTARD, 20, 3, true, 14))
	# barras de progreso
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.06, 0.05, 0.9), CLEAR, 8, 0, false, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.MUSTARD, CLEAR, 8, 0, false, 0))
	t.set_font_size("font_size", "ProgressBar", 15)
	# deslizadores (pomo grande para el pulgar)
	var track := box(Color(0.1, 0.06, 0.05, 0.9), CLEAR, 8, 0, false, 6)
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(Palette.MUSTARD, Palette.MUSTARD, 8, 0, false, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.MUSTARD.lightened(0.15), Palette.MUSTARD, 8, 0, false, 6))
	t.set_icon("grabber", "HSlider", _knob(Palette.CREAM, WIN_EDGE))
	t.set_icon("grabber_highlight", "HSlider", _knob(Palette.MUSTARD.lightened(0.3), WIN_EDGE))
	t.set_icon("grabber_disabled", "HSlider", _knob(Color(0.6, 0.55, 0.5), WIN_EDGE))
	# barra de desplazamiento vertical: fina pero visible, para que se note que la lista sigue
	var sb_track := box(Color(0.1, 0.06, 0.05, 0.55), CLEAR, 6, 0, false, 0)
	sb_track.content_margin_left = 4.0
	sb_track.content_margin_right = 4.0
	t.set_stylebox("scroll", "VScrollBar", sb_track)
	t.set_stylebox("scroll_focus", "VScrollBar", sb_track)
	for g in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(g, "VScrollBar", box(Palette.MUSTARD if g == "grabber" else Palette.MUSTARD.lightened(0.2), CLEAR, 6, 0, false, 0))
	var no_arrow := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for ic in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		t.set_icon(ic, "VScrollBar", no_arrow)
	# separaciones
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	return t

static func _panel(t: Theme, variant: String, sb: StyleBoxFlat) -> void:
	t.set_type_variation(variant, "PanelContainer")
	t.set_stylebox("panel", variant, sb)
