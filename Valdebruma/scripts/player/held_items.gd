class_name HeldItems
extends RefCounted
## HeldItems — cómo se coloca en la mano cada objeto equipable.
##
## Los modelos de objeto están tumbados a lo largo de su eje X (así reposan en el suelo). El
## hueso «item.R» de los brazos y del personaje tiene el origen en la palma, Y = eje del puño
## (del meñique al índice) y Z = hacia los dedos. Cada entrada lleva el objeto a ese agarre.

const GRIP := {
	# mango hacia abajo dentro del puño, filo hacia delante
	"hachuela": [Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0.25, -0.012)],
	"martillo": [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0.22, 0)],
	# barra hacia arriba con el gancho al frente
	"palanca": [Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0.2, -0.012)],
	"espantador": [Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -0.04, -0.02)],
	# linterna apuntando al frente, apoyada sobre el puño
	"linterna": [Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0.03, 0.03)],
	# farol colgando de su asa
	"farol": [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, -0.24, 0)],
}

static func grip(id: String) -> Transform3D:
	var g: Array = GRIP.get(id, [])
	if g.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0))
	return Transform3D(Basis(g[0], g[1], g[2]), g[3])

## Cuelga el modelo del objeto del hueso «item.R» del esqueleto dado. Devuelve el anclaje (o null).
static func attach(skeleton: Skeleton3D, id: String) -> BoneAttachment3D:
	if skeleton == null or id == "" or skeleton.find_bone("item.R") < 0 or not AssetLib.has_model("items/" + id):
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = "item.R"
	skeleton.add_child(att)
	var m := AssetLib.model("items/" + id)
	m.transform = grip(id)
	att.add_child(m)
	return att
