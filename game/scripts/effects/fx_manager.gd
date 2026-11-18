extends Node
## Pooled visual effects. Nothing here is instanced during gameplay: every
## particle system, light, decal and tracer is created once and recycled.

signal shake_requested(strength: float, duration: float)
signal hit_marker(headshot: bool, kill: bool)

const POOL_SIZES := {
	"spark": 10, "dust": 8, "blood": 12, "explosion": 3, "smoke": 4,
	"shockwave": 4, "energy": 4, "death": 6, "tracer": 14, "decal": 28, "light": 4,
}

var _pools := {}
var _cursor := {}
var _root: Node3D
var _soft_tex: Texture2D
var _spark_tex: Texture2D
var _hole_tex: Texture2D


func _ready() -> void:
	_soft_tex = _make_radial(64, 1.6)
	_spark_tex = _make_radial(32, 3.0)
	_hole_tex = _make_hole()


## Called by the gameplay scene so effects live inside the 3D world.
func attach_world(world: Node3D) -> void:
	_root = Node3D.new()
	_root.name = "FXPool"
	world.add_child(_root)
	_pools.clear()
	_cursor.clear()
	for kind in POOL_SIZES:
		_pools[kind] = []
		_cursor[kind] = 0
		for i in POOL_SIZES[kind]:
			var n := _create(kind)
			_root.add_child(n)
			_pools[kind].append(n)


func detach_world() -> void:
	_pools.clear()
	_root = null


func _next(kind: String) -> Node3D:
	if not _pools.has(kind) or not is_instance_valid(_root):
		return null
	var arr: Array = _pools[kind]
	var n: Node3D = arr[_cursor[kind]]
	_cursor[kind] = (_cursor[kind] + 1) % arr.size()
	return n


# --------------------------------------------------------------------------------
# public API
# --------------------------------------------------------------------------------

func impact(pos: Vector3, normal: Vector3, surface: String = "concrete") -> void:
	var p := _next("spark") as GPUParticles3D
	if p:
		_place(p, pos, normal)
		var m := p.process_material as ParticleProcessMaterial
		m.color = Color(1.0, 0.8, 0.4) if surface == "metal" else Color(1.0, 0.7, 0.35)
		_restart(p)
	var d := _next("dust") as GPUParticles3D
	if d and surface != "metal":
		_place(d, pos, normal)
		_restart(d)
	var dec := _next("decal") as Decal
	if dec:
		dec.global_position = pos
		dec.global_basis = _basis_from_normal(normal.normalized())
		dec.visible = true
		dec.modulate = Color(1, 1, 1, 1)


func blood(pos: Vector3, dir: Vector3, amount: float = 1.0) -> void:
	var p := _next("blood") as GPUParticles3D
	if p:
		_place(p, pos, dir)
		p.amount_ratio = clampf(amount, 0.2, 1.0) * Settings.particle_scale()
		p.restart()


func zombie_death(pos: Vector3, color: Color = Color(0.45, 0.9, 0.25)) -> void:
	var p := _next("death") as GPUParticles3D
	if p:
		p.global_position = pos
		(p.process_material as ParticleProcessMaterial).color = color
		_restart(p)


func explosion(pos: Vector3, radius: float = 5.0) -> void:
	var e := _next("explosion") as GPUParticles3D
	if e:
		e.global_position = pos
		_restart(e)
	var s := _next("smoke") as GPUParticles3D
	if s:
		s.global_position = pos + Vector3.UP * 0.4
		_restart(s)
	shockwave(pos + Vector3.UP * 0.15, Color(1.0, 0.6, 0.2), radius)
	flash_light(pos + Vector3.UP, Color(1.0, 0.6, 0.25), 9.0, radius * 2.5, 0.35)
	var dist := 10.0
	var cam := get_viewport().get_camera_3d()
	if cam:
		dist = cam.global_position.distance_to(pos)
	shake_requested.emit(clampf(1.4 - dist / 18.0, 0.15, 1.2), 0.45)
	Audio.play_at("explosion", pos, 4.0, 0.08, 70.0)


func shockwave(pos: Vector3, color: Color, radius: float) -> void:
	var w := _next("shockwave") as MeshInstance3D
	if w == null:
		return
	w.global_position = pos
	w.scale = Vector3.ONE * 0.2
	w.visible = true
	var mat := w.material_override as StandardMaterial3D
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w, "scale", Vector3(radius, 1.0, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(func(): w.visible = false)


func energy_burst(pos: Vector3, color: Color = Color(0.55, 1.0, 0.3)) -> void:
	var p := _next("energy") as GPUParticles3D
	if p:
		p.global_position = pos
		(p.process_material as ParticleProcessMaterial).color = color
		_restart(p)
	flash_light(pos, color, 4.0, 6.0, 0.5)


func flash_light(pos: Vector3, color: Color, energy: float, range_: float, duration: float) -> void:
	var l := _next("light") as OmniLight3D
	if l == null:
		return
	l.global_position = pos
	l.light_color = color
	l.omni_range = range_
	l.light_energy = energy
	l.visible = true
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(func(): l.visible = false)


func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.5)) -> void:
	var t := _next("tracer") as MeshInstance3D
	if t == null:
		return
	var len := from.distance_to(to)
	if len < 0.5:
		return
	t.visible = true
	t.global_position = from.lerp(to, 0.5)
	t.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	t.scale = Vector3(1, 1, len)
	var mat := t.material_override as StandardMaterial3D
	mat.albedo_color = color
	var tw := t.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(func(): t.visible = false)


