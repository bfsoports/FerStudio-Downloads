class_name MapKit
extends RefCounted
## Shared materials, geometry batching and procedural low-poly props.
##
## Static level geometry is accumulated in a Batcher and merged into ONE mesh
## per material per 16 m cell: few draw calls, effective frustum culling.
## Boxes get world-space planar UVs (textures tile seamlessly without triplanar
## cost) and vertex-colour ambient occlusion baked from height.

const CELL := 24.0

static var _mats := {}


# ------------------------------------------------------------------------------
# materials
# ------------------------------------------------------------------------------

static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.25
	var tex := ""
	var col := Color.WHITE
	var emissive := Color.BLACK
	match key:
		"concrete": tex = "concrete"
		"asphalt": tex = "asphalt"
		"brick": tex = "brick"
		"metal": tex = "metal_corrugated"; m.roughness = 0.7
		"wood", "plank", "crate": tex = "wood_planks"
		"dirt": tex = "dirt"
		"tiles": tex = "tiles"
		"hazard": tex = "hazard"
		"roof": tex = "roof"
		"plaster": tex = "plaster"
		"wallbuy":
			tex = "concrete"; col = Color(0.85, 0.82, 0.72)
		"dark_metal": col = Color(0.16, 0.17, 0.17); m.roughness = 0.55; m.metallic = 0.4
		"steel": col = Color(0.42, 0.44, 0.45); m.roughness = 0.45; m.metallic = 0.5
		"rust": col = Color(0.42, 0.24, 0.14)
		"rubber": col = Color(0.07, 0.07, 0.07)
		"sandbag": col = Color(0.55, 0.49, 0.36)
		"car_teal": col = Color(0.22, 0.42, 0.42); m.roughness = 0.6
		"car_red": col = Color(0.52, 0.16, 0.12); m.roughness = 0.6
		"car_cream": col = Color(0.72, 0.68, 0.55); m.roughness = 0.6
		"car_blue": col = Color(0.2, 0.26, 0.42); m.roughness = 0.6
		"glass": col = Color(0.1, 0.13, 0.14); m.roughness = 0.15; m.metallic = 0.3
		"sign_red": col = Color(0.65, 0.12, 0.08)
		"sign_yellow": col = Color(0.85, 0.65, 0.12)
		"sign_green": col = Color(0.18, 0.4, 0.2)
		"olive": col = Color(0.3, 0.34, 0.22)
		"lamp_warm":
			col = Color(1.0, 0.85, 0.6); emissive = Color(1.0, 0.72, 0.4)
		"lamp_green":
			col = Color(0.6, 1.0, 0.4); emissive = Color(0.45, 1.0, 0.25)
		"lamp_red":
			col = Color(1.0, 0.3, 0.2); emissive = Color(1.0, 0.25, 0.15)
		"neon_orange":
			col = Color(1.0, 0.6, 0.2); emissive = Color(1.0, 0.5, 0.1)
		"black": col = Color(0.03, 0.03, 0.03)
		_:
			col = Color(0.5, 0.5, 0.5)
	if tex != "":
		m.albedo_texture = load("res://assets/textures/%s.png" % tex)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_color = col
	if emissive != Color.BLACK:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = 2.2
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


# ------------------------------------------------------------------------------
# batcher
# ------------------------------------------------------------------------------

