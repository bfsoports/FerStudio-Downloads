class_name WorldFx
extends RefCounted
## WorldFx — efectos reutilizables del mundo (fuego de hoguera, luces de farol).
## Partículas y luces con coste contenido: pocas partículas, luz sin sombras.

static func lamp(pos: Vector3, color: Color, range_m: float, energy := 1.6) -> Node3D:
	var n := Node3D.new()
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_m
	l.light_energy = energy
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 15.0
	n.add_child(l)
	return n

static func campfire() -> Node3D:
	var n := lamp(Vector3(0, 0.7, 0), Color(1.0, 0.62, 0.3), 9.0, 2.2)
	n.set_script(load("res://scripts/world/flicker.gd"))
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.9
	p.position = Vector3(0, 0.15, 0)
	p.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.16
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	grad.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/textures/fx/flame.png")
	quad.material = mat
	p.draw_pass_1 = quad
	n.add_child(p)
	var au := AudioStreamPlayer3D.new()
	au.stream = AudioDirector.stream("fire_loop")
	au.bus = &"Ambient"
	au.max_distance = 22.0
	au.unit_size = 4.0
	au.autoplay = true
	n.add_child(au)
	return n
