class_name HUD
extends CanvasLayer
## HUD de la partida (diseño móvil horizontal, compacto): monedas/nivel/XP arriba a la izquierda, temporizador y
## objetivo arriba en el centro, recetas y pausa arriba a la derecha con las comandas en columna debajo (fuera del
## centro de la pantalla, que queda libre para ver la cocina), indicador de interacción y objeto en mano abajo en el
## centro (entre el joystick y el botón de acción), avisos discretos y controles táctiles. Todo vive dentro de un ContentFrame de ancho limitado, así que en
## pantallas muy anchas los elementos no se separan hacia los bordes ni se estiran.

## Icono que se dibuja para cada tipo de indicador de interacción que envían las estaciones.
const PROMPT_ICONS: Dictionary = {"grab": "backpack", "drop": "downgrade", "use": "cursor", "tray": "gift", "blocked": "close", "trash": "trash"}
const TICKET_W := 190.0         # ancho de cada comanda (columna derecha)
const TICKET_H_EST := 74.0      # alto máximo aproximado de una comanda (nombre en dos líneas; lo usa check_ui_layout.py)
const OBJECTIVE_MAX_W := 380.0   # ancho máximo del texto del objetivo antes de pasar a dos líneas

@onready var root: Control = $Root
@onready var touch: TouchControls = $Root/Touch

var shift: ShiftManager = null
var orders: OrderManager = null

var _cfg: Dictionary = {}
var _stats_chip: Control
var _info_chip: Control
var _coins_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _timer_label: Label
var _objective_panel: Control
var _objective_label: Label
var _tickets: VBoxContainer
var _ticket_nodes: Dictionary = {}
var _prompt_box: PanelContainer
var _prompt_icon: TextureRect
var _reticle: Panel
var _prompt_label: Label
var _held_box: PanelContainer
var _held_label: Label
var _toasts: VBoxContainer
var _center_label: Label
var _fps_label: Label
var _timer_urgent := false
var _pause_btn: Button
var _recipes_btn: Button
var _obj_timer := 0.0
var _overlay_layer: CanvasLayer = null

func _ready() -> void:
	layer = 10
	root.theme = UITheme.get_theme()
	_build()
	touch.register_blocker(_pause_btn)
	touch.register_blocker(_recipes_btn)
	Events.coins_changed.connect(_on_coins)
	Events.xp_changed.connect(_on_xp)
	Events.toast.connect(_on_toast)
	Events.held_changed.connect(_on_held)
	Events.prompt_changed.connect(_on_prompt)
	Events.order_created.connect(_on_order_created)
	Events.order_changed.connect(_on_order_changed)
	Events.order_closed.connect(_on_order_closed)
	Events.settings_changed.connect(_on_settings)
	_refresh_stats()
	_on_prompt({})

## Columna a todo el ancho anclada a una altura de la pantalla, cuyos hijos se centran sin estirarse.
func _centered_column(anchor_y: float, top: float, bottom: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)
	col.anchor_left = 0.0
	col.anchor_right = 1.0
	col.anchor_top = anchor_y
	col.anchor_bottom = anchor_y
	col.offset_left = 0.0
	col.offset_right = 0.0
	col.offset_top = top
	col.offset_bottom = bottom
	return col

