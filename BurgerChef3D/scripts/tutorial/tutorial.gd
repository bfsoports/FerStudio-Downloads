class_name Tutorial
extends Node
## Tutorial jugable: un turno guiado sin tiempo ni fallos en el que el jugador prepara y entrega de verdad una
## Hamburguesa con queso. Cada paso muestra una tarjeta con instrucciones (adaptadas a táctil o teclado y ratón), una
## flecha 3D que flota sobre el objetivo y una flecha en el borde de la pantalla cuando el objetivo no se ve.
##
## Los pasos de cocina no dependen del orden en que el jugador haga las cosas: cada medio segundo se mira el estado
## real de la cocina (qué lleva en la mano, qué hay en la plancha, en la tabla y en la bandeja) y se muestra el primer
## paso que falta. Si tira la carne o deshace algo, el tutorial vuelve al paso correspondiente.
##
## Lo que se hace en el tutorial no cuenta para estadísticas, misiones ni monedas (GameState.tracking_enabled); al
## terminarlo por primera vez se regalan REWARD_COINS monedas.

const RECIPE := "cheese"
const REWARD_COINS := 100
const MOVE_METERS := 3.0
const LOOK_AMOUNT := 1.6
const POLL := 0.25
## Tarjeta de instrucciones (los usa también tools/check_ui_layout.py para comprobar que no pisa el joystick).
const CARD_X := 12.0
const CARD_Y := 12.0
const CARD_W_RATIO := 0.4
const CARD_MIN_W := 330.0
const CARD_MAX_W := 440.0
const CARD_FONT := 18

## Orden de los pasos. Los de cocina (de "patty_take" a "to_tray") se recalculan con el estado real.
const STEPS: Array = ["welcome", "move", "look", "customer", "book", "patty_take", "patty_grill", "bun_take",
	"bun_board", "patty_cooked", "cheese", "bun_top", "to_tray", "bell", "dirty", "trash", "tips"]
const KITCHEN_FIRST := 5     # índice de "patty_take"
const KITCHEN_LAST := 12     # índice de "to_tray"
## Pasos que avanzan con el botón «Continuar».
const CONTINUE_STEPS: Array = ["welcome", "tips"]
## Icono de la tarjeta en cada paso.
const STEP_ICONS: Dictionary = {"welcome": "burger", "move": "player", "look": "target", "customer": "friend",
	"book": "book", "bell": "gift", "dirty": "warning", "trash": "trash", "tips": "trophy"}

var _game: Node = null
var _rest: Restaurant = null
var _player: PlayerController = null
var _hud: HUD = null
var _spawner: CustomerSpawner = null
var _shift: ShiftManager = null

var _step := -1
var _active := false
var _finished := false
var _retry := false
var _order_seen := false
var _move_start := 0.0
var _look_start := 0.0
var _poll := 0.0
var _t := 0.0

var _card: PanelContainer = null
var _card_step: Label = null
var _card_icon: TextureRect = null
var _card_text: Label = null
var _card_hint: Label = null
var _card_btn: Button = null
var _pointer: TutorialPointer = null
var _marker: Node3D = null
var _target: Node3D = null
var _target_offset := Vector3.ZERO

func setup(game: Node, rest: Restaurant, player: PlayerController, hud: HUD, spawner: CustomerSpawner, shift: ShiftManager) -> void:
	_game = game
	_rest = rest
	_player = player
	_hud = hud
	_spawner = spawner
	_shift = shift
	_build_card()
	_hud.set_stats_visible(false)
	_hud.set_info_visible(false)
	_hud.reserve_left(CARD_X + _card_width() + 8.0)
	_pointer = TutorialPointer.new()
	_hud.root.add_child(_pointer)
	_hud.root.move_child(_pointer, 0)
	_marker = _make_marker()
	_rest.add_child(_marker)
	_marker.visible = false
	Events.order_created.connect(_on_order_created)
	Events.order_closed.connect(_on_order_closed)
	Events.recipes_opened.connect(_on_recipes_opened)
	Events.tray_washed.connect(_on_tray_washed)
	Events.item_discarded.connect(_on_item_discarded)
	Events.language_changed.connect(func(_l: String) -> void: _show_step())
	_card.visible = false

