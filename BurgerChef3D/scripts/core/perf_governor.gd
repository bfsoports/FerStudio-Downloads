class_name PerfGovernor
extends Node
## Vigila los FPS durante la partida y, si el móvil no llega a ir fluido, baja la calidad por escalones hasta
## recuperar los fotogramas (primero el antialiasing, luego la resolución interna 3D y por último las sombras).
## Nunca toca la interfaz ni las mecánicas, y solo baja: así no oscila entre calidades.

const TARGET_FPS := 40.0     # por debajo de esto (media de unos segundos) se baja un escalón
const GRACE := 4.0           # segundos de margen al empezar (carga de modelos, primeros clientes)
const WINDOW := 4            # muestras de 1 s que se promedian
const MAX_STEP := 3

var _t := 0.0
var _samples: Array = []

func _ready() -> void:
	SettingsManager.perf_step = 0
	SettingsManager.apply_graphics()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	if _t < 1.0 + GRACE:
		return
	_t = GRACE
	_samples.append(Engine.get_frames_per_second())
	if _samples.size() > WINDOW:
		_samples.pop_front()
	if _samples.size() < WINDOW or SettingsManager.perf_step >= MAX_STEP:
		return
	var avg := 0.0
	for f in _samples:
		avg += float(f)
	avg /= float(_samples.size())
	if avg < TARGET_FPS:
		SettingsManager.perf_step += 1
		SettingsManager.apply_graphics()
		_samples.clear()
		print("PerfGovernor: %.0f FPS -> escalón de ahorro %d" % [avg, SettingsManager.perf_step])
