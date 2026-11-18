class_name TouchControls
extends CanvasLayer
## Android touch scheme:
##   left side  -> floating virtual joystick (movement only, push to edge = sprint)
##   right side -> camera drag area (excluding buttons)
##   buttons    -> fire (hold), aim (toggle), reload, jump, interact (hold to
##                 confirm purchases), switch weapon, grenade, pause.
## All fingers are routed here by index so simultaneous touches never interfere;
## a finger that starts on a button never rotates the camera.

signal pause_pressed

const JOY_RADIUS := 95.0
const LOOK_GAIN := 1.9
const HOLD_TO_BUY := 0.35

var player: Player
var enabled := true

var _root: Control
var _joy_base: Control
var _joy_knob: Control
var _buttons := {}           # role -> TouchButton
var _touch_role := {}        # finger index -> role
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_index := -1
var _interact_hold := 0.0
var _interact_done := false
var _interact_continuous := false


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_joystick()
	_add_button("fire", "fire", 78, Vector2(-150, -170), UIStyle.DANGER)
	_add_button("aim", "aim", 50, Vector2(-310, -110), UIStyle.TEXT)
	_add_button("reload", "reload", 44, Vector2(-120, -345), UIStyle.TEXT)
	_add_button("jump", "jump", 46, Vector2(-290, -250), UIStyle.TEXT)
	_add_button("grenade", "grenade", 42, Vector2(-410, -175), UIStyle.TEXT)
	_add_button("interact", "interact", 58, Vector2(-330, -400), UIStyle.ACCENT)
	_add_button("switch", "switch", 40, Vector2(-200, -430), UIStyle.TEXT)
	_add_button("pause", "pause", 30, Vector2(-60, 0), UIStyle.TEXT, true)
	_buttons["interact"].visible = false
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func bind(p: Player) -> void:
	player = p
	p.interact_target_changed.connect(_on_target_changed)
	p.grenades_changed.connect(func(n): _buttons["grenade"].badge_text = str(n); _buttons["grenade"].queue_redraw())
	_buttons["grenade"].badge_text = str(p.grenades)


func _build_joystick() -> void:
	_joy_base = Control.new()
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.draw.connect(func():
		var a := Settings.controls_opacity
		_joy_base.draw_circle(Vector2.ZERO, JOY_RADIUS, Color(0.05, 0.06, 0.05, 0.35 * a + 0.1))
		_joy_base.draw_arc(Vector2.ZERO, JOY_RADIUS, 0, TAU, 64, Color(0.94, 0.92, 0.86, 0.35 * a + 0.2), 3.0, true)
		_joy_base.draw_arc(Vector2.ZERO, JOY_RADIUS * 0.92, -PI * 0.5 - 0.5, -PI * 0.5 + 0.5, 16, Color(UIStyle.ACCENT, 0.5), 5.0, true))
	_root.add_child(_joy_base)
	_joy_knob = Control.new()
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.draw.connect(func():
		_joy_knob.draw_circle(Vector2.ZERO, 40, Color(0.94, 0.92, 0.86, 0.35 * Settings.controls_opacity + 0.3))
		_joy_knob.draw_circle(Vector2.ZERO, 30, Color(0.1, 0.11, 0.1, 0.5)))
	_root.add_child(_joy_knob)
	_reset_joystick()


func _default_joy_pos() -> Vector2:
	var vs := _root.get_viewport_rect().size
	return Vector2(210, vs.y - 190)


func _reset_joystick() -> void:
	_joy_origin = _default_joy_pos()
	_joy_base.position = _joy_origin
	_joy_knob.position = _joy_origin
	_joy_vec = Vector2.ZERO


func _add_button(role: String, icon: String, radius: float, offset: Vector2, accent: Color, top: bool = false) -> void:
	var b := TouchButton.new()
	b.icon_name = icon
	b.radius = radius
	b.accent = accent
	b.name = "Btn_" + role
	_root.add_child(b)
	# anchor to bottom-right (or top-right) corner so layout adapts to any aspect ratio
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = b.anchor_top
	b.set_meta("offset", offset)
	b.set_meta("top", top)
	_buttons[role] = b


