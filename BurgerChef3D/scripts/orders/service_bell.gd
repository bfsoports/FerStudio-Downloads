class_name ServiceBell
extends Interactable
## Campana del puesto: al pulsarla se entrega lo que hay en la bandeja al cliente.

var point: ServicePoint = null
var _dome: Node3D = null

func get_prompt(_player: Node) -> Dictionary:
	if point == null or point.order == null or not point.open:
		return {"icon": "blocked", "text": "prompt.no_customer", "ok": false}
	if not point.has_tray:
		return {"icon": "blocked", "text": "reject.no_tray", "ok": false}
	return {"icon": "tray", "text": "prompt.deliver"}

func interact(_player: Node) -> void:
	if point == null:
		return
	if _dome != null:
		_dome.scale = Vector3(1.0, 0.6, 1.0)
		create_tween().tween_property(_dome, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if point.order == null:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("prompt.no_customer"), "warn")
		return
	if not point.has_tray:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("reject.no_tray"), "warn")
		return
	point.try_deliver()

func set_dome(node: Node3D) -> void:
	_dome = node
