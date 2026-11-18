class_name Bar3D
extends Node3D
## Barra de progreso 3D con texto (cocción, paciencia). Siempre se orienta hacia la cámara en horizontal.

var width: float = 0.5
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _label: Label3D = null
var _last_text := ""

func _init(w: float = 0.5, with_label: bool = true) -> void:
	width = w
	Prims.quad(self, Vector2(w + 0.05, 0.1), Vector3(0, 0, -0.002), Prims.unshaded(Color(0.1, 0.07, 0.06, 0.85)))
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.albedo_color = Palette.LETTUCE
	var qm := QuadMesh.new()
	qm.size = Vector2(w, 0.07)
	qm.center_offset = Vector3(w * 0.5, 0.0, 0.0)
	_fill = MeshInstance3D.new()
	_fill.mesh = qm
	_fill.material_override = _fill_mat
	_fill.position = Vector3(-w * 0.5, 0.0, 0.0)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
	if with_label:
		_label = Prims.label3d(self, "", Vector3(0, 0.15, 0), 0.0032, 56, Palette.CREAM, true, 10)

func set_ratio(ratio: float, color: Color) -> void:
	_fill.scale.x = maxf(clampf(ratio, 0.0, 1.0), 0.001)
	_fill_mat.albedo_color = color

func set_text(text: String) -> void:
	if _label != null and text != _last_text:
		_last_text = text
		_label.text = text

func show_bar(v: bool) -> void:
	visible = v
	set_process(v)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var away := global_position + (global_position - cam.global_position)
	away.y = global_position.y
	if absf(away.x - global_position.x) + absf(away.z - global_position.z) > 0.001:
		look_at(away, Vector3.UP)