class Batcher:
	var tools := {}     # "mat|cx|cz" -> SurfaceTool
	var uv_scale := 0.5

	func _tool(mat_key: String, at: Vector3) -> SurfaceTool:
		var cx := int(floor(at.x / MapKit.CELL))
		var cz := int(floor(at.z / MapKit.CELL))
		var k := "%s|%d|%d" % [mat_key, cx, cz]
		if not tools.has(k):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[k] = st
		return tools[k]

	## Oriented box with world planar UVs and height AO.
	func box(xf: Transform3D, size: Vector3, mat_key: String, tex_scale: float = -1.0, ao: bool = true) -> void:
		var st := _tool(mat_key, xf.origin)
		var s := tex_scale if tex_scale > 0 else uv_scale
		var h := size * 0.5
		var faces := [
			[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
			[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
			[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
			[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
			[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		]
		for f in faces:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var c := Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
			var hu := absf(u.x) * h.x + absf(u.y) * h.y + absf(u.z) * h.z
			var hv := absf(v.x) * h.x + absf(v.y) * h.y + absf(v.z) * h.z
			var corners := [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
			var wn := (xf.basis * n).normalized()
			var wpts := []
			for p in corners:
				wpts.append(xf * p)
			# world planar projection by dominant normal axis
			var uvs := []
			for wp in wpts:
				var uv: Vector2
				if absf(wn.y) > 0.7:
					uv = Vector2(wp.x, wp.z)
				elif absf(wn.x) > absf(wn.z):
					uv = Vector2(wp.z, -wp.y)
				else:
					uv = Vector2(wp.x, -wp.y)
				uvs.append(uv * s)
			var cols := []
			for wp in wpts:
				var k := 1.0
				if ao:
					k = clampf(0.55 + wp.y * 0.3, 0.55, 1.0) if absf(wn.y) < 0.7 else (1.0 if wn.y > 0 else 0.5)
				cols.append(Color(k, k, k))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(wn)
				st.set_uv(uvs[idx])
				st.set_color(cols[idx])
				st.add_vertex(wpts[idx])

	## Appends a primitive Mesh (cylinder, prism...) with a flat colour multiplier.
	func mesh(m: Mesh, xf: Transform3D, mat_key: String, shade: float = 1.0) -> void:
		var st := _tool(mat_key, xf.origin)
		var arrays := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx != null and idx.size() > 0 else verts.size()
		for i in count:
			var vi: int = idx[i] if idx != null and idx.size() > 0 else i
			st.set_normal((xf.basis * norms[vi]).normalized())
			st.set_uv((uvs[vi] if uvs != null and uvs.size() > vi else Vector2.ZERO))
			st.set_color(Color(shade, shade, shade))
			st.add_vertex(xf * verts[vi])

	func build(parent: Node3D) -> int:
		var count := 0
		for k in tools:
			var st: SurfaceTool = tools[k]
			var mesh := st.commit()
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = MapKit.mat(k.split("|")[0])
			mi.name = "Static_" + k.replace("|", "_")
			mi.visibility_range_end = Settings.view_distance() + 10.0
			parent.add_child(mi)
			count += 1
		tools.clear()
		return count


# ------------------------------------------------------------------------------
# collision helper
# ------------------------------------------------------------------------------

static func collider(parent: Node3D, xf: Transform3D, size: Vector3, layer: int = 1, group: String = "") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.transform = xf
	if group != "":
		b.add_to_group(group)
	parent.add_child(b)
	return b


static func solid(b: Batcher, parent: Node3D, xf: Transform3D, size: Vector3, mat_key: String, tex_scale: float = -1.0, group: String = "") -> void:
	b.box(xf, size, mat_key, tex_scale)
	collider(parent, xf, size, 1, group)


static func at(pos: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)


# ------------------------------------------------------------------------------
# props (batched)
# ------------------------------------------------------------------------------

static var _cyl_cache := {}

static func cylinder(r: float, h: float, segs: int = 8) -> Mesh:
	var k := "%f|%f|%d" % [r, h, segs]
	if not _cyl_cache.has(k):
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		_cyl_cache[k] = c
	return _cyl_cache[k]


static func car_wreck(b: Batcher, parent: Node3D, xf: Transform3D, paint: String) -> void:
	# body
	solid(b, parent, xf * Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3(1.85, 0.62, 4.3), paint)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.18, -0.2)), Vector3(1.6, 0.52, 2.2), paint)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.2, -0.2)), Vector3(1.62, 0.36, 2.0), "glass")
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.66, 2.16)), Vector3(1.7, 0.22, 0.08), "steel")
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.66, -2.16)), Vector3(1.7, 0.22, 0.08), "steel")
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.3, 0.95, 1.2)), Vector3(0.7, 0.04, 0.9), "rust")
	for sx in [-1, 1]:
		for sz in [-1.35, 1.35]:
			var w := xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 0.86, 0.33, sz))
			b.mesh(cylinder(0.34, 0.26, 10), w, "rubber")


