extends SceneTree
## Renderiza los iconos de inventario a partir de los modelos 3D reales de cada objeto.
## Uso: xvfb-run -a godot --path . -s tools/godot/render_icons.gd [-- --only=id1,id2]
## Salida: assets/icons/items/<id>.png (192×192, fondo transparente).

const SIZE := 192
var _vp: SubViewport
var _holder: Node3D
var _cam: Camera3D
var _ids: PackedStringArray = []
var _i := -1
var _wait := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/icons/items")
	var dir := DirAccess.open("res://assets/models/items")
	for f in dir.get_files():
		if f.ends_with(".glb"):
			_ids.append(f.get_basename())
	_ids.sort()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_ids = a.substr(7).split(",")
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE * 2, SIZE * 2)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 38, 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.96, 0.88)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -140, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.82, 1.0)
	_vp.add_child(rim)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_cam.current = true

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_aabb(c, xf, acc)

func _next() -> void:
	for c in _holder.get_children():
		c.free()
	_i += 1
	if _i >= _ids.size():
		return
	var inst := AssetLib.model("items/" + _ids[_i])
	_holder.add_child(inst)
	var acc: Array = [null]
	_aabb(inst, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0]
	var center := bb.get_center()
	var radius: float = bb.size.length() * 0.5
	var dir := Vector3(0.55, 0.62, 1.0).normalized()
	var dist: float = radius / tan(deg_to_rad(_cam.fov * 0.5)) * 1.08
	_cam.near = max(0.005, dist - radius * 2.0)
	_cam.far = dist + radius * 3.0
	_cam.look_at_from_position(center + dir * dist, center)
	_wait = 3

func _process(_d: float) -> bool:
	if _i < 0:
		_next()
		return false
	if _i >= _ids.size():
		print("iconos generados: ", _ids.size())
		return true
	_wait -= 1
	if _wait <= 0:
		var img := _vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/items/%s.png" % _ids[_i])
		_next()
	return false
