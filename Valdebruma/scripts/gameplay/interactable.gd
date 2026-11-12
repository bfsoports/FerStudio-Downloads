class_name Interactable
extends Node3D
## Interactable — base de todo objeto con el que se interactúa en el mundo.
##
## Responsabilidad: registrarse en WorldRoot para que la sonda del jugador lo encuentre por
## distancia, ángulo, visibilidad y prioridad; ofrecer el texto contextual y enviar la
## PETICIÓN al servidor (nunca cambia el estado por su cuenta: espera el evento del servidor).
## Señales: ninguna. Datos: kind/oid identifican el objeto en el protocolo.

static var _overlay: ShaderMaterial = null

var kind := 0
var oid := 0
var reach := Protocol.REACH
var priority := 0
var focus := Vector3(0, 0.3, 0)
var _lit := false

func _enter_tree() -> void:
	WorldRoot.interactables.append(self)

func _exit_tree() -> void:
	WorldRoot.interactables.erase(self)

func focus_point() -> Vector3:
	return global_transform * focus

func available() -> bool:
	return true

## Texto de la acción principal ("Abrir puerta"). Vacío = no se ofrece.
func prompt() -> String:
	return ""

## Acción secundaria opcional ("Desmontar", "Llenar botella").
func prompt2() -> String:
	return ""

func interact() -> void:
	Session.request_interact(kind, oid)

func interact2() -> void:
	pass

func set_highlight(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = load("res://assets/shaders/highlight.gdshader")
	_apply_overlay(self, _overlay if on else null)

func _apply_overlay(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		if not (c is Interactable):
			_apply_overlay(c, mat)