static func streetlight(b: Batcher, parent: Node3D, xf: Transform3D, with_light: bool) -> OmniLight3D:
	b.mesh(cylinder(0.08, 5.6, 6), xf * Transform3D(Basis(), Vector3(0, 2.8, 0)), "dark_metal")
	b.box(xf * Transform3D(Basis(), Vector3(0, 5.5, 0.7)), Vector3(0.12, 0.1, 1.5), "dark_metal")
	b.box(xf * Transform3D(Basis(), Vector3(0, 5.42, 1.35)), Vector3(0.36, 0.12, 0.55), "lamp_warm")
	collider(parent, xf * Transform3D(Basis(), Vector3(0, 2.8, 0)), Vector3(0.2, 5.6, 0.2))
	if not with_light:
		return null
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 2.4
	l.omni_range = 11.0
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.transform = xf * Transform3D(Basis(), Vector3(0, 5.0, 1.35))
	parent.add_child(l)
	return l


static func barrel(b: Batcher, parent: Node3D, pos: Vector3, mat_key: String = "rust") -> void:
	var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), pos + Vector3(0, 0.45, 0))
	b.mesh(cylinder(0.3, 0.9, 10), xf, mat_key)
	b.mesh(cylinder(0.31, 0.06, 10), xf * Transform3D(Basis(), Vector3(0, 0.22, 0)), "dark_metal")
	b.mesh(cylinder(0.31, 0.06, 10), xf * Transform3D(Basis(), Vector3(0, -0.22, 0)), "dark_metal")
	collider(parent, xf, Vector3(0.6, 0.9, 0.6))


static func crate(b: Batcher, parent: Node3D, pos: Vector3, s: float = 1.0, yaw: float = 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos + Vector3(0, s * 0.5, 0))
	b.box(xf, Vector3.ONE * s, "crate", 1.0 / s)
	for e in [Vector3(0, 0.5, 0.5), Vector3(0, -0.5, 0.5), Vector3(0, 0.5, -0.5), Vector3(0, -0.5, -0.5)]:
		b.box(xf * Transform3D(Basis(), e * s), Vector3(s + 0.02, 0.08 * s, 0.08 * s), "dark_metal")
	collider(parent, xf, Vector3.ONE * s)


static func sandbags(b: Batcher, parent: Node3D, xf: Transform3D, length: float) -> void:
	var n := int(length / 0.62)
	for row in 3:
		for i in n - row % 2:
			var x := -length * 0.5 + 0.31 + i * 0.62 + (0.31 if row % 2 == 1 else 0.0)
			b.box(xf * Transform3D(Basis(Vector3.UP, randf_range(-0.1, 0.1)), Vector3(x, 0.14 + row * 0.24, 0)), Vector3(0.6, 0.26, 0.42), "sandbag")
	collider(parent, xf * Transform3D(Basis(), Vector3(0, 0.38, 0)), Vector3(length, 0.76, 0.45))


static func jersey_barrier(b: Batcher, parent: Node3D, xf: Transform3D) -> void:
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(2.0, 0.3, 0.6), "concrete")
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(2.0, 0.5, 0.3), "concrete")
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.62, 0.16)), Vector3(2.0, 0.12, 0.02), "hazard", 2.0)
	collider(parent, xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.0, 0.9, 0.6))


static func container(b: Batcher, parent: Node3D, xf: Transform3D, paint: String = "metal") -> void:
	solid(b, parent, xf * Transform3D(Basis(), Vector3(0, 1.3, 0)), Vector3(2.45, 2.6, 6.0), paint, 0.6)
	for z in [-2.95, 2.95]:
		b.box(xf * Transform3D(Basis(), Vector3(0, 1.3, z)), Vector3(2.5, 2.65, 0.12), "dark_metal")


