extends Control
## TouchControls — controles táctiles del juego (Android).
##
## Responsabilidad: joystick flotante en la mitad de movimiento, giro de cámara arrastrando
## en el resto de la pantalla y botones de acción y de menú. Todo el tacto se gestiona aquí
## por índice de dedo (multitáctil real): mover, mirar y pulsar a la vez sin interferencias.
## Escribe en Controls (touch_move, look, touch_sprint, press). Respeta zonas seguras, escala,
## opacidad y modo zurdo de los ajustes. No decide nada de juego.

const LOOK_SPEED := 0.26
const STICK_RADIUS := 78.0

class Btn:
	var id := ""
	var node: PanelContainer
	var icon: TextureRect
	var radius := 36.0
	var held := false
	var finger := -1
	var toggle := false
	var on := false
	var hold_ms := 0

var buttons: Dictionary = {}       # id -> Btn
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _look_finger := -1
var _ring: Panel
var _knob: Panel
var _safe := Rect2()
var _scale := 1.0
var _left := false
var _interact_hint := false
var _secondary := false

func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.07), 200, Color(1, 1, 1, 0.35), 2))
	add_child(_ring)
	_knob = Panel.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.3), 200, Color(1, 1, 1, 0.6), 2))
	add_child(_knob)
	for def: Array in [["interact", "interact", 46.0], ["interact2", "interact2", 34.0], ["jump", "jump", 38.0], ["crouch", "crouch", 34.0],
			["sprint", "sprint", 34.0], ["light", "light", 30.0], ["inventory", "inventory", 30.0], ["craft", "craft", 30.0], ["build", "build", 30.0],
			["map", "map", 30.0], ["journal", "journal", 30.0], ["group", "group", 30.0], ["chat", "chat", 30.0], ["pause", "menu", 30.0],
			["rotate", "rotate", 34.0], ["cancel", "close", 34.0]]:
		_add(String(def[0]), String(def[1]), float(def[2]))
	(buttons["sprint"] as Btn).toggle = true
	Config.changed.connect(func(_s: String, _k: String) -> void: layout())
	get_viewport().size_changed.connect(layout)
	layout()

func _add(id: String, icon_name: String, radius: float) -> void:
	var b := Btn.new()
	b.id = id
	b.radius = radius
	b.node = PanelContainer.new()
	b.node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.icon = UiKit.icon_rect(icon_name, radius, Color.WHITE)
	b.node.add_child(b.icon)
	add_child(b.node)
	buttons[id] = b
	_style(b)

func _style(b: Btn) -> void:
	var lit := b.held or b.on
	var accent := b.id == "interact" and _interact_hint
	var bg := Color(UiKit.C_ACCENT, 0.85) if lit else (Color(UiKit.C_ACCENT, 0.28) if accent else Color(0.03, 0.06, 0.05, 0.5))
	var edge := UiKit.C_ACCENT if (lit or accent) else Color(1, 1, 1, 0.38)
	b.node.add_theme_stylebox_override("panel", UiKit.box(bg, 200, edge, 2, 0))
	b.icon.modulate = UiKit.C_BG if lit else Color(1, 1, 1, 0.95)

## Coloca botones y joystick según tamaño de pantalla, zona segura, escala y mano dominante.
func layout() -> void:
	_safe = Ui.safe_margins()
	_scale = Config.f("control", "touch_scale")
	_left = Config.b("control", "left_handed")
	modulate.a = Config.f("control", "touch_opacity")
	var vp := get_viewport_rect().size
	var r := vp.x - _safe.size.x - 22.0        # borde derecho útil
	var l := _safe.position.x + 22.0
	var bot := vp.y - _safe.size.y - 20.0
	var top := _safe.position.y + 14.0
	var s := _scale
	# racimo de acción (esquina inferior del lado contrario al joystick)
	var pos := {
		"interact": Vector2(r - 66.0 * s, bot - 150.0 * s), "interact2": Vector2(r - 178.0 * s, bot - 190.0 * s), "jump": Vector2(r - 58.0 * s, bot - 46.0 * s),
		"crouch": Vector2(r - 166.0 * s, bot - 84.0 * s), "sprint": Vector2(r - 58.0 * s, bot - 262.0 * s), "light": Vector2(r - 152.0 * s, bot - 286.0 * s),
		"rotate": Vector2(r - 178.0 * s, bot - 190.0 * s), "cancel": Vector2(r - 152.0 * s, bot - 286.0 * s),
	}
	# barra de menús arriba a la derecha
	var x := r - 30.0 * s
	for id: String in ["pause", "map", "journal", "group", "build", "craft", "inventory", "chat"]:
		pos[id] = Vector2(x, top + 30.0 * s)
		x -= 70.0 * s
	for id: String in buttons.keys():
		var b: Btn = buttons[id]
		var p: Vector2 = pos[id]
		if _left and not (id in ["pause", "map", "journal", "group", "build", "craft", "inventory", "chat"]):
			p.x = vp.x - p.x
		var rad := b.radius * s
		b.node.position = p - Vector2(rad, rad)
		b.node.size = Vector2(rad, rad) * 2.0
		b.node.custom_minimum_size = b.node.size
		b.icon.custom_minimum_size = Vector2(rad, rad)
		b.icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ring.size = Vector2(STICK_RADIUS, STICK_RADIUS) * 2.0 * s
	_knob.size = Vector2(54, 54) * s
	_rest_stick()
	set_mode(false, false)

