class_name Interactable
extends StaticBody3D
## Contrato de interacción: cualquier objeto con el que el jugador puede interactuar.
## get_prompt() describe qué se mostrará en el indicador central y interact() ejecuta la acción.
## El diccionario del indicador usa: icon (grab/drop/use/tray/trash/blocked/lock), text (clave de traducción),
## args (opcional, argumentos de formato) y ok (false = acción no disponible).

var _layer_value: int = Const.LAYER_INTERACT

func _init() -> void:
	collision_layer = Const.LAYER_INTERACT
	collision_mask = 0

## Los muebles también bloquean el paso del jugador (capa del mundo); los objetos pequeños no.
func set_blocking(block: bool) -> void:
	_layer_value = Const.LAYER_INTERACT | (Const.LAYER_WORLD if block else 0)
	collision_layer = _layer_value

## Un objeto transportado se vuelve no detectable para que el rayo de interacción no lo golpee.
func set_pickable(on: bool) -> void:
	collision_layer = _layer_value if on else 0

func add_box_collider(size: Vector3, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	add_child(cs)
	return cs

func get_prompt(_player: Node) -> Dictionary:
	return {}

func interact(_player: Node) -> void:
	pass
