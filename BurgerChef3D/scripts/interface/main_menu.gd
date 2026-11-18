extends Node3D
## Menú principal: fondo ilustrado de la cocina con la hamburguesa, logotipo, botón JUGAR, CONTINUAR, seis secciones
## en pastillas marrones y la barra de monedas, nivel y créditos arriba a la derecha (diseño de referencia de 1672 x 941).
##
## Todo se coloca en «unidades de referencia» (las de ese diseño) y se convierte al lienzo real con una escala, así el
## menú se ve igual en 16:9, 20:9, 21:9, tabletas 4:3 y pantallas con muesca. El fondo se ajusta en modo «cubrir»: nunca
## se estira ni deja bandas negras; se recorta lo que sobra y se desplaza para que la hamburguesa quede en el hueco libre
## a la derecha de los botones.

const REF_H := 941.0                      # alto del diseño de referencia
const COL_X := 105.0                      # borde izquierdo de la columna de botones en la referencia
const COL_W := 660.0                      # ancho de la columna (logotipo)
const COL_TOP := 15.0
const BAR_RIGHT := 1640.0                 # borde derecho de la barra de monedas en la referencia
const BAR_TOP := 28.0
const BG_PATH := "res://assets/ui/menu_bg.webp"
const BG_FOCUS := Vector2(0.706, 0.553)  # centro de la hamburguesa dentro de la imagen de fondo (0-1)
const UI := "res://assets/ui/"
const FONT_PATH := "res://assets/fonts/Fredoka-Bold.ttf"
const TEXT_DARK := Color(0.2, 0.09, 0.03)
const TEXT_LIGHT := Color(1.0, 0.98, 0.93)
const OUTLINE_DARK := Color(0.16, 0.07, 0.03)

var _ui_layer: CanvasLayer = null
var _root: Control = null
var _host: Control = null
var _screen: MenuScreen = null
var _screen_id := ""
var _toast_box: VBoxContainer = null
var _free_btn: Button = null
var _free_tick := 0.0
var _font: Font = null
var _s := 1.0                              # escala de unidades de referencia a unidades del lienzo
var _left := Vector2.ZERO                  # dónde cae en el lienzo el punto de referencia (COL_X, COL_TOP)
var _right := Vector2.ZERO                 # dónde cae el punto de referencia (BAR_RIGHT, BAR_TOP)
var _play_btn: Control = null
var _t := 0.0


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_build_ui()
	AudioManager.play_music("menu")
	Events.back_requested.connect(_on_back)
	Events.toast.connect(_on_toast)
	Events.language_changed.connect(_on_language)
	Events.ui_scale_changed.connect(_on_ui_scale)
	get_viewport().size_changed.connect(_on_resized)
	SettingsManager.apply_graphics()

func _process(delta: float) -> void:
	_t += delta
	_free_tick -= delta
	if _free_tick <= 0.0:
		_free_tick = 1.0
		_refresh_free_btn()
	# el botón JUGAR «respira» suavemente para invitar a pulsarlo
	if _play_btn != null and is_instance_valid(_play_btn) and not (_play_btn as BaseButton).is_pressed():
		var k := 1.0 + 0.025 * sin(_t * 3.2)
		_play_btn.scale = Vector2(k, k)

# ------------------------------------------------------------------ medidas
## Calcula la escala y los dos puntos de anclaje (columna izquierda y barra derecha) para el lienzo actual.
func _measure() -> Vector2:
	var avail := UIKit.canvas_size(self)
	var sm := UIKit.safe_margins(self)
	var pad := 10.0
	# la columna ocupa todo el alto, pero nunca más de algo más de la mitad del ancho (tabletas 4:3 o 5:4)
	_s = minf(avail.y / REF_H, (avail.x * 0.47 - float(sm["left"])) / (COL_W + 2.0 * pad + 30.0))
	var col_h := (890.0 - COL_TOP) * _s
	var top := maxf(COL_TOP * _s, (avail.y - col_h) * 0.5)
	top = maxf(top, float(sm["top"]) + 4.0)
	var left := maxf(COL_X * _s * 0.75, float(sm["left"]) + 16.0)
	_left = Vector2(left, top)
	_right = Vector2(avail.x - maxf(32.0 * _s, float(sm["right"]) + 16.0), maxf(BAR_TOP * _s, float(sm["top"]) + 8.0))
	return avail