func _build() -> void:
	var frame := UIKit.frame(1500.0)
	root.add_child(frame)
	var top := UIKit.margin_container(self, 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(bar)
	# izquierda: monedas, nivel y experiencia
	var stats := UIKit.card("PanelChip")
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_child(stats)
	_stats_chip = stats
	var sv := UIKit.vbox(4)
	stats.add_child(sv)
	var coin_row := UIKit.hbox(8)
	coin_row.add_child(UIKit.icon_rect("coin", 34))
	_coins_label = UIKit.label("0", "LabelOutlined", 28)
	coin_row.add_child(_coins_label)
	sv.add_child(coin_row)
	var lv_row := UIKit.hbox(6)
	lv_row.add_child(UIKit.icon_rect("medal", 26))
	_level_label = UIKit.label("", "LabelLight", 20)
	lv_row.add_child(_level_label)
	sv.add_child(lv_row)
	_xp_bar = UIKit.bar(0.0, 1.0, 120.0, 10.0)
	sv.add_child(_xp_bar)
	# centro: temporizador y objetivo
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_constant_override("separation", 6)
	bar.add_child(mid)
	# una sola pastilla con el tiempo y el objetivo (el objetivo ocupa solo lo que mide su texto)
	var info_chip := UIKit.card("PanelChip")
	info_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var info_row := UIKit.hbox(10)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_chip.add_child(info_row)
	info_row.add_child(UIKit.icon_rect("clock", 32))
	_timer_label = UIKit.label("", "LabelOutlined", 30)
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_timer_label)
	var obj_box := UIKit.hbox(10)
	obj_box.add_child(UIKit.divider_vertical())
	_objective_label = UIKit.label("", "LabelLight", 17)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	obj_box.add_child(_objective_label)
	_objective_panel = obj_box
	info_row.add_child(obj_box)
	mid.add_child(info_chip)
	_info_chip = info_chip
	# derecha: recetas y pausa, y debajo las comandas en columna (lejos del centro y del botón de acción)
	var right_col := UIKit.vbox(8)
	right_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := UIKit.hbox(8)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipes_btn = UIKit.icon_button("book", "ButtonRound", 68)
	_recipes_btn.pressed.connect(func() -> void: Events.recipes_opened.emit())
	_pause_btn = UIKit.icon_button("settings", "ButtonRound", 68)
	_pause_btn.pressed.connect(func() -> void: Events.pause_requested.emit())
	right.add_child(_recipes_btn)
	right.add_child(_pause_btn)
	right_col.add_child(right)
	_tickets = VBoxContainer.new()
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tickets.size_flags_horizontal = Control.SIZE_SHRINK_END
	_tickets.add_theme_constant_override("separation", 6)
	right_col.add_child(_tickets)
	bar.add_child(right_col)
	# mira central (siempre en el centro exacto de la pantalla)
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle = Panel.new()   # mira central: punto claro con borde oscuro (dibujado, sin imagen)
	var dot := UITheme.box(Color(1, 0.97, 0.9, 0.92), Color(0.16, 0.08, 0.05, 0.85), 99, 2, false, 0)
	_reticle.add_theme_stylebox_override("panel", dot)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.position = Vector2(-6, -6)
	_reticle.size = Vector2(12, 12)
	anchor.add_child(_reticle)
	# indicador de interacción: una pastilla con icono y texto abajo, encima del objeto en mano, para no tapar lo que
	# hay delante de la mira
	var prompt_col := _centered_column(1.0, -176.0, -118.0)
	_prompt_box = UIKit.card("PanelChip")
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var prompt_row := UIKit.hbox(10)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_icon = UIKit.icon_rect("cursor", 40)
	prompt_row.add_child(_prompt_icon)
	_prompt_label = UIKit.label("", "LabelLight", 22)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_label)
	_prompt_box.add_child(prompt_row)
	prompt_col.add_child(_prompt_box)
	# objeto en la mano
	var held_col := _centered_column(1.0, -112.0, -60.0)
	_held_box = UIKit.chip("backpack", "", "LabelLight", 34, 22)
	_held_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_held_label = UIKit.chip_label(_held_box)
	_held_box.visible = false
	held_col.add_child(_held_box)
	# avisos
	_toasts = _centered_column(0.0, 178.0, 284.0)
	# mensaje grande central (cuenta atrás)
	_center_label = UIKit.label("", "LabelTitle", 130)
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_center_label)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# FPS (opcional)
	_fps_label = UIKit.label("", "LabelOutlined", 18)
	root.add_child(_fps_label)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_left = 12.0
	_fps_label.offset_top = -34.0
	_fps_label.visible = SettingsManager.show_fps

func bind(s: ShiftManager, o: OrderManager) -> void:
	shift = s
	orders = o

## Prepara el temporizador y el objetivo con la configuración del turno antes de empezar.
func show_config(cfg: Dictionary) -> void:
	_cfg = cfg
	_update_objective()

