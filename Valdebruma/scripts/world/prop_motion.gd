extends Node3D
## Movimiento ambiental de objetos del mundo: rotor del molino de viento (gira con el viento)
## y asiento del columpio (se mece). Solo se procesa cuando el objeto está cargado.

var _spin: Node3D
var _sway: Node3D
var _t := 0.0

func setup(spin_name: String, sway_name: String) -> void:
	if spin_name != "":
		_spin = find_child(spin_name, true, false)
	if sway_name != "":
		_sway = find_child(sway_name, true, false)
	_t = randf() * 10.0

func _process(delta: float) -> void:
	var wind := float(Session.env.get("wind", 0.3))
	_t += delta
	if _spin != null:
		_spin.rotate_object_local(Vector3(0, 0, 1), delta * (0.4 + 3.2 * wind))
	if _sway != null:
		_sway.rotation.x = 0.16 * (0.3 + wind) * sin(_t * 1.6)