## Empieza el tutorial (lo llama la partida al terminar la cuenta atrás).
func begin() -> void:
	_active = true
	_go(0)

func current_step() -> String:
	return str(STEPS[_step]) if _step >= 0 and _step < STEPS.size() else ""

# ------------------------------------------------------------------ tarjeta de instrucciones
func _build_card() -> void:
	_card = UIKit.card("PanelChip")
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sm := UIKit.safe_margins(_hud)
	# la tarjeta ocupa la esquina superior izquierda (la pastilla de monedas se oculta en el tutorial), por encima de
	# la zona del joystick
	_card.position = Vector2(CARD_X + float(sm["left"]), CARD_Y + float(sm["top"]))
	_card.custom_minimum_size = Vector2(_card_width(), 0)
	var v := UIKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	var head := UIKit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_icon = UIKit.icon_rect("info", 30)
	head.add_child(_card_icon)
	_card_step = UIKit.label("", "LabelGold", 16)
	_card_step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_card_step)
	v.add_child(head)
	_card_text = UIKit.label("", "LabelLight", CARD_FONT)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(_card_width() - 30.0, 0)
	v.add_child(_card_text)
	_card_hint = UIKit.label("", "LabelMuted", 15)
	_card_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_hint.custom_minimum_size = Vector2(_card_width() - 30.0, 0)
	v.add_child(_card_hint)
	_card_btn = UIKit.icon_text_button("check", Loc.t("tut.continue"), "ButtonSuccess", UIKit.H_SMALL, 0, 30)
	_card_btn.pressed.connect(_on_continue)
	v.add_child(_card_btn)
	_hud.root.add_child(_card)
	# los toques que empiezan sobre la tarjeta no mueven el joystick
	_hud.touch.register_blocker(_card)

func _card_width() -> float:
	return clampf(UIKit.canvas_size(_hud).x * CARD_W_RATIO, CARD_MIN_W, CARD_MAX_W)

func _act_text() -> String:
	return Loc.t("tut.act_touch") if SettingsManager.use_touch_ui() else Loc.t("tut.act_desktop")

## Texto de cada paso (con variantes para táctil y para teclado y ratón).
func _text_for(id: String) -> String:
	var touch := SettingsManager.use_touch_ui()
	match id:
		"move":
			return Loc.t("tut.move_touch") if touch else Loc.t("tut.move_desktop")
		"look":
			return Loc.t("tut.look_touch") if touch else Loc.t("tut.look_desktop")
		"patty_take":
			return Loc.t("tut.patty_take", [_act_text()])
		"book":
			return Loc.t("tut.book") if touch else Loc.t("tut.book_desktop")
	return Loc.t("tut." + id)

## Pista secundaria según lo que lleva el jugador en la mano (ayuda cuando hace las cosas en otro orden).
func _hint_for(id: String) -> String:
	var held := _player.held
	if id == "patty_cooked" and _grill_patty() != null and _grill_patty().state != FoodItem.State.COOKED and held == null:
		return Loc.t("tut.hint_wait_grill")
	if held == null:
		return ""
	var useful := _held_destination() != null
	if not useful and id in ["patty_take", "bun_take", "cheese", "bun_top"]:
		return Loc.t("tut.hint_drop")
	return ""

func _show_step() -> void:
	if _step < 0 or _step >= STEPS.size():
		return
	var id := current_step()
	_card.visible = true
	_card_step.text = "%s  ·  %s" % [Loc.t("tut.title"), Loc.t("tut.step", [_step + 1, STEPS.size()])]
	_card_icon.texture = UIKit.icon(str(STEP_ICONS.get(id, "info")), 30.0)
	_card_text.text = _text_for(id)
	_card_hint.text = _hint_for(id)
	_card_hint.visible = _card_hint.text != ""
	# en escritorio el ratón está capturado durante la partida: se continúa con Intro o Espacio
	_card_btn.text = Loc.t("tut.continue") if SettingsManager.use_touch_ui() else Loc.t("tut.continue_key")
	_card_btn.visible = CONTINUE_STEPS.has(id)

