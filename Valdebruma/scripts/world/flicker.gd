extends Node3D
## Parpadeo de la luz de una hoguera (variación suave de energía y posición).

var _t := 0.0
var _light: OmniLight3D

func _ready() -> void:
	for c in get_children():
		if c is OmniLight3D:
			_light = c
	_t = randf() * 10.0

func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	_light.light_energy = 2.0 + 0.45 * sin(_t * 9.0) * sin(_t * 3.7) + 0.25 * sin(_t * 23.0)
	_light.position.x = 0.05 * sin(_t * 7.0)