func _rest_stick() -> void:
	var vp := get_viewport_rect().size
	var c := Vector2(_safe.position.x + 150.0 * _scale, vp.y - _safe.size.y - 140.0 * _scale)
	if _left:
		c.x = vp.x - c.x
	_ring.position = c - _ring.size * 0.5
	_knob.position = c - _knob.size * 0.5
	_ring.modulate.a = 0.55
	_knob.modulate.a = 0.55

## Modo de construcción: cambia secundaria/linterna por girar/cancelar.
func set_mode(building: bool, has_light: bool) -> void:
	(buttons["rotate"] as Btn).node.visible = building
	(buttons["cancel"] as Btn).node.visible = building
	(buttons["interact2"] as Btn).node.visible = not building and _secondary
	(buttons["light"] as Btn).node.visible = not building and has_light

func set_target(has_target: bool, has_secondary: bool) -> void:
	if has_target == _interact_hint and has_secondary == _secondary:
		return
	_interact_hint = has_target
	_secondary = has_secondary
	_style(buttons["interact"])
	(buttons["interact2"] as Btn).node.visible = has_secondary and not (buttons["rotate"] as Btn).node.visible

func release_all() -> void:
	_stick_finger = -1
	_look_finger = -1
	Controls.touch_move = Vector2.ZERO
	for id: String in buttons.keys():
		var b: Btn = buttons[id]
		if b.held:
			b.held = false
			b.finger = -1
			_style(b)
	_rest_stick()

func _move_side(p: Vector2) -> bool:
	var vp := get_viewport_rect().size
	var in_half := p.x > vp.x * 0.55 if _left else p.x < vp.x * 0.45
	return in_half and p.y > vp.y * 0.28

func _hit(p: Vector2) -> Btn:
	var best: Btn = null
	var best_d := 1e9
	for id: String in buttons.keys():
		var b: Btn = buttons[id]
		if not b.node.visible:
			continue
		var c := b.node.position + b.node.size * 0.5
		var d := p.distance_to(c)
		if d < b.node.size.x * 0.5 + 10.0 and d < best_d:
			best = b
			best_d = d
	return best

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if Controls.blocked:
		if _stick_finger >= 0 or _look_finger >= 0:
			release_all()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_down(t.index, t.position)
		else:
			_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_drag_stick(d.position)
		elif d.index == _look_finger:
			Controls.look += d.relative * LOOK_SPEED

func _down(index: int, p: Vector2) -> void:
	var b := _hit(p)
	if b != null:
		b.finger = index
		b.held = true
		b.hold_ms = Time.get_ticks_msec()
		if b.toggle:
			b.on = not b.on
			Controls.touch_sprint = b.on
		elif not (b.id == "interact" and Config.b("access", "hold_to_interact")):
			_fire(b)
		_style(b)
		return
	if _move_side(p) and _stick_finger < 0:
		_stick_finger = index
		_stick_origin = p
		_ring.position = p - _ring.size * 0.5
		_knob.position = p - _knob.size * 0.5
		_ring.modulate.a = 1.0
		_knob.modulate.a = 1.0
		return
	if _look_finger < 0:
		_look_finger = index

func _up(index: int) -> void:
	if index == _stick_finger:
		_stick_finger = -1
		Controls.touch_move = Vector2.ZERO
		_rest_stick()
	elif index == _look_finger:
		_look_finger = -1
	for id: String in buttons.keys():
		var b: Btn = buttons[id]
		if b.finger == index:
			b.finger = -1
			b.held = false
			_style(b)

func _process(_delta: float) -> void:
	# «mantener para interactuar»: se dispara al sostener el botón 0,35 s
	var b: Btn = buttons["interact"]
	if b.held and Config.b("access", "hold_to_interact") and b.hold_ms > 0 and Time.get_ticks_msec() - b.hold_ms > 350:
		b.hold_ms = 0
		_fire(b)
	var sprint: Btn = buttons["sprint"]
	if sprint.on and Controls.touch_move.length() < 0.1 and _stick_finger < 0:
		sprint.on = false
		Controls.touch_sprint = false
		_style(sprint)

func _fire(b: Btn) -> void:
	AudioDirector.play_ui("ui_click", -10.0)
	match b.id:
		"cancel": Controls.press("pause")
		_: Controls.press(b.id)

func _drag_stick(p: Vector2) -> void:
	var v := (p - _stick_origin) / (STICK_RADIUS * _scale)
	if v.length() > 1.0:
		v = v.normalized()
	_knob.position = _stick_origin + v * STICK_RADIUS * _scale - _knob.size * 0.5
	var dead := 0.14
	var m := v.length()
	var out := Vector2.ZERO if m < dead else v.normalized() * ((m - dead) / (1.0 - dead))
	Controls.touch_move = Vector2(out.x, -out.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_node_ready():
			release_all()