func _go(step: int) -> void:
	if step == _step:
		return
	var forward := step > _step
	_step = step
	GameState.tutorial_step = _step
	Events.tutorial_step_changed.emit(_step)
	var id := current_step()
	if id == "move":
		_move_start = _player.distance_walked
	elif id == "look":
		_look_start = _player.look_total
	elif id == "customer":
		_order_seen = false
		_spawner.spawn_now()
	_show_step()
	_update_target()
	if forward and _step > 0:
		AudioManager.play_sfx("click", -2.0, 1.2)
		_card.pivot_offset = _card.size * 0.5
		_card.scale = Vector2(1.06, 1.06)
		_card.create_tween().tween_property(_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _finished or not CONTINUE_STEPS.has(current_step()):
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_continue()

func _on_continue() -> void:
	AudioManager.play_sfx("click")
	var id := current_step()
	if id == "tips":
		_complete()
	elif CONTINUE_STEPS.has(id):
		_go(_step + 1)

# ------------------------------------------------------------------ avance de los pasos
func _process(delta: float) -> void:
	_t += delta
	_animate_marker()
	if not _active or _finished:
		return
	if _game != null and _game.has_method("is_overlay_open") and bool(_game.call("is_overlay_open")):
		return
	var id := current_step()
	if id == "move" and _player.distance_walked - _move_start >= MOVE_METERS:
		_praise()
		_go(_step + 1)
	elif id == "look" and _player.look_total - _look_start >= LOOK_AMOUNT:
		_praise()
		_go(_step + 1)
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	# también en el paso de la campana: si quita la hamburguesa de la bandeja, se vuelve atrás
	if _step >= KITCHEN_FIRST and _step <= KITCHEN_LAST + 1:
		var k := _first_missing_kitchen_step()
		if k != _step:
			if k > _step:
				_praise()
			_go(k)
	if id == "customer":
		if _order_seen:
			_go(_step + 1)
		elif _point().customer == null:
			_spawner.spawn_now()
	_update_target()
	_card_hint.text = _hint_for(current_step())
	_card_hint.visible = _card_hint.text != ""

func _praise() -> void:
	AudioManager.play_sfx("ding", -6.0, 1.4)

## Primer paso de cocina que falta según el estado real (o el paso de la campana si ya está todo en la bandeja).
func _first_missing_kitchen_step() -> int:
	var stack := _current_stack()
	var held := _player.held
	var held_id := (held as FoodItem).ingredient_id if held is FoodItem else ""
	var stack_has := func(ing: String) -> bool: return stack != null and stack.ids().has(ing)
	var grill_has := _grill_patty() != null
	var checks: Array = [
		held_id == "patty" or grill_has or stack_has.call("patty"),            # patty_take
		grill_has or stack_has.call("patty"),                                   # patty_grill
		held_id == "bun_bottom" or stack != null,                               # bun_take
		stack != null,                                                          # bun_board
		stack_has.call("patty"),                                                # patty_cooked
		stack_has.call("cheese"),                                               # cheese
		stack != null and stack.closed,                                         # bun_top
		_tray_stack() != null and _tray_stack().closed,                         # to_tray
	]
	for i in checks.size():
		if not bool(checks[i]):
			return KITCHEN_FIRST + i
	return KITCHEN_LAST + 1

func _on_order_created(_o: RefCounted) -> void:
	if current_step() == "customer":
		_order_seen = true

func _on_recipes_opened() -> void:
	if current_step() == "book":
		_go(_step + 1)

func _on_order_closed(_o: RefCounted, outcome: String) -> void:
	# también vale si toca la campana justo antes de que el tutorial pase al paso de la campana
	if _step < KITCHEN_FIRST or _step > STEPS.find("bell"):
		return
	if outcome == "ok":
		_hud.show_center_text(Loc.t("tut.great"))
		get_tree().create_timer(0.9, false).timeout.connect(func() -> void: _hud.show_center_text(""))
	else:
		_retry = true
		Events.toast.emit(Loc.t("tut.retry"), "warn")
	_go(STEPS.find("dirty"))

func _on_tray_washed() -> void:
	if current_step() != "dirty":
		return
	if _retry:
		# el pedido salió mal: otro cliente y se repite la cocina
		_retry = false
		_go(STEPS.find("customer"))
	else:
		_go(_step + 1)

func _on_item_discarded(_id: String) -> void:
	if current_step() == "trash":
		_praise()
		_go(_step + 1)

# ------------------------------------------------------------------ estado de la cocina
func _point() -> ServicePoint:
	return _rest.service_points[0] as ServicePoint

func _board() -> AssemblyStation:
	for b in _rest.assembly_boards:
		var st := b as AssemblyStation
		if st.is_unlocked():
			return st
	return _rest.assembly_boards[0] as AssemblyStation

## Hamburguesa en curso: en la tabla, en la mano o en la bandeja.
func _current_stack() -> BurgerStack:
	if _player.held is BurgerStack:
		return _player.held as BurgerStack
	for b in _rest.assembly_boards:
		var st := b as AssemblyStation
		if st.stack != null:
			return st.stack
	return _tray_stack()

func _tray_stack() -> BurgerStack:
	return _point().slot_items[ServicePoint.SLOT_MAIN] as BurgerStack

func _grill_patty() -> FoodItem:
	for it in _rest.grill.items_present():
		var fi := it as FoodItem
		if fi != null and fi.ingredient_id == "patty":
			return fi
	return null

func _crate(ingredient: String) -> IngredientCrate:
	for c in _rest.crates:
		var ic := c as IngredientCrate
		if ic.ingredient_id == ingredient:
			return ic
	return null

## Adónde hay que llevar lo que el jugador tiene en la mano para avanzar (o null si no sirve para la receta).
func _held_destination() -> Node3D:
	var held := _player.held
	if held == null:
		return null
	if held is DirtyTray:
		return _rest.sink
	if held is BurgerStack:
		if (held as BurgerStack).closed:
			return _point()
		return _board()
	var fi := held as FoodItem
	if fi == null:
		return null
	if fi.ingredient_id == "patty":
		if fi.state != FoodItem.State.COOKED:
			return _rest.grill
		return _board()
	if current_step() == "trash":
		return _rest.trash
	if ["bun_bottom", "cheese", "bun_top"].has(fi.ingredient_id):
		return _board()
	return null

## Objetivo que señalan las flechas en el paso actual.
func _update_target() -> void:
	var id := current_step()
	var tgt: Node3D = null
	var ctl: Control = null
	var dest := _held_destination()
	var kitchen := _step >= KITCHEN_FIRST and _step <= KITCHEN_LAST
	if kitchen and _player.held != null and dest != null:
		# lo que lleva en la mano sirve: se señala adónde llevarlo
		tgt = dest
	else:
		match id:
			"customer":
				tgt = _point()
			"bell":
				tgt = _point()
				if not _rest.bells.is_empty():
					tgt = _rest.bells[0] as Node3D
			"book":
				ctl = _hud.recipes_button()
			"patty_take", "patty_grill":
				tgt = _crate("patty")
			"bun_take", "bun_board":
				tgt = _crate("bun_bottom")
			"patty_cooked":
				tgt = _crate("patty")
				if _grill_patty() != null:
					tgt = _rest.grill
			"cheese":
				tgt = _crate("cheese")
			"bun_top":
				tgt = _crate("bun_top")
			"to_tray":
				tgt = _board()
			"dirty":
				if _player.held is DirtyTray or not _rest.sink.items_present().is_empty():
					tgt = _rest.sink
				elif _point().dirty_tray != null and is_instance_valid(_point().dirty_tray):
					tgt = _point().dirty_tray
				else:
					tgt = _rest.sink
			"trash":
				tgt = _crate("lettuce")
				if _player.held != null:
					tgt = _rest.trash
	_set_target(tgt, ctl)

func _set_target(tgt: Node3D, ctl: Control) -> void:
	_target = tgt
	if ctl != null:
		_pointer.point_at_control(ctl)
		_marker.visible = false
		return
	if tgt == null or not is_instance_valid(tgt):
		_pointer.clear()
		_marker.visible = false
		return
	_target_offset = Vector3(0, _marker_height(tgt), 0)
	_marker.visible = true
	_pointer.point_at_world(tgt.global_position + _target_offset)

## Altura de la flecha 3D sobre cada tipo de objetivo.
func _marker_height(tgt: Node3D) -> float:
	if tgt is DirtyTray:
		return 0.45
	if tgt is ServiceBell:
		return 0.75
	if tgt is IngredientCrate:
		return 1.45
	if tgt is CookStation:
		return 1.85
	if tgt is SinkStation:
		return 1.25
	return 1.55

# ------------------------------------------------------------------ flecha 3D
func _make_marker() -> Node3D:
	var root := Node3D.new()
	var m := Prims.unshaded(TutorialPointer.COLOR)
	# borde oscuro: el mismo cono algo más grande, dibujado por dentro (material propio, no el compartido de Prims)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = TutorialPointer.OUTLINE
	dark.cull_mode = BaseMaterial3D.CULL_FRONT
	# cono que apunta hacia abajo con un borde oscuro para que se vea sobre cualquier fondo
	var cone := Prims.cyl(root, 0.17, 0.0, 0.3, Vector3(0, 0.15, 0), m, 12)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rim := Prims.cyl(root, 0.2, 0.0, 0.34, Vector3(0, 0.15, 0), dark, 12)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stem := Prims.cyl(root, 0.06, 0.06, 0.22, Vector3(0, 0.41, 0), m, 10)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

func _animate_marker() -> void:
	if _marker == null or not _marker.visible:
		return
	if _target == null or not is_instance_valid(_target):
		_marker.visible = false
		return
	var base := _target.global_position + _target_offset
	_marker.global_position = base + Vector3(0, 0.12 * sin(_t * 4.0), 0)
	_marker.rotation.y = _t * 1.5
	_pointer.point_at_world(base)

# ------------------------------------------------------------------ fin del tutorial
func _complete() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	var first := not GameState.tutorial_done
	GameState.tutorial_done = true
	if first:
		EconomyManager.earn(REWARD_COINS, "tutorial")
	SaveManager.save_now()
	_cleanup()
	AudioManager.play_sfx("win")
	_show_end_dialog(first)

## Saltar el tutorial desde la pausa: se da por visto (sin recompensa) y se vuelve al menú.
func skip() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	GameState.tutorial_done = true
	_cleanup()
	if _game != null and _game.has_method("leave_tutorial"):
		_game.call("leave_tutorial", false)

func _cleanup() -> void:
	_card.visible = false
	_pointer.clear()
	_marker.visible = false

func _show_end_dialog(first: bool) -> void:
	if _game != null and _game.has_method("freeze_for_dialog"):
		_game.call("freeze_for_dialog", true)
	var layer := Control.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var avail := UIKit.canvas_size(_hud)
	var panel_w := minf(600.0, avail.x - 40.0)
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	var trophy := UIKit.icon_rect("trophy", 84)
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(trophy)
	var title := UIKit.label(Loc.t("tut.done_title"), "LabelHeader", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := UIKit.label(Loc.t("tut.done_body"), "LabelLight", 21)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(panel_w - 40.0, 0)
	v.add_child(body)
	if first:
		var reward := UIKit.chip("coin", "+%d" % REWARD_COINS, "LabelValue", 34, 28)
		reward.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(reward)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_w := minf(250.0, (panel_w - 50.0) * 0.5)
	var menu := UIKit.icon_text_button("home", Loc.t("tut.to_menu"), "ButtonSecondary", UIKit.H_BTN, btn_w, 34)
	menu.pressed.connect(func() -> void: _leave(false))
	var play := UIKit.icon_text_button("play", Loc.t("tut.play_level_1"), "ButtonSuccess", UIKit.H_BTN, btn_w, 38)
	play.pressed.connect(func() -> void: _leave(true))
	row.add_child(menu)
	row.add_child(play)
	v.add_child(row)
	_hud.add_overlay(layer)

func _leave(play: bool) -> void:
	if _game != null and _game.has_method("leave_tutorial"):
		_game.call("leave_tutorial", play)
