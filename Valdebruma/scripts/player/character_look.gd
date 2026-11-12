class_name CharacterLook
extends RefCounted
## CharacterLook — aspecto de los personajes: colores cosméticos, piezas de equipo visibles y
## arreglo de bucles de animación tras importar los GLB.

## Marca como cíclicos los clips que lo son según el JSON generado junto al modelo.
static func fix_loops(ap: AnimationPlayer, json_path: String) -> void:
	if ap == null:
		return
	var clips: Dictionary = DataFiles.dict(json_path).get("clips", {})
	for clip: String in clips.keys():
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if bool(clips[clip].loop) else Animation.LOOP_NONE

static func _color_of(id: String, key: String, def: Color) -> Color:
	var c: Dictionary = (GameData.progression.get("cosmetics", {}) as Dictionary).get(id, {})
	var a: Variant = c.get(key)
	return Color(a[0], a[1], a[2]) if a is Array else def

## Aplica colores de chaqueta y gorro duplicando solo esos materiales para este personaje.
static func tint(model: Node, cosmetics: Dictionary, raincoat: bool) -> void:
	var jacket := _color_of(String(cosmetics.get("jacket", "")), "color", Color(0.34, 0.4, 0.27))
	if raincoat:
		jacket = Color(0.86, 0.68, 0.16)
	var hat := _color_of(String(cosmetics.get("hat", "")), "hat", Color(0.5, 0.2, 0.14))
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null:
				continue
			var which := mat.resource_name
			if which == "char_jacket" or which == "char_hat":
				var dup: StandardMaterial3D = mat.duplicate()
				dup.resource_name = which
				dup.albedo_color = jacket if which == "char_jacket" else hat
				mi.set_surface_override_material(s, dup)

## Muestra u oculta las piezas según el equipo visible: {hat, pack, mask}.
static func equipment(model: Node, eq: Dictionary) -> void:
	var pack := int(eq.get("pack", 0))
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		match String(n.name):
			"hat": (n as Node3D).visible = bool(eq.get("hat", false))
			"mask": (n as Node3D).visible = bool(eq.get("mask", false))
			"pack_small": (n as Node3D).visible = pack == 1
			"pack_large": (n as Node3D).visible = pack == 2
