class_name ModelLib
extends RefCounted
## Carga los modelos 3D reales del juego: KayKit Restaurant Bits y Kenney Food Kit (ambos CC0) y los modelos propios
## del usuario en assets/models/custom/ (optimizados con tools/optimize_models.py).
## La tabla clave -> archivo/escala/desplazamiento la genera tools/gen_models.py (scripts/core/model_table.gd).
## Los modelos los importa el propio editor de Godot (assets/models/), así que aquí solo se instancian.

const ROOT := "res://assets/models/"

static func has(key: String) -> bool:
	return ModelTable.MODELS.has(key)

## Tamaño final del modelo en metros (con la escala de la tabla, sin estiramientos extra).
static func size_of(key: String) -> Vector3:
	if not ModelTable.MODELS.has(key):
		return Vector3.ZERO
	var e: Array = ModelTable.MODELS[key]
	return Vector3(float(e[5]), float(e[6]), float(e[7]))

## Instancia el modelo con la base apoyada en y=0. stretch estira cada eje (módulos de mostrador, bandejas...).
## Si el modelo no existe o no se ha importado devuelve un Node3D vacío y deja el error en el log.
static func spawn(key: String, stretch: Vector3 = Vector3.ONE) -> Node3D:
	var holder := Node3D.new()
	holder.name = key
	if not ModelTable.MODELS.has(key):
		push_error("ModelLib: modelo desconocido '%s'" % key)
		return holder
	var e: Array = ModelTable.MODELS[key]
	var path: String = ROOT + str(e[0])
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ModelLib: no se pudo cargar %s (¿lo ha importado ya el editor de Godot?)" % path)
		return holder
	var inst := packed.instantiate() as Node3D
	if inst == null:
		push_error("ModelLib: %s no tiene un nodo 3D como raíz" % path)
		return holder
	var s: float = float(e[1])
	holder.scale = Vector3(s * stretch.x, s * stretch.y, s * stretch.z)
	inst.position = Vector3(float(e[2]), float(e[3]), float(e[4]))
	holder.add_child(inst)
	return holder

## Multiplica el color de albedo de todas las mallas del nodo por c (el modelo conserva su textura).
## Duplica el material de cada superficie una sola vez, así que llamarla de nuevo solo cambia el color y los
## demás modelos que comparten el material importado no se ven afectados.
static func tint(node: Node, c: Color) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(s) as BaseMaterial3D
			if ov == null:
				var base := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if base == null:
					continue
				ov = base.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(s, ov)
			ov.albedo_color = c
	for ch in node.get_children():
		tint(ch, c)
