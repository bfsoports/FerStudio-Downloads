class_name PerfGovernor
extends Node
## Dynamic resolution: keeps the frame rate near the target on phones by
## adjusting Viewport.scaling_3d_scale within the profile's limits.
## UI stays at native resolution (only the 3D view is scaled).

const SAMPLE_TIME := 2.0

var min_scale := 0.55
var max_scale := 1.0
var _acc := 0.0
var _frames := 0
var _scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	match Settings.quality:
		Settings.Quality.LOW:
			min_scale = 0.5
			max_scale = 0.75
		Settings.Quality.MEDIUM:
			min_scale = 0.6
			max_scale = 0.9
		_:
			min_scale = 0.7
			max_scale = 1.0
	_scale = get_viewport().scaling_3d_scale


func _process(delta: float) -> void:
	_acc += delta
	_frames += 1
	if _acc < SAMPLE_TIME:
		return
	var fps := _frames / _acc
	_acc = 0.0
	_frames = 0
	var target := float(Settings.fps_limit)
	if fps < target * 0.88:
		_scale = maxf(min_scale, _scale - 0.05)
	elif fps > target * 0.97:
		_scale = minf(max_scale, _scale + 0.025)
	get_viewport().scaling_3d_scale = _scale


func current_scale() -> float:
	return _scale
