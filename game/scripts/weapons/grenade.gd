class_name Grenade
extends RigidBody3D
## Frag grenade: bounces, beeps, explodes after a fuse. Damage scales with round.

const FUSE := 2.2
const RADIUS := 5.5

var _owner_player: Player
var _t := 0.0
var _beep := 0.0
var _light: OmniLight3D


func _init() -> void:
	mass = 0.4
	collision_layer = 0
	collision_mask = 1
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.35
	physics_material_override.friction = 0.8
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.07
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.16
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.18)
	mat.roughness = 0.7
	mi.material_override = mat
	add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.2, 0.1)
	_light.omni_range = 1.5
	_light.light_energy = 0.0
	add_child(_light)


func launch(vel: Vector3, owner_player: Player) -> void:
	_owner_player = owner_player
	linear_velocity = vel
	angular_velocity = Vector3(randf(), randf(), randf()) * 8.0


func _physics_process(delta: float) -> void:
	_t += delta
	_beep -= delta
	if _beep <= 0.0:
		_beep = maxf(0.12, 0.5 - _t * 0.18)
		_light.light_energy = 2.0
		Audio.play_at("grenade_beep", global_position, -12.0, 0.0, 15.0)
	else:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 20.0)
	if _t >= FUSE:
		_explode()


func _explode() -> void:
	var pos := global_position
	FX.explosion(pos, RADIUS)
	var dmg := 180.0 + 90.0 * float(GameState.current_round)
	for z in get_tree().get_nodes_in_group("zombie"):
		if z is Zombie and z.is_alive():
			var d: float = (z.global_position + Vector3.UP).distance_to(pos)
			if d < RADIUS:
				var f: float = 1.0 - d / RADIUS * 0.6
				(z as Zombie).take_hit(dmg * f, z.global_position + Vector3.UP, (z.global_position - pos).normalized(), false, _owner_player.weapons if _owner_player else null, true)
	if _owner_player and _owner_player.alive:
		var pd := _owner_player.global_position.distance_to(pos)
		if pd < 3.0:
			_owner_player.take_damage(35.0 * (1.0 - pd / 3.0), pos)
	queue_free()