## Rectángulo en el lienzo de un elemento de la columna izquierda dado en unidades de referencia.
func _lrect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_left + Vector2(x - COL_X, y - COL_TOP) * _s, Vector2(w, h) * _s)

func _px(v: float) -> int:
	return maxi(1, int(round(v * _s)))

# ------------------------------------------------------------------ interfaz
func _build_ui() -> void:
	if _ui_layer != null:
		_ui_layer.queue_free()
	_screen = null
	_play_btn = null
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ui_layer.add_child(_root)
	var avail := _measure()
	_build_background(avail)
	_build_column()
	_build_top_bar()
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_host)
	_toast_box = UIKit.vbox(6)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_box.offset_top = -170.0
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN

## Fondo en modo «cubrir»: la imagen se escala lo justo para tapar toda la pantalla (sin deformarla ni dejar bordes) y se
## desplaza para que la hamburguesa quede centrada en el hueco a la derecha de la columna de botones.
func _build_background(avail: Vector2) -> void:
	var tex := load(BG_PATH) as Texture2D
	var base := ColorRect.new()   # por si la textura no cargara: tono del fondo, nunca negro
	base.color = Color.html("#7a4a2c")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(base)
	if tex == null:
		return
	var ts := Vector2(tex.get_size())
	var k := maxf(avail.x / ts.x, avail.y / ts.y)
	var size := ts * k
	var col_right := _left.x + (COL_W + 10.0) * _s
	var focus := Vector2((col_right + avail.x) * 0.5, avail.y * 0.56)
	var pos := focus - BG_FOCUS * size
	pos.x = clampf(pos.x, avail.x - size.x, 0.0)
	pos.y = clampf(pos.y, avail.y - size.y, 0.0)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = pos
	bg.size = size
	_root.add_child(bg)
	# sombra suave a la izquierda para que la columna de botones destaque sobre la cocina
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.04, 0.02, 0.5))
	grad.set_color(1, Color(0.1, 0.04, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2.ZERO
	shade.size = Vector2(col_right + 120.0 * _s, avail.y)
	_root.add_child(shade)

func _build_column() -> void:
	# logotipo
	var title := TextureRect.new()
	title.texture = load(UI + "title.webp") as Texture2D
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_rect(title, _lrect(COL_X, COL_TOP, COL_W, 288.0))
	_root.add_child(title)
	var y := 320.0
	# JUGAR: botón verde con los destellos y el triángulo de la imagen, y el texto traducible encima
	var play := _image_button("btn_play.webp", 360.0, 130.0, _lrect(82.0, y - 40.0, 663.0, 195.0))
	_add_text(play, Loc.t("menu.play"), Rect2(0.40, 0.2, 0.54, 0.46), 78.0, TEXT_DARK, Color(0.93, 1.0, 0.55), 5.0)
	_add_text(play, Loc.t("menu.play_sub"), Rect2(0.40, 0.6, 0.54, 0.18), 30.0, TEXT_DARK, Color(0, 0, 0, 0), 0.0)
	play.pressed.connect(_on_play)
	_play_btn = play
	y += 162.0
	var has_continue := GameState.stat("shifts_played") > 0 or GameState.highest_unlocked > 1
	if has_continue:
		var cont := _image_button("btn_continue.webp", 340.0, 150.0, _lrect(146.0, y, 593.0, 99.0))
		_add_text(cont, Loc.t("menu.continue", [GameState.highest_unlocked]), Rect2(0.25, 0.14, 0.68, 0.62), 36.0, TEXT_DARK, Color(1, 0.93, 0.5), 3.0)
		cont.pressed.connect(_start.bind({"mode": Const.MODE_CAMPAIGN, "level_id": GameState.highest_unlocked}))
		y += 117.0
	else:
		y += 30.0
	# secciones: 2 columnas x 3 filas de pastillas marrones con icono y nombre
	var entries: Array = [["restaurant", "shop", Loc.t("menu.restaurant")], ["upgrades", "upgrade", Loc.t("menu.upgrades")],
		["recipes", "book", Loc.t("menu.recipes")], ["missions", "target", Loc.t("menu.missions")],
		["customize", "palette", Loc.t("menu.customize")], ["settings", "settings", Loc.t("menu.settings")]]
	var rows_h := 890.0 - y
	var tile_h := clampf((rows_h - 2.0 * 10.0) / 3.0, 82.0, 104.0)
	var gap := 10.0
	var tile_w := (COL_W - 20.0 - gap) * 0.5
	for i in entries.size():
		var e: Array = entries[i]
		var col := i % 2
		var row := i / 2
		var r := _lrect(133.0 + col * (tile_w + gap), y + row * (tile_h + gap), tile_w, tile_h)
		var b := _image_button("pill_brown.webp", 52.0, 52.0, r)
		var ic := TextureRect.new()
		ic.texture = UIKit.icon(str(e[1]), 66.0 * _s)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_px := minf(70.0, tile_h * 0.74) * _s
		ic.position = Vector2(22.0 * _s, (r.size.y - icon_px) * 0.5 - 3.0 * _s)
		ic.size = Vector2(icon_px, icon_px)
		b.add_child(ic)
		_add_text(b, str(e[2]), Rect2(112.0 / tile_w, 0.1, 1.0 - 124.0 / tile_w, 0.72), 36.0, TEXT_LIGHT, OUTLINE_DARK, 7.0, HORIZONTAL_ALIGNMENT_LEFT)
		b.pressed.connect(_open_screen.bind(str(e[0])))
		match str(e[0]):
			"missions":
				_add_badge(b, MissionManager.claimable_count())
			"upgrades":
				_add_badge(b, EconomyManager.buyable_upgrades())
			"recipes":
				_add_badge(b, GameState.unseen_recipes().size())
			"customize":
				_add_badge(b, EconomyManager.unseen_items().size())

## Barra de arriba a la derecha: monedas | nivel | corazón (créditos), y debajo el regalo de monedas por anuncio.
func _build_top_bar() -> void:
	var h := 80.0 * _s
	var bar := PanelContainer.new()
	var sb := UITheme.box(Color(0.17, 0.08, 0.05, 0.86), Color(0.45, 0.25, 0.15, 0.9), int(h * 0.5), maxi(2, _px(3.0)), true, 0)
	sb.content_margin_left = 14.0 * _s
	sb.content_margin_right = 14.0 * _s
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(14.0))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	row.add_child(_bar_icon("coin", 62.0))
	row.add_child(_bar_label(str(GameState.coins), 40.0, 120.0))
	row.add_child(_bar_divider())
	row.add_child(_bar_icon("medal", 60.0))
	row.add_child(_bar_label(Loc.t("hud.level", [GameState.level]), 34.0, 110.0))
	row.add_child(_bar_divider())
	var heart := TextureButton.new()
	heart.texture_normal = UIKit.icon("heart", 64.0 * _s)
	heart.ignore_texture_size = true
	heart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	heart.custom_minimum_size = Vector2(70.0, 70.0) * _s
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_open_screen("credits"))
	_press_feedback(heart)
	row.add_child(heart)
	_root.add_child(bar)
	bar.custom_minimum_size = Vector2(0, h)
	bar.size = bar.get_combined_minimum_size()
	bar.position = Vector2(_right.x - bar.size.x, _right.y)
	# monedas gratis con un anuncio recompensado (con espera entre regalos), debajo de la barra
	_free_btn = null
	if Ads.enabled():
		_free_btn = UIKit.icon_text_button("gift", "", "ButtonSuccess", 62.0 * _s, 0.0, 40.0 * _s)
		_free_btn.add_theme_font_size_override("font_size", _px(26.0))
		_free_btn.tooltip_text = Loc.t("ads.free_coins_title")
		_free_btn.pressed.connect(_on_free_coins)
		_root.add_child(_free_btn)
		_refresh_free_btn()
		_free_btn.size = _free_btn.get_combined_minimum_size()
		_free_btn.position = Vector2(_right.x - _free_btn.size.x, _right.y + h + 12.0 * _s)

