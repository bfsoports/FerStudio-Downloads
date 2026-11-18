class_name Player
extends CharacterBody3D
## First-person survivor: movement, camera, health/regeneration, perks,
## interaction targeting and grenades. Weapons live in WeaponHolder.

signal health_changed(current: float, maximum: float)
signal damaged(from_dir: Vector3, amount: float)
signal died
signal perks_changed(perks: Array)
signal interact_target_changed(target: Interactable)
signal grenades_changed(count: int)
signal sprint_changed(sprinting: bool)

const WALK_SPEED := 4.7
const SPRINT_MULT := 1.38
const ADS_MULT := 0.6
const ACCEL := 14.0
const AIR_ACCEL := 4.0
const JUMP_VELOCITY := 4.6
const GRAVITY := 13.0
const EYE_HEIGHT := 1.62
const INTERACT_RANGE := 2.4
const MAX_GRENADES := 4

var max_health := 100.0
var health := 100.0
var alive := true
var perks: Array[String] = []
var grenades := 2

# input state, written by TouchControls / desktop input
var move_input := Vector2.ZERO
var look_input := Vector2.ZERO
var wants_sprint := false
var fire_held := false

var head: Node3D
var camera: Camera3D
var weapons: WeaponHolder
var current_target: Interactable

var _pitch := 0.0
var _regen_delay := 0.0
var _hurt_cooldown := 0.0
var _shake_strength := 0.0
var _shake_time := 0.0
var _bob_t := 0.0
var _step_t := 0.0
var _interact_scan := 0.0
var _sprinting := false
var _base_fov := 75.0
var _land_kick := 0.0
var _was_on_floor := true


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 32
	floor_max_angle = deg_to_rad(50)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = _base_fov
	camera.near = 0.03
	camera.far = Settings.view_distance() + 20.0
	camera.current = true
	head.add_child(camera)
	weapons = WeaponHolder.new()
	weapons.name = "WeaponHolder"
	camera.add_child(weapons)
	weapons.setup(self)
	FX.shake_requested.connect(_on_shake)
	health = max_health
	_setup_desktop_actions()


func _setup_desktop_actions() -> void:
	var map := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "reload": KEY_R, "interact": KEY_E, "switch_weapon": KEY_Q,
		"grenade": KEY_G, "sprint": KEY_SHIFT, "pause": KEY_ESCAPE,
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[action]
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------------------------
# frame update
# ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Desktop testing support (mouse look when captured).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input += event.relative * 0.6
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			fire_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			weapons.toggle_aim()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			weapons.switch_next()


func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	_read_desktop_keys()
	_apply_look()
	_move(delta)
	_update_regen(delta)
	_update_camera_fx(delta)
	_interact_scan -= delta
	if _interact_scan <= 0.0:
		_interact_scan = 0.1
		_scan_interactables()
	if fire_held:
		weapons.try_fire()


func _read_desktop_keys() -> void:
	if OS.has_feature("mobile"):
		return
	var k := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
	if k != Vector2.ZERO:
		move_input = k.limit_length(1.0)
		wants_sprint = Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("jump"):
		jump()
	if Input.is_action_just_pressed("reload"):
		weapons.reload()
	if Input.is_action_just_pressed("switch_weapon"):
		weapons.switch_next()
	if Input.is_action_just_pressed("grenade"):
		throw_grenade()
	if Input.is_action_just_pressed("interact"):
		interact()


func _apply_look() -> void:
	if look_input == Vector2.ZERO:
		return
	var sens := Settings.look_sensitivity * 0.12
	if weapons.aiming:
		sens *= Settings.aim_sensitivity * weapons.ads_zoom_factor()
	rotate_y(deg_to_rad(-look_input.x * sens))
	var dy := look_input.y * sens * (-1.0 if Settings.invert_y else 1.0)
	_pitch = clampf(_pitch - dy, -85.0, 85.0)
	look_input = Vector2.ZERO


func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_pitch = clampf(_pitch + pitch_deg, -85.0, 85.0)
	rotate_y(deg_to_rad(yaw_deg))


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= GRAVITY * delta
	elif not _was_on_floor and velocity.y < -3.0:
		_land_kick = 0.06
		Audio.play("land", -8.0)
	_was_on_floor = on_floor
	var input := move_input
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var speed := WALK_SPEED * weapons.move_speed_mult()
	if has_perk("speed"):
		speed *= 1.18
	var sprint := wants_sprint and input.y < -0.6 and not weapons.aiming and on_floor
	if sprint != _sprinting:
		_sprinting = sprint
		sprint_changed.emit(sprint)
	if sprint:
		speed *= SPRINT_MULT
	elif weapons.aiming:
		speed *= ADS_MULT
	var target := dir * speed
	var a := ACCEL if on_floor else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, a * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, a * speed * delta)
	move_and_slide()
	# footsteps & head bob
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if on_floor and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.8
		_step_t -= delta * hspeed
		if _step_t <= 0.0:
			_step_t = 2.1
			Audio.play("step", -14.0, 0.12)
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 6.0)


