class_name UIStyle
extends RefCounted
## Visual component system shared by every screen (see docs/GUIA_VISUAL.md).
## Military-arcade look: slanted plates, hazard-orange accent, toxic green energy.

const BG := Color(0.055, 0.06, 0.055)
const PANEL := Color(0.09, 0.1, 0.085, 0.88)
const PANEL_LIGHT := Color(0.16, 0.17, 0.14, 0.92)
const BORDER := Color(0.36, 0.38, 0.3)
const ACCENT := Color(1.0, 0.56, 0.12)
const TOXIC := Color(0.58, 1.0, 0.24)
const TEXT := Color(0.94, 0.92, 0.86)
const TEXT_DIM := Color(0.64, 0.66, 0.6)
const DANGER := Color(0.92, 0.22, 0.16)
const GOLD := Color(1.0, 0.82, 0.3)
const SKEW := 0.18

static var _title_font: Font
static var _body_font: Font
static var _theme: Theme


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/RussoOne-Regular.ttf")
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://assets/fonts/Teko-SemiBold.ttf")
	return _body_font


static func plate(color: Color, border: Color = BORDER, border_w: int = 2, skew: float = SKEW) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.skew = Vector2(skew, 0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 28
	# Buttons
	t.set_stylebox("normal", "Button", plate(Color(0.1, 0.11, 0.095, 0.92)))
	t.set_stylebox("hover", "Button", plate(Color(0.17, 0.16, 0.12, 0.95), ACCENT))
	t.set_stylebox("pressed", "Button", plate(Color(0.3, 0.17, 0.05, 0.98), ACCENT, 3))
	t.set_stylebox("focus", "Button", plate(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("disabled", "Button", plate(Color(0.08, 0.08, 0.08, 0.6), Color(0.2, 0.2, 0.2)))
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)
	# Panels
	var p := plate(PANEL, BORDER, 2, 0.0)
	p.set_content_margin_all(22)
	t.set_stylebox("panel", "PanelContainer", p)
	t.set_stylebox("panel", "Panel", p)
	# Sliders
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.2, 0.21, 0.18)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = ACCENT
	slider_fill.content_margin_top = 6
	slider_fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	t.set_icon("grabber", "HSlider", _grabber_tex())
	t.set_icon("grabber_highlight", "HSlider", _grabber_tex())
	# CheckButton / OptionButton
	t.set_font("font", "CheckButton", body_font())
	t.set_font_size("font_size", "CheckButton", 28)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "OptionButton", plate(Color(0.1, 0.11, 0.095, 0.92), BORDER, 2, 0.0))
	t.set_stylebox("hover", "OptionButton", plate(Color(0.17, 0.16, 0.12, 0.95), ACCENT, 2, 0.0))
	t.set_stylebox("pressed", "OptionButton", plate(Color(0.3, 0.17, 0.05, 0.98), ACCENT, 2, 0.0))
	t.set_font("font", "OptionButton", title_font())
	t.set_font_size("font_size", "OptionButton", 22)
	_theme = t
	return t


static func _grabber_tex() -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d < 12:
				img.set_pixel(x, y, ACCENT if d < 9 else Color(0.1, 0.1, 0.1))
	return ImageTexture.create_from_image(img)


static func make_label(text: String, size: int = 28, color: Color = TEXT, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func make_button(text: String, min_w: float = 320, min_h: float = 62) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("ui_click", -4.0))
	return b


static func icon(name: String) -> Texture2D:
	var path := "res://assets/ui/icons/%s.svg" % name
	if ResourceLoader.exists(path):
		return load(path)
	path = "res://assets/ui/icons/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func hazard_strip(height: float = 10.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/icons/hazard_strip.svg")
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(0, height)
	return tr
