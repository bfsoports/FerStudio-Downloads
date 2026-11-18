extends Node
## Vibración del móvil (respuesta háptica) en las acciones importantes: coger y colocar, cerrar una hamburguesa,
## entregar un pedido, avisos de error, comida quemada y pedidos caducados. Escucha el bus de eventos, así que ningún
## sistema necesita llamarla. Se desactiva en Ajustes > Controles > Vibración (SettingsManager.vibration).
## Solo funciona en Android/iOS (Input.vibrate_handheld); en escritorio no hace nada. Requiere el permiso VIBRATE
## (export_presets.cfg: permissions/vibrate=true).

const MIN_GAP_MS := 60   # dos vibraciones seguidas más juntas que esto se agrupan en una

## Duración (ms) de cada tipo de vibración.
const PULSES: Dictionary = {"pick": 12, "place": 10, "burger": 30, "deliver": 45, "warn": 35, "burnt": 110, "expired": 150, "wash": 25}

var _last_ms := -100000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.item_picked.connect(func(_id: String) -> void: pulse("pick"))
	Events.item_placed.connect(func(_id: String, _kind: String) -> void: pulse("place"))
	Events.burger_closed.connect(func(_layers: Array) -> void: pulse("burger"))
	Events.item_burnt.connect(func(_id: String) -> void: pulse("burnt"))
	Events.tray_washed.connect(func() -> void: pulse("wash"))
	Events.order_closed.connect(_on_order_closed)
	Events.toast.connect(_on_toast)

func is_supported() -> bool:
	return OS.has_feature("mobile")

func pulse(kind: String) -> void:
	if not SettingsManager.vibration or not is_supported():
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	Input.vibrate_handheld(int(PULSES.get(kind, 15)))

func _on_order_closed(_order: RefCounted, outcome: String) -> void:
	match outcome:
		"ok":
			pulse("deliver")
		"expired":
			pulse("expired")
		_:
			pulse("warn")

func _on_toast(_text: String, kind: String) -> void:
	if kind == "warn":
		pulse("warn")
