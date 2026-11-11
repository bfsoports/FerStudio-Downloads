class_name AssetLib
extends RefCounted
## Carga de modelos GLB con sustitución de materiales por nombre.
##
## Responsabilidad: los GLB generados por tools/blender solo llevan el NOMBRE del
## material; aquí se sustituye por el recurso compartido assets/materials/<nombre>.tres
## (una sola instancia por material => menos memoria y menos cambios de estado).
## Datos: cachés estáticas de materiales, escenas y mallas. Sin señales ni persistencia.
## Lo llaman: streaming del mundo, jugador, criaturas, interfaz (iconos 3D) y herramientas.

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var missing_materials: Dictionary = {}

static func material(mat_name: String) -> Material:
	if _materials.has(mat_name):
		return _materials[mat_name]
	var path := "res://assets/materials/%s.tres" % mat_name
	var m: Material = null
	if ResourceLoader.exists(path):
		m = load(path)
	else:
		missing_materials[mat_name] = true
	_materials[mat_name] = m
	return m

static func all_loaded_materials() -> Array:
	return _materials.values()

static func apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null and not mesh.has_meta(&"vb_remapped"):
			for i in mesh.get_surface_count():
				var src: Material = mesh.surface_get_material(i)
				if src != null:
					var m: Material = material(src.resource_name)
					if m != null:
						mesh.surface_set_material(i, m)
			mesh.set_meta(&"vb_remapped", true)
	for c in node.get_children():
		apply_materials(c)

static func has_model(rel: String) -> bool:
	return ResourceLoader.exists("res://assets/models/%s.glb" % rel)

static func scene(rel: String) -> PackedScene:
	var ps: PackedScene = _scenes.get(rel)
	if ps == null:
		ps = load("res://assets/models/%s.glb" % rel)
		_scenes[rel] = ps
	return ps

## Instancia un modelo, p. ej. model("vegetation/tree_oak_a_lod0").
static func model(rel: String) -> Node3D:
	var ps := scene(rel)
	if ps == null:
		push_error("Modelo inexistente: " + rel)
		return Node3D.new()
	var inst: Node3D = ps.instantiate()
	apply_materials(inst)
	return inst

## Devuelve la primera malla del modelo (para MultiMesh).
static func mesh(rel: String) -> Mesh:
	if _meshes.has(rel):
		return _meshes[rel]
	var inst := model(rel)
	var found: Mesh = _first_mesh(inst)
	inst.free()
	_meshes[rel] = found
	return found

static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null
