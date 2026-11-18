class_name PlayerController
extends CharacterBody3D
## Jugador en primera persona: movimiento con aceleración, colisiones y gravedad; cámara con límite vertical;
## detección de objetos por un rayo físico desde la cámara (no atraviesa paredes) y transporte de objetos.

const WALK_SPEED := 4.4
const ACCEL := 20.0
const DECEL := 26.0
const GRAVITY := 24.0
const PITCH_LIMIT := 1.3
const TOUCH_LOOK := 0.0032
const MOUSE_LOOK := 0.0022

var touch: TouchControls = null
var controls_enabled: bool = false
var held: Carryable = null
var distance_walked: float = 0.0
var look_total: float = 0.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _target: Interactable = null
var _last_prompt_key: String = "-"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hold_point: Marker3D = $Head/Camera3D/HoldPoint

func _ready() -> void:
	collision_layer = Const.LAYER_PLAYER
	collision_mask = Const.LAYER_WORLD
	ray.collision_mask = Const.LAYER_WORLD | Const.LAYER_INTERACT
	ray.target_position = Vector3(0.0, 0.0, -Const.REACH)
	ray.enabled = true
	camera.current = true

func setup(touch_controls: TouchControls) -> void:
	touch = touch_controls
	if touch != null and not touch.interact_pressed.is_connected(try_interact):
		touch.interact_pressed.connect(try_interact)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if controls_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch != null and touch.move_vector.length() > 0.01:
			dir = touch.move_vector
	var wish := global_transform.basis * Vector3(dir.x, 0.0, dir.y)
	wish.y = 0.0
	var target_vel := wish * WALK_SPEED
	var rate := ACCEL if dir.length() > 0.01 else DECEL
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	move_and_slide()
	distance_walked += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_update_target()

func _process(_delta: float) -> void:
	if controls_enabled and touch != null:
		var rel := touch.consume_look()
		if rel != Vector2.ZERO:
			apply_look(rel * TOUCH_LOOK * SettingsManager.sensitivity)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look((event as InputEventMouseMotion).relative * MOUSE_LOOK * SettingsManager.sensitivity)
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_interact()

func apply_look(rel: Vector2) -> void:
	_yaw -= rel.x
	var sy := -1.0 if SettingsManager.invert_y else 1.0
	_pitch = clampf(_pitch - rel.y * sy, -PITCH_LIMIT, PITCH_LIMIT)
	rotation.y = _yaw
	head.rotation.x = _pitch
	look_total += absf(rel.x) + absf(rel.y)

# ------------------------------------------------------------------ interacción
func _update_target() -> void:
	var t: Interactable = null
	if controls_enabled:
		ray.force_raycast_update()
		if ray.is_colliding():
			t = ray.get_collider() as Interactable
	_target = t
	var prompt: Dictionary = {}
	if t != null:
		prompt = t.get_prompt(self)
	var key := "%s|%s|%s|%s" % [prompt.get("icon", ""), prompt.get("text", ""), prompt.get("ok", true), prompt.get("args", [])]
	if key != _last_prompt_key:
		_last_prompt_key = key
		Events.prompt_changed.emit(prompt)

func try_interact() -> void:
	if not controls_enabled:
		return
	_update_target()
	if _target != null and is_instance_valid(_target):
		_target.interact(self)

func get_aim_point() -> Vector3:
	if ray.is_colliding():
		return ray.get_collision_point()
	return global_position

# ------------------------------------------------------------------ objetos transportados
func hold(item: Carryable) -> void:
	if held != null:
		return
	var in_tree := item.is_inside_tree()
	var from_t := item.global_transform if in_tree else Transform3D.IDENTITY
	var parent := item.get_parent()
	if parent != null:
		parent.remove_child(item)
	hold_point.add_child(item)
	if in_tree:
		item.global_transform = from_t
	item.set_pickable(false)
	item.station = null
	held = item
	var tw := item.create_tween().set_parallel(true)
	tw.tween_property(item, "position", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "rotation", Vector3.ZERO, 0.14)
	tw.tween_property(item, "scale", Vector3.ONE * item.carry_scale(), 0.14)
	Events.held_changed.emit(item.display_name())

## Suelta lo que lleva en la mano y lo devuelve (el llamador lo coloca o lo elimina).
func release_held() -> Carryable:
	var it := held
	held = null
	Events.held_changed.emit("")
	return it

func reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	rotation.y = 0.0
	head.rotation.x = 0.0
