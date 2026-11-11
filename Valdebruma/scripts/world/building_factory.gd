class_name BuildingFactory
extends RefCounted
## Ensambla un edificio a partir de su GLB y de data/buildings/<tipo>.json.
##
## Responsabilidad: crear la parte ESTÁTICA y visual (malla, mobiliario fijo, colisiones,
## luces de interior). Puertas y contenedores son interactivos y los crea el sector del
## mundo con su estado replicado; aquí solo se ofrecen utilidades para construirlos.
## Datos: ninguno propio (lee DataFiles). Autoridad online: ninguna (solo presentación
## y colisión local; el servidor valida con los mismos JSON, ver server_geometry.gd).

const LAYER_WORLD := 1
const LAYER_INTERACT := 4

## Devuelve un Node3D con la malla, el mobiliario y (opcional) las colisiones.
static func create(kind_name: String, with_collision := true, with_props := true) -> Node3D:
	var meta := DataFiles.building(kind_name)
	var root := Node3D.new()
	root.name = kind_name
	var mesh := AssetLib.model("buildings/" + kind_name)
	mesh.name = "Mesh"
	root.add_child(mesh)
	var body: StaticBody3D = null
	if with_collision:
		body = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		root.add_child(body)
		for c: Array in meta.get("colliders", []):
			_add_box(body, Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5]), Basis.IDENTITY)
		for r: Dictionary in meta.get("ramps", []):
			_add_ramp(body, DataFiles.v3(r.a), DataFiles.v3(r.b), float(r.w))
	if with_props:
		var holder := Node3D.new()
		holder.name = "Props"
		root.add_child(holder)
		for p: Dictionary in meta.get("props", []):
			var inst := place_prop(String(p.model), DataFiles.v3(p.pos), float(p.yaw), body)
			holder.add_child(inst)
	return root

## Instancia un mueble/objeto y añade su colisión (si es sólido) al cuerpo estático dado.
static func place_prop(model_name: String, pos: Vector3, yaw_deg: float, body: StaticBody3D = null) -> Node3D:
	var inst := AssetLib.model("props/" + model_name)
	inst.name = model_name
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	if body != null:
		add_prop_collider(body, model_name, pos, yaw_deg)
	return inst

static func add_prop_collider(body: StaticBody3D, model_name: String, pos: Vector3, yaw_deg: float) -> void:
	var info := DataFiles.prop(model_name)
	if info.is_empty() or not bool(info.get("solid", true)):
		return
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	if info.has("colliders"):
		for c: Array in info.colliders:
			_add_box(body, pos + basis * Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5]), basis)
		return
	var size: Vector3
	var center: Vector3
	if info.has("collider"):
		var cs: Array = info.collider
		size = Vector3(cs[0], cs[1], cs[2])
		var off: Array = info.get("collider_off", [0, 0, 0])
		center = Vector3(off[0], size.y * 0.5 + off[1], off[2])
	else:
		size = DataFiles.v3(info.size)
		center = DataFiles.v3(info.center)
	if size.y < 0.25:
		return
	_add_box(body, pos + basis * center, size, basis)

static func _add_box(body: StaticBody3D, center: Vector3, size: Vector3, basis: Basis) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)

static func _add_ramp(body: StaticBody3D, a: Vector3, b: Vector3, width: float) -> void:
	var dir := b - a
	var length := dir.length()
	var flat := Vector3(dir.x, 0, dir.z)
	var yaw := atan2(-flat.z, flat.x)
	var pitch := atan2(dir.y, flat.length())
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), pitch)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.2, width)
	cs.shape = shape
	cs.transform = Transform3D(basis, (a + b) * 0.5 + basis * Vector3(0, -0.1, 0))
	body.add_child(cs)

## Hoja de puerta visual (origen en la bisagra); la lógica vive en door.gd.
static func door_leaf(door: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = DataFiles.v3(door.pos)
	pivot.rotation_degrees.y = float(door.yaw)
	var leaf := AssetLib.model("doors/" + String(door.type))
	leaf.name = "Leaf"
	pivot.add_child(leaf)
	return pivot
