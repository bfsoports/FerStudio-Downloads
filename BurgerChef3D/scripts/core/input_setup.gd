class_name InputSetup
extends RefCounted
## Registra por código las acciones de entrada de escritorio (WASD, E, R, Esc). Se llama una vez al arrancar.

static func ensure() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("interact", [KEY_E, KEY_F])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_keys("recipes", [KEY_R, KEY_TAB])

static func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
