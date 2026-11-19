class_name UIKit
extends RefCounted
## Constructores de interfaz reutilizables: etiquetas, botones, iconos 3D cartoon propios (assets/ui/icons), chips, tarjetas,
## estrellas, iconos de hamburguesa, diálogos y márgenes de zona segura. Mantienen coherente el sistema de diseño
## en todas las pantallas (ver docs/style_guide.md).

const ICON_DIR := "res://assets/ui/icons/"
const ICON_SRC_PX := 160
## Todos los iconos de la interfaz (assets/ui/icons/<nombre>.webp). test_ui.gd comprueba que existen.
const ICON_NAMES: Array = ["shop", "upgrade", "book", "target", "palette", "settings", "coin", "medal", "heart", "play", "skip", "home",
	"trophy", "star", "star_empty", "clock", "check", "close", "info", "warning", "lock", "gift", "burger", "fire",
	"trash", "cursor", "backpack", "downgrade", "rebirth", "stats", "skull", "lightning", "crown", "cash", "plus", "dice",
	"sound_on", "sound_off", "music_on", "music_off", "calendar", "player", "friend", "chat", "utensils", "cloche", "soda", "fries",
	"ing_bun_bottom", "ing_bun_top", "ing_patty", "ing_veggie_patty", "ing_bacon", "ing_cheese", "ing_lettuce", "ing_tomato", "ing_onion",
	"grill", "fryer", "board", "roller", "floor", "counter", "table", "chair", "lamp", "sign", "plant", "register", "sink", "crate", "hourglass"]
const ICON_ALIASES: Dictionary = {"rocket": "play", "wheel": "palette"}
const H_CTA := 96.0     # botón principal grande
const H_BTN := 78.0     # botón normal
const H_SMALL := 66.0   # botón de tarjeta o de pestaña

static var _icons: Dictionary = {}

## Tamaño del lienzo de la interfaz en unidades de UI. Cambia con la pantalla (16:9, 20:9, tableta...) y con el tamaño
## de interfaz elegido en ajustes, así que las pantallas lo consultan para repartir su contenido.
static func canvas_size(node: Node) -> Vector2:
	var vp := node.get_viewport()
	if vp == null:
		return Vector2(1024.0, 576.0)
	return vp.get_visible_rect().size

## Cuántas columnas de ancho item_w caben en avail_w (con hueco gap entre ellas), entre min_cols y max_cols.
static func fit_columns(avail_w: float, item_w: float, gap: float, min_cols: int, max_cols: int) -> int:
	return clampi(int(floorf((avail_w + gap) / (item_w + gap))), min_cols, max_cols)

## Ancho de cada elemento de una cuadrícula de cols columnas que ocupa avail_w, sin pasar de max_w.
static func fit_width(avail_w: float, cols: int, gap: float, max_w: float) -> float:
	return minf(max_w, floorf((avail_w - gap * float(cols - 1)) / float(cols)))

## Textura de un icono ajustada al tamaño real en que se dibuja (px del lienzo por el factor de escala de la ventana),
## así los iconos (160 px, estilo 3D cartoon hechos en Canva) salen nítidos sin deformarse.
static func icon(icon_name: String, px: float = 64.0) -> Texture2D:
	var k := maxf(1.0, float(DisplayServer.window_get_size().y) / 720.0)
	var want := clampi(int(round(px * k)), 16, ICON_SRC_PX)
	var key := "%s_%d" % [icon_name, want]
	if _icons.has(key):
		return _icons[key] as Texture2D
	var tex: Texture2D = null
	var path := icon_path(icon_name)
	if ResourceLoader.exists(path):
		tex = _fit(load(path) as Texture2D, want)
	else:
		push_error("UIKit: no existe el icono '%s'" % icon_name)
	_icons[key] = tex
	return tex

## Icono de un ingrediente (pan, carne, queso... y patatas y bebida), o "" si no tiene.
static func ingredient_icon(ingredient_id: String) -> String:
	match ingredient_id:
		"fries":
			return "fries"
		"drink":
			return "soda"
	var n := "ing_" + ingredient_id
	return n if ICON_NAMES.has(n) else ""

