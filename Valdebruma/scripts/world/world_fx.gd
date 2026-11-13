class_name WorldFx
extends RefCounted
## WorldFx — efectos reutilizables del mundo (fuego de hoguera, luces de farol).
## Luces sin sombras y con desvanecido por distancia; la llama es el efecto Vfx.fire.

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
	var n := Node3D.new()
	n.add_child(Vfx.fire(0.85))
	var au := AudioStreamPlayer3D.new()
	au.stream = AudioDirector.stream("fire_loop")
	au.bus = &"Ambient"
	au.max_distance = 22.0
	au.unit_size = 4.0
	au.autoplay = true
	n.add_child(au)
	return n