func _bar_icon(icon_name: String, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UIKit.icon(icon_name, px * _s)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px) * _s
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _bar_label(text: String, size: float, min_w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", _px(size))
	l.add_theme_color_override("font_color", TEXT_LIGHT)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", _px(6.0))
	l.custom_minimum_size = Vector2(min_w * _s, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar_divider() -> Control:
	var p := ColorRect.new()
	p.color = Color(1, 0.85, 0.7, 0.35)
	p.custom_minimum_size = Vector2(maxf(2.0, 3.0 * _s), 50.0 * _s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Botón hecho con una imagen de 9 partes: los extremos (destellos, iconos, curvas) conservan su forma y solo se alarga la
## parte central lisa, así el botón toma el tamaño del diseño sin deformarse. La imagen se dibuja a su resolución y se
## escala entera al alto del botón, por eso se ve nítida en cualquier pantalla.
func _image_button(file: String, margin_l: float, margin_r: float, r: Rect2) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: AudioManager.play_sfx("click"))
	_set_rect(b, r)
	b.pivot_offset = r.size * 0.5
	var tex := load(UI + file) as Texture2D
	if tex != null:
		var np := NinePatchRect.new()
		np.texture = tex
		np.patch_margin_left = int(margin_l)
		np.patch_margin_right = int(margin_r)
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := r.size.y / float(tex.get_height())
		np.size = Vector2(maxf(r.size.x / k, margin_l + margin_r + 2.0), float(tex.get_height()))
		np.scale = Vector2(r.size.x / np.size.x, k)
		b.add_child(np)
	_press_feedback(b)
	_root.add_child(b)
	return b

## Al pulsar, el botón se hunde un poco y se oscurece (respuesta inmediata al dedo).
func _press_feedback(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.95, 0.95)
		b.modulate = Color(0.86, 0.86, 0.86))
	b.button_up.connect(func() -> void:
		b.scale = Vector2.ONE
		b.modulate = Color.WHITE)

## Texto centrado en una zona del botón (zona en fracciones del tamaño del botón); se reduce si no cabe.
func _add_text(b: Control, text: String, zone: Rect2, size: float, color: Color, outline: Color, outline_w: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	var w := zone.size.x * b.size.x
	var sz := _fit_size(text, w / _s, size)
	l.add_theme_font_size_override("font_size", _px(sz))
	l.add_theme_color_override("font_color", color)
	if outline_w > 0.0 and outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", _px(outline_w))
	l.position = Vector2(zone.position.x * b.size.x, zone.position.y * b.size.y)
	l.size = Vector2(w, zone.size.y * b.size.y)
	b.add_child(l)
	return l

## Mayor tamaño de letra (en unidades de referencia, hasta hi) con el que el texto cabe en el ancho w.
func _fit_size(text: String, w: float, hi: float) -> float:
	var sz := hi
	while sz > 14.0 and _font != null and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz)).x > w:
		sz -= 1.0
	return sz