static func shelf(b: Batcher, parent: Node3D, xf: Transform3D) -> void:
	for x in [-1.9, 1.9]:
		for z in [-0.5, 0.5]:
			b.box(xf * Transform3D(Basis(), Vector3(x, 1.6, z)), Vector3(0.1, 3.2, 0.1), "sign_yellow")
	for y in [0.15, 1.2, 2.25]:
		b.box(xf * Transform3D(Basis(), Vector3(0, y, 0)), Vector3(4.0, 0.08, 1.1), "sign_red")
		for i in 3:
			if randf() < 0.75:
				var s := randf_range(0.5, 0.85)
				b.box(xf * Transform3D(Basis(Vector3.UP, randf_range(-0.2, 0.2)), Vector3(-1.3 + i * 1.3, y + 0.04 + s * 0.5, 0)), Vector3(s, s, s), "crate", 1.0 / s)
	collider(parent, xf * Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(4.0, 3.2, 1.1))


static func gas_pump(b: Batcher, parent: Node3D, xf: Transform3D) -> void:
	solid(b, parent, xf * Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.2, 0.3, 0.8), "concrete")
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.05, 0)), Vector3(0.75, 1.5, 0.5), "sign_red")
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.45, 0.26)), Vector3(0.5, 0.3, 0.02), "lamp_warm")
	b.box(xf * Transform3D(Basis(), Vector3(0.42, 0.9, 0)), Vector3(0.08, 0.5, 0.1), "black")
	collider(parent, xf * Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(0.8, 1.8, 0.55))


static func debris(b: Batcher, center: Transform3D, size: Vector3, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in 9:
		var p := Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(0.0, 0.8) * size.y, rng.randf_range(-0.4, 0.4) * size.z)
		var s := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.3, 0.9), rng.randf_range(0.5, 1.0))
		var rot := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		b.box(center * Transform3D(rot, p + Vector3.UP * s.y * 0.4), s, "concrete" if i % 3 else "wood")


# ------------------------------------------------------------------------------
# interactive visuals (not batched: they move / glow)
# ------------------------------------------------------------------------------

static func _mi(m: Mesh, mat_key: String, pos: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(mat_key)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func door_visual(style: String, size: Vector3) -> Node3D:
	var root := Node3D.new()
	if style == "gate":
		_mi(_boxm(Vector3(size.x, size.y, 0.12)), "metal", Vector3(0, size.y * 0.5, 0), root)
		for i in 5:
			_mi(_boxm(Vector3(size.x + 0.05, 0.08, 0.16)), "dark_metal", Vector3(0, 0.3 + i * size.y / 5.0, 0), root)
		_mi(_boxm(Vector3(size.x * 0.9, 0.35, 0.14)), "hazard", Vector3(0, size.y * 0.5, 0.02), root)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(size.x * 100)
		for i in 14:
			var s := Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.7))
			var p := Vector3(rng.randf_range(-0.45, 0.45) * size.x, rng.randf_range(0.1, 0.85) * size.y, rng.randf_range(-0.3, 0.3))
			var mi := _mi(_boxm(s), "concrete" if i % 3 else "wood", p, root, Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * PI, rng.randf_range(-0.5, 0.5)))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi(_boxm(Vector3(size.x * 0.8, 0.14, 0.05)), "hazard", Vector3(0, size.y * 0.75, size.z * 0.5 + 0.1), root, Vector3(0, 0, 0.08))
	return root


