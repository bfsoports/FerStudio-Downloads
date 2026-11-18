class_name Prims
extends RefCounted
## Ayudantes para construir geometría low-poly por código: mallas primitivas, materiales cacheados y colisiones.

static var _mats: Dictionary = {}
static var _font: Font = null

static func ui_font() -> Font:
	if _font == null and ResourceLoader.exists("res://assets/fonts/Poppins-Bold.ttf"):
		_font = load("res://assets/fonts/Poppins-Bold.ttf") as Font
	return _font

static func mat(color: Color, rough: float = 0.85, emissive: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(true), rough, emissive]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

## Material con textura repetida en coordenadas del mundo (triplanar): una repetición cada 1/world_scale metros.
static func tex_mat(tex_name: String, tint: Color = Color.WHITE, world_scale: float = 0.5, rough: float = 0.9) -> StandardMaterial3D:
	var key := "T|%s|%s|%.2f" % [tex_name, tint.to_html(false), world_scale]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	var path := "res://assets/textures/%s.png" % tex_name
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path) as Texture2D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(world_scale, world_scale, world_scale)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "U|%s" % color.to_html(true)
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func _add(parent: Node, mesh: Mesh, pos: Vector3, m: Material, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, shadow: bool = true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(parent, bm, pos, m, shadow)

static func cyl(parent: Node, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, segs: int = 20) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return _add(parent, cm, pos, m, true)

## Esfera (o hemisferio con la base plana en pos.y) con aplastamiento vertical opcional.
static func sphere(parent: Node, radius: float, pos: Vector3, m: Material, squash: float = 1.0, hemi: bool = false, segs: int = 20) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius if hemi else radius * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = segs
	sm.rings = maxi(4, segs >> 1)
	var mi := _add(parent, sm, pos, m, true)
	mi.scale = Vector3(1.0, squash, 1.0)
	return mi

static func torus(parent: Node, inner: float, outer: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 20
	tm.ring_segments = 8
	return _add(parent, tm, pos, m, true)

static func capsule(parent: Node, radius: float, height: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 16
	cm.rings = 6
	return _add(parent, cm, pos, m, true)

static func quad(parent: Node, size: Vector2, pos: Vector3, m: Material, shadow: bool = false) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	return _add(parent, qm, pos, m, shadow)

static func collider_box(parent: Node, size: Vector3, pos: Vector3, layer: int = Const.LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	return body

## Caja visible con colisión sólida (paredes, mostradores, muebles).
static func solid_box(parent: Node, size: Vector3, pos: Vector3, m: Material) -> StaticBody3D:
	var body := collider_box(parent, size, pos)
	box(body, size, Vector3.ZERO, m)
	return body

static func label3d(parent: Node, text: String, pos: Vector3, pixel_size: float = 0.004, font_size: int = 64, color: Color = Color.WHITE, billboard: bool = true, outline: int = 12) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = pixel_size
	l.font_size = font_size
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Palette.BROWN
	var f := ui_font()
	if f != null:
		l.font = f
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l
