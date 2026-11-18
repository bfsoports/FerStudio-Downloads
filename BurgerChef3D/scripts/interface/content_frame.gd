class_name ContentFrame
extends Container
## Contenedor que limita el ancho de su contenido: lo centra y nunca lo estira más de max_width.
## En pantallas muy anchas (móviles 20:9) la interfaz queda recogida en el centro en vez de estirarse hacia los lados.

@export var max_width: float = 1280.0:
	set(value):
		max_width = value
		queue_sort()

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var w := minf(size.x, max_width)
	for c in get_children():
		var ctrl := c as Control
		if ctrl != null and ctrl.visible:
			fit_child_in_rect(ctrl, Rect2((size.x - w) * 0.5, 0.0, w, size.y))
