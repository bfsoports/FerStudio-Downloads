class_name TutorialPointer
extends Control
## Indicador 2D del tutorial: cuando el objetivo (un punto 3D) está fuera de la pantalla o detrás de la cámara, dibuja
## una flecha amarilla en el borde que apunta hacia él; cuando se ve, dibuja un anillo que late a su alrededor (la
## flecha 3D del tutorial ya lo señala desde arriba). También puede señalar un botón de la interfaz (target_control).

const EDGE := 64.0          # distancia de la flecha al borde de la pantalla
const ARROW := 30.0         # tamaño de la flecha
const COLOR := Color(1.0, 0.82, 0.22)
const OUTLINE := Color(0.23, 0.13, 0.09)

var target_world: Vector3 = Vector3.INF
var target_control: Control = null
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func point_at_world(p: Vector3) -> void:
	target_world = p
	target_control = null

func point_at_control(c: Control) -> void:
	target_control = c
	target_world = Vector3.INF

func clear() -> void:
	target_world = Vector3.INF
	target_control = null
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if target_control != null and is_instance_valid(target_control) and target_control.is_visible_in_tree():
		_draw_control_hint(target_control)
		return
	if not target_world.is_finite():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var behind := cam.is_position_behind(target_world)
	var sp := cam.unproject_position(target_world)
	# unproject_position devuelve coordenadas del rectángulo visible del viewport; se ajustan por si este control no
	# ocupa exactamente todo el lienzo
	var k := size.x / maxf(1.0, float(get_viewport().get_visible_rect().size.x))
	sp *= k
	var inner := rect.grow(-EDGE)
	if not behind and inner.has_point(sp):
		var r := 34.0 + 6.0 * sin(_t * 6.0)
		draw_arc(sp, r, 0.0, TAU, 40, OUTLINE, 7.0, true)
		draw_arc(sp, r, 0.0, TAU, 40, COLOR, 4.0, true)
		return
	# fuera de la pantalla: flecha en el borde en la dirección del objetivo
	var center := rect.size * 0.5
	var dir := sp - center
	if behind:
		dir = -dir
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var half := inner.size * 0.5
	var t := minf(absf(half.x / dir.x) if absf(dir.x) > 0.0001 else INF, absf(half.y / dir.y) if absf(dir.y) > 0.0001 else INF)
	var tip := center + dir * t + dir * (4.0 * sin(_t * 7.0))
	_arrow(tip, dir)

func _arrow(tip: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var base := tip - dir * ARROW * 1.4
	var pts := PackedVector2Array([tip, base + side * ARROW * 0.8, base - side * ARROW * 0.8])
	var grow := PackedVector2Array([tip + dir * 5.0, base + side * (ARROW * 0.8 + 5.0) - dir * 3.0, base - side * (ARROW * 0.8 + 5.0) - dir * 3.0])
	draw_colored_polygon(grow, OUTLINE)
	draw_colored_polygon(pts, COLOR)

## Señala un botón de la interfaz con una flecha que rebota a su izquierda.
func _draw_control_hint(c: Control) -> void:
	var r := c.get_global_rect()
	var to_local := get_global_transform().affine_inverse()
	var mid: Vector2 = to_local * (r.position + Vector2(0.0, r.size.y * 0.5))
	var tip := mid - Vector2(10.0 + 6.0 * sin(_t * 7.0), 0.0)
	_arrow(tip, Vector2.RIGHT)
	var rr := Rect2(to_local * r.position, r.size).grow(6.0)
	draw_rect(rr, COLOR, false, 4.0)