func _on_settings() -> void:
	_fps_label.visible = SettingsManager.show_fps
	_refresh_stats()

func _refresh_stats() -> void:
	_coins_label.text = str(GameState.coins)
	_level_label.text = Loc.t("hud.level", [GameState.level])
	_xp_bar.max_value = GameState.xp_needed(GameState.level)
	_xp_bar.value = GameState.xp

func _on_coins(total: int, delta: int) -> void:
	_coins_label.text = str(total)
	if delta != 0:
		_coins_label.pivot_offset = _coins_label.size * 0.5
		_coins_label.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(_coins_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_xp(level: int, xp: int, needed: int) -> void:
	_level_label.text = Loc.t("hud.level", [level])
	_xp_bar.max_value = needed
	_xp_bar.value = xp

func _process(delta: float) -> void:
	if shift != null:
		var secs := 0.0
		if shift.running:
			secs = shift.time_left if shift.has_time_limit() else shift.elapsed
		else:
			secs = float(_cfg.get("duration", 0.0))
		# solo se toca la etiqueta cuando cambia: cambiar texto o color cada fotograma obliga a recolocar la interfaz
		var txt := Util.fmt_time(secs)
		if txt != _timer_label.text:
			_timer_label.text = txt
		var urgent := shift.running and shift.has_time_limit() and shift.time_left < 15.0
		if urgent != _timer_urgent:
			_timer_urgent = urgent
			_timer_label.add_theme_color_override("font_color", Palette.KETCHUP.lightened(0.35) if urgent else Palette.CREAM)
	_obj_timer -= delta
	if _obj_timer <= 0.0:
		_obj_timer = 0.4
		_update_objective()
	for id in _ticket_nodes:
		var e: Dictionary = _ticket_nodes[id]
		var o := e["order"] as Order
		var ratio := o.patience_ratio()
		var bar := e["bar"] as ProgressBar
		var v := snappedf(ratio * 100.0, 0.5)
		if v != bar.value:
			bar.value = v
		var fill := e["fill"] as StyleBoxFlat
		var col := Palette.KETCHUP if ratio < 0.3 else (Palette.MUSTARD if ratio < 0.6 else Palette.LETTUCE)
		if fill.bg_color != col:
			fill.bg_color = col
	if _fps_label.visible:
		var ft := "%d FPS" % Engine.get_frames_per_second()
		if ft != _fps_label.text:
			_fps_label.text = ft

## Oculta o muestra la pastilla de monedas y nivel (el tutorial pone ahí su tarjeta de instrucciones). Se deja su
## hueco con transparencia para que el resto de la fila superior no se desplace.
func set_stats_visible(v: bool) -> void:
	_stats_chip.modulate.a = 1.0 if v else 0.0

## Oculta o muestra la pastilla de tiempo y objetivo (el tutorial no tiene tiempo y su tarjeta ocupa esa zona).
func set_info_visible(v: bool) -> void:
	_info_chip.modulate.a = 1.0 if v else 0.0

## Reserva una franja a la izquierda (la tarjeta del tutorial) para que los avisos se centren en el resto.
func reserve_left(px: float) -> void:
	_toasts.offset_left = px

## Botón del libro de recetas (el tutorial lo señala).
func recipes_button() -> Button:
	return _recipes_btn

func _update_objective() -> void:
	if str(_cfg.get("mode", "")) == Const.MODE_TUTORIAL:
		_objective_label.text = Loc.t("tut.objective")
		_fit_objective()
		return
	var win: Dictionary = _cfg.get("win", {})
	var stats: Dictionary = shift.stats if shift != null else {}
	if win.is_empty():
		var ok := int(stats.get("orders_ok", 0))
		_objective_label.text = Loc.t("obj.free", [ok, ShiftRules.net_income(stats)]) if not _cfg.is_empty() else ""
		_fit_objective()
		return
	var parts: Array = []
	for e in ShiftRules.objective_progress(win, stats):
		parts.append(UIKit.objective_label(e, true))
	_objective_label.text = "  ·  ".join(parts)
	_fit_objective()

## Ajusta el ancho del texto del objetivo a lo que mide (hasta un máximo, a partir del cual pasa a dos líneas).
func _fit_objective() -> void:
	var text := _objective_label.text
	_objective_panel.visible = text != ""
	if text == "":
		return
	var f := _objective_label.get_theme_font("font")
	var fs := _objective_label.get_theme_font_size("font_size")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var max_w := clampf(UIKit.canvas_size(self).x - 540.0, 160.0, OBJECTIVE_MAX_W)
	_objective_label.custom_minimum_size = Vector2(minf(w + 6.0, max_w), 0)

# ------------------------------------------------------------------ comandas
func _on_order_created(o: RefCounted) -> void:
	var order := o as Order
	var ticket_w := TICKET_W
	var panel := UIKit.card("PanelTicket")
	panel.custom_minimum_size = Vector2(ticket_w, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# comanda compacta de dos filas: número, receta e icono; paciencia y estado
	var v := UIKit.vbox(3)
	panel.add_child(v)
	var head := UIKit.hbox(6)
	var num := UIKit.label("#%d" % (order.service_point.index + 1), "LabelInkBold", 18)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(num)
	var nm := UIKit.label(order.recipe_name(), "LabelInk", 14)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.custom_minimum_size = Vector2(ticket_w - 30.0 - 22.0 - 34.0, 0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	var bi := UIKit.burger_stack(Catalog.recipe_layers(order.recipe_id), 40)
	bi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bi)
	v.add_child(head)
	var foot := UIKit.hbox(6)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 100.0
	pb.custom_minimum_size = Vector2(0, 8)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := UITheme.box(Palette.LETTUCE, UITheme.CLEAR, 8, 0, false, 0)
	pb.add_theme_stylebox_override("fill", fill)
	foot.add_child(pb)
	var st := UIKit.label(Loc.t(order.state_key()), "LabelInk", 12)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(st)
	v.add_child(foot)
	panel.modulate.a = 0.0
	_tickets.add_child(panel)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
	_ticket_nodes[order.id] = {"panel": panel, "bar": pb, "fill": fill, "state": st, "order": order}

func _on_order_changed(o: RefCounted) -> void:
	var order := o as Order
	if _ticket_nodes.has(order.id):
		((_ticket_nodes[order.id] as Dictionary)["state"] as Label).text = Loc.t(order.state_key())

func _on_order_closed(o: RefCounted, _outcome: String) -> void:
	var order := o as Order
	if not _ticket_nodes.has(order.id):
		return
	var panel := (_ticket_nodes[order.id] as Dictionary)["panel"] as Control
	_ticket_nodes.erase(order.id)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)

# ------------------------------------------------------------------ indicador, objeto en mano, avisos
func _on_prompt(p: Dictionary) -> void:
	if p.is_empty():
		_prompt_box.visible = false
		_reticle.visible = true
		return
	_reticle.visible = false
	_prompt_box.visible = true
	_prompt_icon.texture = UIKit.icon(str(PROMPT_ICONS.get(str(p.get("icon", "use")), "cursor")), 40.0)
	_prompt_box.modulate = Color.WHITE if bool(p.get("ok", true)) else Color(1, 1, 1, 0.78)
	_prompt_label.text = Loc.t(str(p.get("text", "")), p.get("args", []))

func _on_held(text: String) -> void:
	_held_label.text = Loc.t("hud.holding", [text]) if text != "" else ""
	_held_box.visible = text != ""

func _on_toast(text: String, kind: String) -> void:
	var p := UIKit.toast_panel(text, kind)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func show_center_text(text: String) -> void:
	_center_label.text = text
	if text != "":
		_center_label.pivot_offset = _center_label.size * 0.5
		_center_label.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(_center_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_gameplay_visible(v: bool) -> void:
	root.visible = v

func add_overlay(node: Control) -> void:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.layer = 30
		_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_overlay_layer)
	node.theme = UITheme.get_theme()
	_overlay_layer.add_child(node)