static func perk_machine_visual(color: Color, icon_name: String) -> Node3D:
	var root := Node3D.new()
	var body := StandardMaterial3D.new()
	body.albedo_color = color.darkened(0.35)
	body.roughness = 0.55
	body.metallic = 0.2
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color.lightened(0.2)
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cab := MeshInstance3D.new()
	cab.mesh = _boxm(Vector3(1.2, 2.2, 0.9))
	cab.material_override = body
	cab.position = Vector3(0, 1.1, 0)
	root.add_child(cab)
	var screen := MeshInstance3D.new()
	screen.mesh = _boxm(Vector3(0.9, 1.0, 0.04))
	screen.material_override = glow
	screen.position = Vector3(0, 1.4, 0.46)
	root.add_child(screen)
	var top := MeshInstance3D.new()
	top.mesh = _boxm(Vector3(1.3, 0.25, 1.0))
	top.material_override = mat("dark_metal")
	top.position = Vector3(0, 2.3, 0)
	root.add_child(top)
	var slot := MeshInstance3D.new()
	slot.mesh = _boxm(Vector3(0.6, 0.25, 0.06))
	slot.material_override = mat("black")
	slot.position = Vector3(0, 0.45, 0.46)
	root.add_child(slot)
	var tex := UIStyle.icon(icon_name)
	if tex:
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.pixel_size = 0.0055
		sp.position = Vector3(0, 1.45, 0.49)
		sp.modulate = Color(0.08, 0.08, 0.08)
		root.add_child(sp)
	var cs := StaticBody3D.new()
	cs.collision_layer = 1
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 2.4, 0.9)
	shape.shape = bs
	shape.position.y = 1.2
	cs.add_child(shape)
	root.add_child(cs)
	return root


static func forge_visual() -> Node3D:
	var root := Node3D.new()
	_mi(_boxm(Vector3(2.4, 0.6, 1.8)), "dark_metal", Vector3(0, 0.3, 0), root)
	_mi(_boxm(Vector3(2.5, 0.12, 1.9)), "hazard", Vector3(0, 0.62, 0), root)
	for x in [-1.0, 1.0]:
		_mi(_boxm(Vector3(0.32, 2.6, 0.5)), "steel", Vector3(x, 1.9, -0.3), root)
	_mi(_boxm(Vector3(2.4, 0.4, 0.8)), "dark_metal", Vector3(0, 3.2, -0.3), root)
	_mi(_boxm(Vector3(1.2, 0.25, 0.9)), "rust", Vector3(0, 2.6, 0.1), root)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	core.material_override = mat("lamp_green")
	core.position = Vector3(0, 1.35, -0.35)
	core.name = "Core"
	root.add_child(core)
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.48 + i * 0.16
		tm.outer_radius = 0.55 + i * 0.16
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = mat("lamp_green") if i == 0 else mat("steel")
		ring.position = Vector3(0, 1.35, -0.35)
		ring.rotation = Vector3(deg_to_rad(70 + i * 30), 0, deg_to_rad(15))
		var pivot := Node3D.new()
		pivot.name = "Ring%d" % i
		pivot.position = Vector3.ZERO
		pivot.add_child(ring)
		root.add_child(pivot)
	# conveyor
	_mi(_boxm(Vector3(0.9, 0.08, 1.4)), "rubber", Vector3(0, 0.95, 0.5), root)
	var cs := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.5, 3.4, 1.6)
	shape.shape = bs
	shape.position = Vector3(0, 1.7, -0.2)
	cs.add_child(shape)
	root.add_child(cs)
	return root


static func mystery_box_visual() -> Node3D:
	var root := Node3D.new()
	if ResourceLoader.exists("res://assets/props/mystery_box.glb"):
		var m: Node3D = load("res://assets/props/mystery_box.glb").instantiate()
		m.scale = Vector3(1.35, 1.25, 1.2)
		m.position.y = 0.39
		root.add_child(m)
	var q := Label3D.new()
	q.text = "?"
	q.font = UIStyle.title_font()
	q.font_size = 96
	q.pixel_size = 0.004
	q.modulate = Color(0.6, 1.0, 0.35)
	q.outline_size = 0
	q.position = Vector3(0, 0.42, 0.44)
	root.add_child(q)
	var q2 := q.duplicate() as Label3D
	q2.position = Vector3(0, 0.42, -0.44)
	q2.rotation.y = PI
	root.add_child(q2)
	var cs := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.35, 0.8, 0.85)
	shape.shape = bs
	shape.position.y = 0.4
	cs.add_child(shape)
	root.add_child(cs)
	return root


static func sign(parent: Node3D, text: String, xf: Transform3D, color: Color, size: int = 96) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.title_font()
	l.font_size = size * 2
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.transform = xf
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l