func _apply_settings() -> void:
	var s := Settings.controls_scale
	for role in _buttons:
		var b: TouchButton = _buttons[role]
		var off: Vector2 = b.get_meta("offset") * s
		var r := b.radius
		if b.get_meta("top"):
			off.y = 18 + r * s
		b.offset_left = off.x - r
		b.offset_top = off.y - r
		b.offset_right = off.x + r
		b.offset_bottom = off.y + r
		b.scale = Vector2.ONE * s
		b.pivot_offset = Vector2(r, r)
		b.queue_redraw()
	_joy_base.scale = Vector2.ONE * s
	_joy_knob.scale = Vector2.ONE * s
	_joy_base.queue_redraw()


func _on_target_changed(t: Interactable) -> void:
	var b: TouchButton = _buttons["interact"]
	b.visible = t != null
	if t == null:
		_cancel_interact()


func set_enabled(v: bool) -> void:
	enabled = v
	_root.visible = v
	if not v:
		_release_all()


func _release_all() -> void:
	for idx in _touch_role.keys():
		_release(idx)
	_touch_role.clear()
	_joy_index = -1
	_look_index = -1
	_reset_joystick()


# ------------------------------------------------------------------------------
# input routing
# ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()


func _press(index: int, pos: Vector2) -> void:
	for role in _buttons:
		var b: TouchButton = _buttons[role]
		if b.hit(pos):
			_touch_role[index] = role
			b.pressed = true
			_button_down(role)
			return
	var vs := _root.get_viewport_rect().size
	if pos.x < vs.x * 0.42 and _joy_index == -1:
		_joy_index = index
		_touch_role[index] = "move"
		_joy_origin = pos
		_joy_base.position = pos
		_joy_knob.position = pos
		_joy_vec = Vector2.ZERO
	elif _look_index == -1:
		_look_index = index
		_touch_role[index] = "look"


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var role: String = _touch_role.get(index, "")
	match role:
		"move":
			var d := pos - _joy_origin
			var r := JOY_RADIUS * Settings.controls_scale
			if d.length() > r:
				d = d.normalized() * r
			_joy_knob.position = _joy_origin + d
			_joy_vec = d / r
		"look":
			player.look_input += rel * LOOK_GAIN


func _release(index: int) -> void:
	var role: String = _touch_role.get(index, "")
	_touch_role.erase(index)
	match role:
		"move":
			_joy_index = -1
			_reset_joystick()
		"look":
			_look_index = -1
		"":
			pass
		_:
			var b: TouchButton = _buttons.get(role)
			if b:
				b.pressed = false
			_button_up(role)


func _button_down(role: String) -> void:
	match role:
		"fire":
			player.fire_held = true
		"aim":
			player.weapons.toggle_aim()
		"reload":
			player.weapons.reload()
		"jump":
			player.jump()
		"grenade":
			player.throw_grenade()
		"switch":
			player.weapons.switch_next()
		"pause":
			pause_pressed.emit()
		"interact":
			_interact_done = false
			var t := player.current_target
			_interact_continuous = t != null and t.continuous
			if _interact_continuous:
				player.interact_hold(true)
			elif not Settings.hold_to_buy or (t and t.get_prompt(player).get("price", 0) == 0):
				player.interact()
				_interact_done = true
			else:
				_interact_hold = 0.0001


func _button_up(role: String) -> void:
	match role:
		"fire":
			player.fire_held = false
		"interact":
			_cancel_interact()


func _cancel_interact() -> void:
	if _interact_continuous and player:
		player.interact_hold(false)
	_interact_continuous = false
	_interact_hold = 0.0
	(_buttons["interact"] as TouchButton).progress = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	_joy_base.queue_redraw()
	player.move_input = Vector2(_joy_vec.x, _joy_vec.y)
	player.wants_sprint = _joy_vec.length() > 0.93 and _joy_vec.y < -0.75
	if _interact_hold > 0.0 and not _interact_done:
		_interact_hold += delta
		var b: TouchButton = _buttons["interact"]
		b.progress = clampf(_interact_hold / HOLD_TO_BUY, 0.0, 1.0)
		if _interact_hold >= HOLD_TO_BUY:
			_interact_done = true
			_interact_hold = 0.0
			b.progress = 0.0
			player.interact()
	# aim button reflects state
	(_buttons["aim"] as TouchButton).pressed = player.weapons.aiming or _touch_role.values().has("aim")


func interact_progress() -> float:
	return clampf(_interact_hold / HOLD_TO_BUY, 0.0, 1.0) if _interact_hold > 0.0 else 0.0