func _set_rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size

## Círculo rojo con el número de novedades, en la esquina superior derecha de la sección.
func _add_badge(b: Control, count: int) -> void:
	if count <= 0:
		return
	var badge := UIKit.badge(count)
	b.add_child(badge)
	var d := 40.0 * _s
	badge.custom_minimum_size = Vector2(d, d)
	badge.position = Vector2(b.size.x - d * 0.75, -d * 0.3)
	badge.size = Vector2(d, d)

func _on_resized() -> void:
	call_deferred("_rebuild")

func _refresh_free_btn() -> void:
	if _free_btn == null or not is_instance_valid(_free_btn):
		return
	var wait := Ads.free_coins_wait()
	if wait > 0:
		_free_btn.text = Util.fmt_time(float(wait))
		_free_btn.disabled = true
	else:
		_free_btn.text = Loc.t("ads.free_coins", [Ads.free_coins_amount()])
		_free_btn.disabled = false

func _on_free_coins() -> void:
	if Ads.free_coins_wait() > 0:
		Events.toast.emit(Loc.t("ads.free_coins_wait", [Util.fmt_time(float(Ads.free_coins_wait()))]), "info")
		return
	if not Ads.rewarded_ready():
		Events.toast.emit(Loc.t("ads.not_ready"), "warn")
		return
	_free_btn.disabled = true
	Ads.show_rewarded("free_coins")
	var res: Array = await Ads.rewarded_finished
	if res.size() > 1 and bool(res[1]):
		var got := Ads.claim_free_coins()
		AudioManager.play_sfx("coin")
		Events.toast.emit(Loc.t("ads.free_coins_got", [got]), "success")
		call_deferred("_rebuild")
	else:
		_refresh_free_btn()