## Hamburguesa dibujada con los iconos de sus ingredientes apilados de abajo arriba (más clara que las barras de
## colores). w es el ancho; el alto sale del número de capas.
static func burger_stack(layer_ids: Array, w: float, spread: float = 0.2) -> Control:
	var step := w * spread
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := layer_ids.size()
	var h := w * 0.62 + step * float(maxi(0, n - 1))
	box.custom_minimum_size = Vector2(w, h)
	for i in n:
		var ic_name := ingredient_icon(str(layer_ids[i]))
		if ic_name == "":
			continue
		var r := icon_rect(ic_name, w)
		r.custom_minimum_size = Vector2(w, w)
		r.position = Vector2(0, h - w * 0.69 - step * float(i))
		r.size = Vector2(w, w)
		box.add_child(r)
	return box

## Ruta del archivo de un icono (con los nombres antiguos «rocket» y «wheel» redirigidos a los nuevos).
static func icon_path(icon_name: String) -> String:
	return "%s%s.webp" % [ICON_DIR, str(ICON_ALIASES.get(icon_name, icon_name))]

static func _fit(src: Texture2D, want: int) -> Texture2D:
	if src == null or src.get_width() == want:
		return src
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.resize(want, want, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

static func label(text: String, variation: String = "", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l

static func button(text: String, variant: String = "ButtonPrimary", min_h: float = H_BTN, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variant
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: AudioManager.play_sfx("click"))
	return b

## Botón con icono a la izquierda del texto (el icono real del pack, con el tamaño pedido).
static func icon_text_button(icon_name: String, text: String, variant: String = "ButtonPrimary", min_h: float = H_BTN, min_w: float = 0.0, icon_px: float = 40.0) -> Button:
	var b := button(text, variant, min_h, min_w)
	b.icon = icon(icon_name, icon_px)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	return b

## Botón con el icono encima y el texto debajo (accesos del menú principal).
static func tile_button(icon_name: String, text: String, variant: String, w: float, h: float, icon_px: float = 44.0, font_size: int = 15) -> Button:
	var b := button("", variant, h, w)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var ic := icon_rect(icon_name, icon_px)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(text, "LabelHeader", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b

## Botón cuadrado que solo muestra un icono (cierre, ajustes, recetas...).
static func icon_button(icon_name: String, variant: String = "ButtonIcon", px: float = 64.0) -> Button:
	var b := button("", variant, px, px)
	b.icon = icon(icon_name, px * 0.84)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	return b

static func icon_rect(icon_name: String, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name, px)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h: float = 8.0, expand: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

static func card(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p

## Línea fina de separación.
static func divider() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.12), UITheme.CLEAR, 1, 0, false, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Línea fina vertical de separación.
static func divider_vertical() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(2, 28)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.22), UITheme.CLEAR, 1, 0, false, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Lista desplazable con el dedo desde cualquier punto (también encima de botones), con barra visible si hay más
## contenido (ver TouchScroll).
static func scroll(content: Control) -> ScrollContainer:
	var sc := TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc

## Centra horizontalmente un contenido sin estirarlo (queda con su tamaño mínimo).
static func centered(content: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	h.add_child(content)
	return h

## Columna vertical de ancho fijo: nada de lo que contiene se estira más allá de ese ancho.
static func column(width: float, sep: int = 12) -> VBoxContainer:
	var v := vbox(sep)
	v.custom_minimum_size = Vector2(width, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return v

## Cuadrícula de columnas fijas centrada (las tarjetas que se meten dentro conservan su tamaño).
static func grid(columns: int, h_sep: int = 12, v_sep: int = 12) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", h_sep)
	g.add_theme_constant_override("v_separation", v_sep)
	return g

## Marco que limita el ancho del contenido (ver ContentFrame): evita que la interfaz se estire en pantallas anchas.
static func frame(max_w: float = 1280.0) -> ContentFrame:
	var f := ContentFrame.new()
	f.max_width = max_w
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

static func star_row(stars: int, px: float = 30.0, total: int = 3) -> HBoxContainer:
	var h := hbox(4)
	for i in total:
		var r := icon_rect("star" if i < stars else "star_empty", px)
		if i >= stars:
			r.modulate = Color(1, 1, 1, 0.3)   # estrella vacía: silueta blanca muy tenue
		h.add_child(r)
	return h

## Pastilla con un icono y un texto (monedas, tiempo, nivel...). El texto es el segundo hijo de la caja interior.
static func chip(icon_name: String, text: String, variation: String = "LabelHeader", px: float = 30.0, size: int = 0) -> PanelContainer:
	var p := card("PanelChip")
	var h := hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	h.add_child(icon_rect(icon_name, px))
	var l := label(text, variation, size)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return p

static func chip_label(c: PanelContainer) -> Label:
	return c.get_child(0).get_child(1) as Label

static func coin_chip(amount: int, px: float = 30.0) -> PanelContainer:
	return chip("coin", str(amount), "LabelHeader", px, int(px * 0.9))

## Título de sección con un icono real a la izquierda.
static func section_title(text: String, icon_name: String = "") -> HBoxContainer:
	var h := hbox(8)
	if icon_name != "":
		h.add_child(icon_rect(icon_name, 34))
	var l := label(text, "LabelHeader", 26)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

## Casilla de estadística: icono, nombre pequeño y valor grande, de ancho fijo.
static func stat_tile(icon_name: String, label_text: String, value_text: String, w: float = 300.0) -> PanelContainer:
	var p := card("PanelFlat")
	p.custom_minimum_size = Vector2(w, 0)
	var h := hbox(12)
	p.add_child(h)
	h.add_child(icon_rect(icon_name, 46))
	var v := vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := label(label_text, "LabelMuted", 16)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	v.add_child(label(value_text, "LabelHeader", 26))
	h.add_child(v)
	return p

## Puntos de nivel (mejoras): rellenos hasta level, vacíos hasta max_level.
static func pips(level: int, max_level: int) -> HBoxContainer:
	var h := hbox(4)
	for i in max_level:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(22, 10)
		var col := Palette.MUSTARD if i < level else Color(0.1, 0.06, 0.05, 0.9)
		p.add_theme_stylebox_override("panel", UITheme.box(col, UITheme.CLEAR, 5, 0, false, 0))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(p)
	return h

## Barra de progreso de tamaño fijo.
static func bar(value: float, max_value: float, w: float = 180.0, h: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(max_value, 0.001)
	b.value = clampf(value, 0.0, b.max_value)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## Círculo rojo con un número (avisos pendientes, p. ej. misiones por reclamar).
static func badge(count: int) -> PanelContainer:
	var p := card("PanelBadge")
	p.custom_minimum_size = Vector2(34, 34)
	var l := label(str(count), "LabelHeader", 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Aviso emergente: icono según el tipo y texto, sobre un fondo oscuro con borde de color.
static func toast_panel(text: String, kind: String = "info") -> PanelContainer:
	var p := card("PanelToast")
	p.add_theme_stylebox_override("panel", UITheme.toast_box(kind))
	var h := hbox(10)
	p.add_child(h)
	match kind:
		"success":
			h.add_child(icon_rect("check", 34))
		"warn":
			h.add_child(icon_rect("warning", 34))
		_:
			h.add_child(icon_rect("info", 34))
	var l := label(text, "LabelLight", 22)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Icono de una hamburguesa dibujado con barras de colores (una por capa, de abajo a arriba).
## thickness multiplica el grosor de cada capa (las tarjetas grandes la dibujan más alta).
static func burger_icon(layer_ids: Array, width: float = 40.0, thickness: float = 1.0) -> Control:
	var box_ := VBoxContainer.new()
	box_.add_theme_constant_override("separation", maxi(1, int(round(thickness))))
	box_.alignment = BoxContainer.ALIGNMENT_END
	box_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(layer_ids.size() - 1, -1, -1):
		var id := str(layer_ids[i])
		var layer_bar := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Catalog.ingredient_color(id)
		sb.set_corner_radius_all(int((4.0 if id.begins_with("bun") else 2.0) * thickness))
		layer_bar.add_theme_stylebox_override("panel", sb)
		var h := (12.0 if id == "bun_top" else (8.0 if id == "bun_bottom" else 5.0)) * thickness
		layer_bar.custom_minimum_size = Vector2(width if id.begins_with("bun") else width * 0.92, h)
		layer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box_.add_child(layer_bar)
	return box_

static func objective_label(e: Dictionary, show_progress: bool) -> String:
	var cur := int(e["current"])
	var tgt := int(e["target"])
	match str(e["key"]):
		"orders":
			return Loc.t("obj.orders", [cur, tgt]) if show_progress else Loc.t("goal.orders", [tgt])
		"customers":
			return Loc.t("obj.customers", [cur, tgt]) if show_progress else Loc.t("goal.customers", [tgt])
		"income":
			return Loc.t("obj.income", [cur, tgt]) if show_progress else Loc.t("goal.income", [tgt])
		"satisfaction":
			return Loc.t("obj.satisfaction", [cur, tgt]) if show_progress else Loc.t("goal.satisfaction", [tgt])
		"no_burnt":
			return Loc.t("obj.no_burnt") if not show_progress or cur > 0 else Loc.t("obj.no_burnt_failed")
		"recipe":
			var rn := Catalog.name_of(Catalog.recipe(str(e["recipe_id"])))
			return Loc.t("obj.recipe", [rn, cur, tgt]) if show_progress else Loc.t("goal.recipe", [tgt, rn])
	return ""

## Márgenes de la zona segura (muescas, esquinas redondeadas) en unidades del lienzo. En escritorio son 0.
static func safe_margins(node: Node) -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := Vector2(DisplayServer.window_get_size())
	var vp := node.get_viewport()
	if vp == null or win.x <= 0.0:
		return out
	var k := vp.get_visible_rect().size.x / win.x
	var safe := DisplayServer.get_display_safe_area()
	out["left"] = maxf(0.0, float(safe.position.x) * k)
	out["top"] = maxf(0.0, float(safe.position.y) * k)
	out["right"] = maxf(0.0, (win.x - float(safe.position.x + safe.size.x)) * k)
	out["bottom"] = maxf(0.0, (win.y - float(safe.position.y + safe.size.y)) * k)
	return out

static func margin_container(node: Node, base: int = 16) -> MarginContainer:
	var m := MarginContainer.new()
	var sm := safe_margins(node)
	m.add_theme_constant_override("margin_left", base + int(sm["left"]))
	m.add_theme_constant_override("margin_top", base + int(sm["top"]))
	m.add_theme_constant_override("margin_right", base + int(sm["right"]))
	m.add_theme_constant_override("margin_bottom", base + int(sm["bottom"]))
	return m

# ------------------------------------------------------------------ pantallas completas
const SCREEN_HEADER_H := 86.0   # alto de la barra de cabecera de las pantallas completas
const SCREEN_PAD := 18.0        # margen interior del cuerpo
const SCROLLBAR_W := 16.0       # hueco que se deja a la derecha para la barra de desplazamiento

## Pantalla completa (menús y recetas de la partida): fondo chocolate que tapa todo, barra de cabecera con icono,
## título, monedas (opcional) y botón de cierre, y un cuerpo que ocupa el resto. Respeta las muescas (zona segura).
## Devuelve {"root", "body" (VBoxContainer), "coin_label" (o null), "close"}.
static func screen_shell(host: Control, title_text: String, icon_name: String, with_coins: bool, on_close: Callable) -> Dictionary:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", UITheme.screen_bg())
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var sm := safe_margins(host)
	var v := vbox(0)
	root.add_child(v)
	var bar := PanelContainer.new()
	var bar_sb := UITheme.screen_header()
	bar_sb.content_margin_left = 16.0 + float(sm["left"])
	bar_sb.content_margin_right = 16.0 + float(sm["right"])
	bar_sb.content_margin_top = 8.0 + float(sm["top"])
	bar.add_theme_stylebox_override("panel", bar_sb)
	bar.custom_minimum_size = Vector2(0, SCREEN_HEADER_H + float(sm["top"]))
	v.add_child(bar)
	var head := hbox(14)
	bar.add_child(head)
	head.add_child(icon_rect(icon_name, 58))
	var title := label(title_text, "LabelTitle", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var coin_label: Label = null
	if with_coins:
		var chip_ := coin_chip(GameState.coins, 34)
		chip_.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin_label = chip_label(chip_)
		head.add_child(chip_)
	var close := icon_button("close", "ButtonIcon", 72)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	head.add_child(close)
	var m := MarginContainer.new()
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", int(SCREEN_PAD + float(sm["left"])))
	m.add_theme_constant_override("margin_right", int(SCREEN_PAD * 0.5 + float(sm["right"])))
	m.add_theme_constant_override("margin_top", int(SCREEN_PAD))
	m.add_theme_constant_override("margin_bottom", int(SCREEN_PAD * 0.6 + float(sm["bottom"])))
	v.add_child(m)
	var body := vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(body)
	return {"root": root, "body": body, "coin_label": coin_label, "close": close}

## Ancho y alto útiles del cuerpo de una pantalla completa (sin la barra de desplazamiento).
static func screen_inner_size(node: Node) -> Vector2:
	var avail := canvas_size(node)
	var sm := safe_margins(node)
	var w := avail.x - float(sm["left"]) - float(sm["right"]) - SCREEN_PAD * 1.5 - SCROLLBAR_W
	var h := avail.y - float(sm["top"]) - float(sm["bottom"]) - SCREEN_HEADER_H - SCREEN_PAD * 1.6
	return Vector2(floorf(w), floorf(h))

## Reparte inner_w en columnas de al menos min_w (entre 1 y max_cols) y devuelve [columnas, ancho de cada una].
static func fill_columns(inner_w: float, min_w: float, gap: float, max_cols: int) -> Array:
	var cols := clampi(int(floorf((inner_w + gap) / (min_w + gap))), 1, max_cols)
	return [cols, floorf((inner_w - gap * float(cols - 1)) / float(cols))]

## Diálogo modal de confirmación para acciones destructivas. Funciona también con el árbol pausado.
## no_text / on_no (opcionales) cambian el texto del botón de cancelar y le añaden una acción; icon_name, el icono.
static func confirm(host: Node, message: String, yes_text: String, on_yes: Callable, danger: bool = true, no_text: String = "", on_no: Callable = Callable(), icon_name: String = "warning") -> void:
	var layer := Control.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.theme = UITheme.get_theme()
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel_w := minf(520.0, canvas_size(host).x - 40.0)
	var panel := card()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)
	var v := vbox(16)
	panel.add_child(v)
	var head := hbox(14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(icon_rect(icon_name, 56))
	var msg := label(message, "LabelLight", 24)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(panel_w - 140.0, 0)
	msg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(msg)
	v.add_child(head)
	var row := hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var btn_w := minf(200.0, (panel_w - 36.0 - 14.0) * 0.5)
	var no := icon_text_button("close", Loc.t("ui.cancel") if no_text == "" else no_text, "ButtonSecondary", H_SMALL, btn_w, 32)
	var yes := icon_text_button("check", yes_text, "ButtonDanger" if danger else "ButtonSuccess", H_SMALL, btn_w, 32)
	row.add_child(no)
	row.add_child(yes)
	no.pressed.connect(func() -> void:
		layer.queue_free()
		if on_no.is_valid():
			on_no.call())
	yes.pressed.connect(func() -> void:
		layer.queue_free()
		on_yes.call())
	host.add_child(layer)