func shake(strength: float, duration: float = 0.25) -> void:
	shake_requested.emit(strength, duration)


# --------------------------------------------------------------------------------
# construction
# --------------------------------------------------------------------------------

func _place(p: Node3D, pos: Vector3, normal: Vector3) -> void:
	p.global_position = pos
	if normal.length() > 0.01:
		p.global_basis = _basis_from_normal(normal.normalized())


func _basis_from_normal(n: Vector3) -> Basis:
	# Y axis along the normal
	var up := n
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


func _restart(p: GPUParticles3D) -> void:
	p.amount_ratio = Settings.particle_scale()
	p.restart()


func _particles(amount: int, lifetime: float, tex: Texture2D, size: float, additive: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	quad.material = m
	p.draw_pass_1 = quad
	return p


func _ppm(dir: Vector3, spread: float, vmin: float, vmax: float, gravity: Vector3, color: Color, scale_curve := true) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = vmin
	m.initial_velocity_max = vmax
	m.gravity = gravity
	m.color = color
	m.damping_min = 1.0
	m.damping_max = 3.0
	if scale_curve:
		var c := Curve.new()
		c.add_point(Vector2(0, 1))
		c.add_point(Vector2(1, 0))
		var ct := CurveTexture.new()
		ct.curve = c
		m.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	return m


func _create(kind: String) -> Node3D:
	match kind:
		"spark":
			var p := _particles(14, 0.35, _spark_tex, 0.07, true)
			p.process_material = _ppm(Vector3.UP, 55, 3.0, 8.0, Vector3(0, -9, 0), Color(1, 0.75, 0.35))
			return p
		"dust":
			var p := _particles(6, 0.8, _soft_tex, 0.35, false)
			var m := _ppm(Vector3.UP, 35, 0.4, 1.4, Vector3(0, 0.2, 0), Color(0.55, 0.52, 0.46, 0.7), false)
			m.scale_min = 0.6
			m.scale_max = 1.4
			p.process_material = m
			return p
		"blood":
			var p := _particles(16, 0.55, _soft_tex, 0.12, false)
			var m := _ppm(Vector3.UP, 40, 1.5, 4.0, Vector3(0, -9.8, 0), Color(0.42, 0.06, 0.05))
			m.scale_min = 0.6
			m.scale_max = 1.5
			p.process_material = m
			return p
		"death":
			var p := _particles(22, 0.9, _soft_tex, 0.18, true)
			var m := _ppm(Vector3.UP, 70, 1.0, 3.5, Vector3(0, -2, 0), Color(0.45, 0.9, 0.25))
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.4
			p.process_material = m
			return p
		"explosion":
			var p := _particles(40, 0.7, _soft_tex, 1.1, true)
			var m := _ppm(Vector3.UP, 180, 3.0, 9.0, Vector3(0, 1.5, 0), Color(1.0, 0.55, 0.15))
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.6
			m.scale_min = 0.7
			m.scale_max = 1.8
			p.process_material = m
			return p
		"smoke":
			var p := _particles(18, 2.4, _soft_tex, 1.8, false)
			var m := _ppm(Vector3.UP, 60, 0.6, 2.2, Vector3(0, 0.6, 0), Color(0.18, 0.17, 0.16, 0.75), false)
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.8
			m.scale_min = 0.8
			m.scale_max = 2.0
			p.process_material = m
			return p
		"energy":
			var p := _particles(28, 1.0, _spark_tex, 0.14, true)
			var m := _ppm(Vector3.UP, 180, 1.0, 4.0, Vector3(0, 1.2, 0), Color(0.55, 1, 0.3))
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.5
			p.process_material = m
			return p
		"shockwave":
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.92
			tm.outer_radius = 1.0
			tm.rings = 32
			tm.ring_segments = 4
			mi.mesh = tm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			return mi
		"tracer":
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.018, 0.018, 1.0)
			mi.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			return mi
		"decal":
			var d := Decal.new()
			d.size = Vector3(0.14, 0.12, 0.14)
			d.texture_albedo = _hole_tex
			d.cull_mask = 1
			d.distance_fade_enabled = true
			d.distance_fade_begin = 18.0
			d.distance_fade_length = 6.0
			d.visible = false
			return d
		"light":
			var l := OmniLight3D.new()
			l.shadow_enabled = false
			l.visible = false
			return l
	return Node3D.new()


func _make_radial(size: int, falloff: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := clampf(Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			var a := pow(1.0 - d, falloff)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_hole() -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := 0.0
			if d < 0.35:
				a = 0.95
			elif d < 1.0:
				a = 0.55 * (1.0 - d) * (0.6 + 0.4 * sin(atan2(y - c, x - c) * 5.0))
			img.set_pixel(x, y, Color(0.05, 0.05, 0.05, a))
	return ImageTexture.create_from_image(img)
