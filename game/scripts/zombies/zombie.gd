class_name Zombie
extends CharacterBody3D
## Zombie body: stats, damage, navigation helpers and the state machine host.
## Behaviour lives in scripts/zombies/states/*.gd (one script per state).

signal died(zombie: Zombie, headshot: bool)

const GRAVITY := 14.0

var data: ZombieData
var health := 100.0
var max_health := 100.0
var speed := 1.2
var running := false
var round_spawned := 1
var target: Player
var barrier: Barricade           # window this zombie must break through (may be null)
var spawn_point: SpawnPoint
var animator: ZombieAnimator
var agent: NavigationAgent3D
var states := {}
var state: ZombieState
var state_name := ""
var boss_brain: Node

var _alive := false
var _burn_time := 0.0
var _burn_dps := 0.0
var _burn_source: Node
var _repath_timer := 0.0
var _stagger_cd := 0.0
var _groan_t := 0.0
var _model: Node3D
var _shape: CollisionShape3D
var _blob: MeshInstance3D
var _mesh_instances: Array[MeshInstance3D] = []
var _burn_overlay: StandardMaterial3D
var _skeleton: Skeleton3D
var _head_bone := -1
var _last_pos := Vector3.ZERO
var _stuck_t := 0.0

static var _scene_cache := {}
static var _blob_mesh: QuadMesh


func setup(d: ZombieData) -> void:
	data = d
	name = "Zombie_" + d.id
	add_to_group("zombie")
	collision_layer = 4
	collision_mask = 1 | 4 | 32
	floor_snap_length = 0.4
	safe_margin = 0.02
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = d.radius * d.scale
	cap.height = d.height * d.scale
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	add_child(_shape)
	# model
	if not _scene_cache.has(d.model_path):
		_scene_cache[d.model_path] = load(d.model_path)
	_model = (_scene_cache[d.model_path] as PackedScene).instantiate()
	_model.scale = Vector3.ONE * d.scale
	_model.rotation.y = PI    # glTF faces +Z; our forward is -Z
	add_child(_model)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		_mesh_instances.append(m)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if Settings.quality == Settings.Quality.HIGH and d.scale > 1.2:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		m.visibility_range_end = Settings.view_distance()
		if d.tint != Color.WHITE or d.emissive != Color.BLACK:
			var src := m.get_active_material(0) as StandardMaterial3D
			if src:
				var mat := src.duplicate() as StandardMaterial3D
				mat.albedo_color = d.tint
				if d.emissive != Color.BLACK:
					mat.emission_enabled = true
					mat.emission = d.emissive
					mat.emission_energy_multiplier = 0.6
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
				m.set_surface_override_material(0, mat)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_head_bone = _skeleton.find_bone("mixamorig_Head")
		if _head_bone < 0:
			_head_bone = _skeleton.find_bone("mixamorig:Head")
	animator = ZombieAnimator.new()
	animator.setup(_model.find_child("AnimationPlayer", true, false) as AnimationPlayer, self)
	add_child(animator)
	# fake blob shadow (cheap, works on every quality profile)
	_blob = MeshInstance3D.new()
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2(1, 1)
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_texture = _make_blob_tex()
		bm.albedo_color = Color(0, 0, 0, 0.55)
		bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_blob_mesh.material = bm
	_blob.mesh = _blob_mesh
	_blob.scale = Vector3.ONE * d.radius * d.scale * 3.2
	_blob.position.y = 0.03
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob)
	_blob.visible = Settings.quality >= Settings.Quality.MEDIUM
	# navigation
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 0.6
	agent.radius = d.radius * d.scale
	agent.height = d.height * d.scale
	agent.path_max_distance = 3.0
	agent.avoidance_enabled = Settings.quality >= Settings.Quality.MEDIUM
	agent.max_speed = d.run_speed * 1.2
	agent.neighbor_distance = 3.0
	agent.max_neighbors = 5
	agent.time_horizon_agents = 0.6
	add_child(agent)
	agent.velocity_computed.connect(_on_velocity_computed)
	# states
	for s in [ZState_Spawn, ZState_ToBarrier, ZState_BreakBarrier, ZState_Vault, ZState_Chase, ZState_Attack, ZState_Stagger, ZState_Dead]:
		var st: ZombieState = s.new()
		st.zombie = self
		states[st.state_id()] = st
	if d.is_boss:
		boss_brain = BossBrain.new()
		boss_brain.zombie = self
		add_child(boss_brain)
	deactivate()


static func _make_blob_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0, 1) ** 1.5))
	return ImageTexture.create_from_image(img)


# --------------------------------------------------------------------------------
# pooling
# --------------------------------------------------------------------------------

func activate(at: Transform3D, round_number: int, player: Player, sp: SpawnPoint, sprint: bool) -> void:
	global_transform = at
	round_spawned = round_number
	target = player
	spawn_point = sp
	barrier = sp.barricade if sp else null
	max_health = data.health_for_round(round_number)
	health = max_health
	running = sprint
	speed = (data.run_speed if sprint else data.walk_speed) * randf_range(0.92, 1.08)
	_alive = true
	_burn_time = 0.0
	_stagger_cd = 0.0
	_groan_t = randf_range(1.0, 5.0)
	visible = true
	_shape.disabled = false
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector3.ZERO
	_set_burn_visual(false)
	animator.reset()
	if boss_brain:
		boss_brain.call("reset")
	change_state("spawn")


func deactivate() -> void:
	_alive = false
	visible = false
	_shape.disabled = true
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = Vector3(0, -200, 0)
	if state:
		state.exit()
	state = null
	state_name = ""


func is_alive() -> bool:
	return _alive


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED


# --------------------------------------------------------------------------------
# state machine
# --------------------------------------------------------------------------------

func change_state(id: String) -> void:
	if state:
		state.exit()
	state = states.get(id)
	state_name = id
	if state:
		state.enter()


func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)
	if _alive:
		_update_burn(delta)
		_stagger_cd = maxf(0.0, _stagger_cd - delta)
		_groan_t -= delta
		if _groan_t <= 0.0:
			_groan_t = randf_range(3.0, 7.0)
			if target and global_position.distance_to(target.global_position) < 22.0:
				Audio.play_at(data.groan_sound, global_position + Vector3.UP * 1.5, -6.0, 0.15, 26.0, 150)
	animator.lod_update(delta)


# --------------------------------------------------------------------------------
# movement helpers used by states
# --------------------------------------------------------------------------------

func set_nav_target(pos: Vector3, force: bool = false) -> void:
	if force or _repath_timer <= 0.0:
		agent.target_position = pos
		var d := global_position.distance_to(pos)
		# far zombies repath less often: spreads path queries across frames
		_repath_timer = clampf(d * 0.04, 0.25, 1.2) + randf() * 0.15


func move_along_path(delta: float, move_speed: float) -> void:
	_repath_timer -= delta
	var next := agent.get_next_path_position()
	var to := next - global_position
	to.y = 0.0
	var desired := Vector3.ZERO
	if to.length() > 0.05:
		desired = to.normalized() * move_speed
	if agent.avoidance_enabled:
		agent.velocity = desired
	else:
		_apply_velocity(desired, delta)
	_face(desired if desired.length() > 0.1 else (target.global_position - global_position if target else Vector3.ZERO), delta)
	# stuck detection: nudge sideways if not progressing
	_stuck_t += delta
	if _stuck_t > 1.0:
		if global_position.distance_to(_last_pos) < 0.2 and desired.length() > 0.1:
			velocity += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2.0
			_repath_timer = 0.0
		_last_pos = global_position
		_stuck_t = 0.0


func move_direct(delta: float, dir: Vector3, move_speed: float) -> void:
	dir.y = 0
	var desired := dir.normalized() * move_speed if dir.length() > 0.01 else Vector3.ZERO
	_apply_velocity(desired, delta)
	_face(dir, delta)


func _on_velocity_computed(safe: Vector3) -> void:
	if _alive and state and state.uses_navigation():
		_apply_velocity(safe, get_physics_process_delta_time())


func _apply_velocity(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()


func stand_still(delta: float) -> void:
	_apply_velocity(Vector3.ZERO, delta)


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 8.0))


func face_point(p: Vector3, delta: float) -> void:
	_face(p - global_position, delta)


func distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if target else INF


func can_see_target() -> bool:
	if target == null:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, target.global_position + Vector3.UP * 1.4, 1)
	return space.intersect_ray(q).is_empty()


# --------------------------------------------------------------------------------
# combat
# --------------------------------------------------------------------------------

func is_headshot(point: Vector3) -> bool:
	if _skeleton and _head_bone >= 0:
		var hp := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone).origin
		return point.distance_to(hp + Vector3.UP * 0.08 * data.scale) < 0.3 * data.scale
	return point.y - global_position.y > (data.head_height - 0.15) * data.scale


func take_hit(amount: float, pos: Vector3, dir: Vector3, headshot: bool, source: Node = null, explosive: bool = false) -> bool:
	if not _alive:
		return false
	var dmg := amount
	if not headshot and not explosive:
		dmg *= (1.0 - data.armor)
	if headshot and data.armor > 0.0:
		FX.impact(pos, -dir if dir != Vector3.ZERO else Vector3.UP, "metal")
	health -= dmg
	if health <= 0.0:
		_die(headshot, explosive)
		return true
	GameState.add_points(data.points_hit)
	if boss_brain:
		boss_brain.call("on_damaged", dmg)
	var chance := clampf(dmg / max_health * 4.0, 0.15, 1.0) * (1.0 - data.stagger_resist)
	if _stagger_cd <= 0.0 and randf() < chance and state_name in ["chase", "attack"]:
		_stagger_cd = 1.4
		change_state("stagger")
	return false


func ignite(dps: float, duration: float, source: Node) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)
	_burn_source = source
	_set_burn_visual(true)


func _update_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	health -= _burn_dps * delta
	if randf() < delta * 6.0:
		FX.impact(global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 1.6) * data.scale, randf_range(-0.2, 0.2)), Vector3.UP, "metal")
	if health <= 0.0:
		_die(false, true)
	elif _burn_time <= 0.0:
		_set_burn_visual(false)


func _set_burn_visual(on: bool) -> void:
	if on and _burn_overlay == null:
		_burn_overlay = StandardMaterial3D.new()
		_burn_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burn_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_burn_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_burn_overlay.albedo_color = Color(1.0, 0.4, 0.1, 0.35)
	for m in _mesh_instances:
		m.material_overlay = _burn_overlay if on else null


func _die(headshot: bool, explosive: bool) -> void:
	_alive = false
	health = 0.0
	_burn_time = 0.0
	var pts := data.points_kill + (data.points_headshot_bonus if headshot else 0)
	GameState.add_points(pts)
	GameState.register_kill(headshot)
	FX.zombie_death(global_position + Vector3.UP * data.height * data.scale * 0.5, Color(0.55, 0.95, 0.3) if not data.is_boss else Color(0.4, 1.0, 0.2))
	Audio.play_at("zombie_death", global_position + Vector3.UP, -3.0, 0.15, 30.0)
	if headshot:
		FX.blood(global_position + Vector3.UP * data.head_height * data.scale, Vector3.UP, 1.0)
	change_state("dead")
	died.emit(self, headshot)