## JUGAR: la primera vez se ofrece el tutorial (una sola vez); después abre la selección de nivel.
func _on_play() -> void:
	if GameState.tutorial_done or GameState.tutorial_prompted or GameState.stat("shifts_played") > 0:
		_open_screen("play")
		return
	GameState.tutorial_prompted = true
	SaveManager.request_save()
	UIKit.confirm(_ui_layer, Loc.t("tut.offer"), Loc.t("tut.offer_yes"), _start.bind({"mode": Const.MODE_TUTORIAL}), false,
		Loc.t("tut.offer_no"), _open_screen.bind("play"), "info")

func _make_screen(id: String) -> MenuScreen:
	match id:
		"play":
			return LevelSelectScreen.new()
		"restaurant":
			return RestaurantScreen.new()
		"upgrades":
			return UpgradesScreen.new()
		"recipes":
			return RecipesScreen.new()
		"missions":
			return MissionsScreen.new()
		"customize":
			return CustomizationScreen.new()
		"settings":
			return SettingsScreen.new()
		"credits":
			return CreditsScreen.new()
	return null

func _open_screen(id: String) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = _make_screen(id)
	if _screen == null:
		return
	_screen_id = id
	_screen.back_requested.connect(_close_screen)
	_screen.play_requested.connect(_start)
	_host.add_child(_screen)

func _close_screen() -> void:
	_screen_id = ""
	call_deferred("_build_ui")

func _start(params: Dictionary) -> void:
	SceneManager.change_scene(Const.SCENE_GAME, params)

func _on_back() -> void:
	if _screen != null:
		_close_screen()
	else:
		UIKit.confirm(_ui_layer, Loc.t("menu.confirm_quit"), Loc.t("menu.quit"), SceneManager.quit_game)

func _on_language(_lang: String) -> void:
	call_deferred("_rebuild")

## Al cambiar el tamaño de la interfaz se recoloca todo (y se reabre la pantalla que estuviera abierta).
func _on_ui_scale() -> void:
	call_deferred("_rebuild")

func _rebuild() -> void:
	var keep := _screen_id
	_build_ui()
	if keep != "":
		_open_screen(keep)

func _on_toast(text: String, kind: String) -> void:
	if _toast_box == null:
		return
	var p := UIKit.toast_panel(text, kind)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
