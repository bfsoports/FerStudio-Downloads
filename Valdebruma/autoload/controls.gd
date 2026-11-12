extends Node
## Controls — estado de entrada unificado (autoload).
##
## Responsabilidad: reunir en un solo sitio lo que piden teclado/ratón (pruebas en PC) y los
## controles táctiles (Android): vector de movimiento, giro acumulado de cámara y pulsaciones.
## El jugador solo lee de aquí, de modo que joystick, zona de cámara y botones no se pisan.
## 'blocked' anula el movimiento mientras hay un menú abierto. Señales: pressed(action).

signal pressed(action: String)

var move := Vector2.ZERO          # x derecha, y adelante (−1..1)
var look := Vector2.ZERO          # giro pendiente en grados (se consume cada fotograma)
var sprint := false
var crouch := false
var blocked := false
var touch_move := Vector2.ZERO
var touch_sprint := false
var mouse_captured := false
var _keys := {"jump": KEY_SPACE, "interact": KEY_E, "interact2": KEY_F, "inventory": KEY_TAB, "map": KEY_M, "light": KEY_L, "craft": KEY_C, "build": KEY_B,
	"pause": KEY_ESCAPE, "journal": KEY_J, "group": KEY_G, "quick1": KEY_1, "quick2": KEY_2, "quick3": KEY_3, "quick4": KEY_4, "chat": KEY_ENTER, "rotate": KEY_R}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func capture_mouse(on: bool) -> void:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return
	mouse_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func press(action: String) -> void:
	pressed.emit(action)

func consume_look() -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured and not blocked:
		look += (event as InputEventMouseMotion).relative * 0.12
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var code := (event as InputEventKey).physical_keycode
		if code == KEY_CTRL:
			crouch = not crouch
		for action: String in _keys.keys():
			if _keys[action] == code:
				press(action)

func _process(_delta: float) -> void:
	var kb := Vector2.ZERO
	if not blocked:
		kb.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		kb.y = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	move = (kb + touch_move).limit_length(1.0) if not blocked else Vector2.ZERO
	sprint = (Input.is_physical_key_pressed(KEY_SHIFT) or touch_sprint or (Config.b("control", "auto_sprint") and touch_move.length() > 0.92)) and not blocked

func _notification(what: int) -> void:
	# al perder el foco o suspenderse Android se sueltan todas las entradas
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		touch_move = Vector2.ZERO
		touch_sprint = false
		look = Vector2.ZERO
		move = Vector2.ZERO