func is_sprinting() -> bool:
	return _sprinting


func jump() -> void:
	if alive and is_on_floor():
		velocity.y = JUMP_VELOCITY
		Audio.play("jump", -10.0)


func _update_camera_fx(delta: float) -> void:
	var bob := Vector3(cos(_bob_t * 0.5) * 0.03, absf(sin(_bob_t)) * 0.045, 0.0)
	if weapons.aiming:
		bob *= 0.25
	_land_kick = move_toward(_land_kick, 0.0, delta * 0.4)
	var shake := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_strength * 0.05
	head.position = Vector3(0, EYE_HEIGHT - _land_kick, 0) + bob + shake
	head.rotation.x = deg_to_rad(_pitch)
	var fov_target := weapons.target_fov(_base_fov)
	if _sprinting:
		fov_target += 6.0
	camera.fov = lerpf(camera.fov, fov_target, delta * 12.0)


func _on_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(strength, _shake_strength if _shake_time > 0 else 0.0)
	_shake_time = maxf(duration, _shake_time)


# ---------------------------------------------------------------------------------
# health
# ---------------------------------------------------------------------------------

func take_damage(amount: float, from_pos: Vector3) -> void:
	if not alive or _hurt_cooldown > 0.0:
		return
	health -= amount
	_regen_delay = 2.4 if has_perk("regen") else 4.0
	_hurt_cooldown = 0.12
	var dir := (from_pos - global_position)
	dir.y = 0
	damaged.emit(dir.normalized(), amount)
	health_changed.emit(health, max_health)
	_on_shake(0.6, 0.2)
	Audio.play("player_hurt", -2.0, 0.1)
	Audio.vibrate(60)
	if health <= 0.0:
		health = 0.0
		_die()


func _update_regen(delta: float) -> void:
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	if health >= max_health:
		return
	_regen_delay -= delta
	if _regen_delay <= 0.0:
		var rate := 60.0 if has_perk("regen") else 30.0
		health = minf(max_health, health + rate * delta)
		health_changed.emit(health, max_health)


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _die() -> void:
	alive = false
	fire_held = false
	weapons.set_dead()
	Audio.play("player_death", 0.0)
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(head, "rotation:z", deg_to_rad(70), 1.2)
	died.emit()


# ---------------------------------------------------------------------------------
# perks
# ---------------------------------------------------------------------------------

func has_perk(id: String) -> bool:
	return perks.has(id)


func add_perk(id: String) -> void:
	if perks.has(id):
		return
	perks.append(id)
	if id == "vitality":
		max_health = 200.0
		health = max_health
		health_changed.emit(health, max_health)
	perks_changed.emit(perks)


func damage_multiplier() -> float:
	return 1.3 if has_perk("damage") else 1.0


func reload_multiplier() -> float:
	return 0.5 if has_perk("quick_reload") else 1.0


# ---------------------------------------------------------------------------------
# interaction
# ---------------------------------------------------------------------------------

func _scan_interactables() -> void:
	var best: Interactable = null
	var best_score := -INF
	var eye := camera.global_position
	var fwd := -camera.global_basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_available(self):
			continue
		var p := it.focus_point()
		var to := p - eye
		var d := to.length()
		if d > it.interact_radius + 0.6:
			continue
		var facing := fwd.dot(to / maxf(d, 0.001))
		if facing < 0.15 and d > 1.0:
			continue
		var score := facing * 2.0 - d
		if score > best_score:
			best_score = score
			best = it
	if best != current_target:
		current_target = best
		interact_target_changed.emit(best)


func interact() -> void:
	if alive and current_target and current_target.is_available(self):
		current_target.interact(self)
		interact_target_changed.emit(current_target)


func interact_hold(active: bool) -> void:
	if current_target:
		current_target.hold(self, active)


# ---------------------------------------------------------------------------------
# grenades
# ---------------------------------------------------------------------------------

func add_grenades(n: int) -> void:
	grenades = mini(MAX_GRENADES, grenades + n)
	grenades_changed.emit(grenades)


func throw_grenade() -> void:
	if not alive or grenades <= 0 or weapons.busy():
		return
	grenades -= 1
	grenades_changed.emit(grenades)
	var g := Grenade.new()
	get_tree().current_scene.add_child(g)
	var fwd := -camera.global_basis.z
	g.global_position = camera.global_position + fwd * 0.6 + Vector3.DOWN * 0.15
	g.launch(fwd * 15.0 + Vector3.UP * 3.5 + velocity * 0.5, self)
	weapons.play_throw()
	Audio.play("grenade_throw", -4.0)
