class_name TouchControls
extends Control
## Controles táctiles: joystick virtual (mitad izquierda), giro de cámara por deslizamiento (mitad derecha) y botón de
## interacción. Cada dedo pertenece a UN solo control desde que toca la pantalla hasta que la suelta, así que un dedo que
## empezó en un botón o en el joystick nunca se convierte en un gesto de cámara. Soporta multitáctil.

signal interact_pressed

## El lienzo de la interfaz es más pequeño que antes (1024 x 576), así que los controles táctiles se reducen en la misma
## proporción para conservar su tamaño real en pantalla.
const BASE_SCALE := 0.8
const JOY_RADIUS := 105.0
const KNOB_RADIUS := 44.0
const BTN_RADIUS := 62.0
const DEAD_ZONE := 0.12

var move_vector: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO

var _owners: Dictionary = {}       # índice de dedo -> "joy" | "look" | "btn" | "block" | "ignore"
var _joy_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_offset: Vector2 = Vector2.ZERO
var _btn_pressed: bool = false
var _enabled: bool = true
var _blockers: Array = []
var _icon: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UIKit.icon("cursor", 88.0)
	resized.connect(_on_resized)
	Events.settings_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var on := SettingsManager.use_touch_ui()
	visible = on
	set_process_input(on and _enabled)
	_joy_center = _idle_center()
	queue_redraw()

func _on_resized() -> void:
	if _joy_index == -1:
		_joy_center = _idle_center()
	queue_redraw()

func _s() -> float:
	return SettingsManager.control_scale * BASE_SCALE

func _idle_center() -> Vector2:
	return Vector2(JOY_RADIUS * _s() + 56.0, size.y - JOY_RADIUS * _s() - 48.0)

func _btn_center() -> Vector2:
	return Vector2(size.x - BTN_RADIUS * _s() - 56.0, size.y - BTN_RADIUS * _s() - 56.0)

func _btn_rect() -> Rect2:
	var r := BTN_RADIUS * _s()
	return Rect2(_btn_center() - Vector2(r, r), Vector2(r, r) * 2.0).grow(14.0)

## Registra un control de la interfaz (botón de pausa, etc.) que debe consumir los toques que empiecen sobre él.
func register_blocker(c: Control) -> void:
	_blockers.append(c)

func set_enabled(v: bool) -> void:
	_enabled = v
	set_process_input(v and visible)
	if not v:
		cancel_all()

func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d

func cancel_all() -> void:
	_owners.clear()
	_joy_index = -1
	_joy_offset = Vector2.ZERO
	_btn_pressed = false
	move_vector = Vector2.ZERO
	look_delta = Vector2.ZERO
	_joy_center = _idle_center()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		cancel_all()

# ------------------------------------------------------------------ entrada
func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_drag(d.index, d.position, d.relative)

func _hits_blocker(pos: Vector2) -> bool:
	for c in _blockers:
		var ctl := c as Control
		if ctl != null and is_instance_valid(ctl) and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
			return true
	return false

func _on_press(index: int, pos: Vector2) -> void:
	if _owners.has(index):
		return
	if _hits_blocker(pos):
		_owners[index] = "block"
		return
	if _btn_rect().has_point(pos):
		_owners[index] = "btn"
		_btn_pressed = true
		queue_redraw()
		interact_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if pos.x < size.x * 0.5:
		if _joy_index == -1 and pos.y > size.y * 0.3:
			_start_joystick(index, pos)
			get_viewport().set_input_as_handled()
		else:
			_owners[index] = "ignore"
	else:
		_owners[index] = "look"
		get_viewport().set_input_as_handled()

func _on_release(index: int) -> void:
	if not _owners.has(index):
		return
	var o: String = _owners[index]
	_owners.erase(index)
	if o == "joy":
		_joy_index = -1
		_joy_offset = Vector2.ZERO
		move_vector = Vector2.ZERO
		_joy_center = _idle_center()
		queue_redraw()
	elif o == "btn":
		_btn_pressed = false
		queue_redraw()
	if o != "block":
		get_viewport().set_input_as_handled()

func _on_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if not _owners.has(index):
		return
	var o: String = _owners[index]
	if o == "joy":
		_update_joystick(pos)
		get_viewport().set_input_as_handled()
	elif o == "look":
		look_delta += rel
		get_viewport().set_input_as_handled()

func _start_joystick(index: int, pos: Vector2) -> void:
	var r := JOY_RADIUS * _s()
	_joy_center = Vector2(clampf(pos.x, r + 20.0, size.x * 0.5 - r), clampf(pos.y, size.y * 0.3 + r, size.y - r - 20.0))
	_joy_index = index
	_owners[index] = "joy"
	_update_joystick(pos)

func _update_joystick(pos: Vector2) -> void:
	var r := JOY_RADIUS * _s()
	var off := pos - _joy_center
	if off.length() > r:
		off = off.normalized() * r
	_joy_offset = off
	var v := off / r
	var dist := v.length()
	if dist < DEAD_ZONE:
		move_vector = Vector2.ZERO
	else:
		move_vector = v.normalized() * ((dist - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	queue_redraw()

# ------------------------------------------------------------------ dibujo
func _draw() -> void:
	var s := _s()
	var active := _joy_index != -1
	var base_c := _joy_center if active else _idle_center()
	var a := 0.55 if active else 0.3
	draw_circle(base_c, JOY_RADIUS * s, Color(Palette.BROWN, 0.32))
	draw_arc(base_c, JOY_RADIUS * s, 0.0, TAU, 48, Color(Palette.CREAM, a + 0.2), 4.0, true)
	var knob := base_c + _joy_offset
	draw_circle(knob, KNOB_RADIUS * s, Color(Palette.MUSTARD, 0.9 if active else 0.55))
	draw_arc(knob, KNOB_RADIUS * s, 0.0, TAU, 32, Color(Palette.BROWN, 0.9), 4.0, true)
	var bc := _btn_center()
	var br := BTN_RADIUS * s * (0.92 if _btn_pressed else 1.0)
	draw_circle(bc + Vector2(0, 4), br, Color(0, 0, 0, 0.3))
	draw_circle(bc, br, Palette.MUSTARD.darkened(0.12) if _btn_pressed else Palette.MUSTARD)
	draw_arc(bc, br, 0.0, TAU, 40, Palette.BROWN, 5.0, true)
	if _icon != null:
		var isz := br * 1.15
		draw_texture_rect(_icon, Rect2(bc - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
