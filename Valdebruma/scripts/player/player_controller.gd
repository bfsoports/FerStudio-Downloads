class_name PlayerController
extends CharacterBody3D
## PlayerController — personaje local en primera persona.
##
## Responsabilidad: movimiento con aceleración, carrera, agachado, salto, escalones y
## pendientes; cámara suave con sensibilidad configurable; nado; brazos animados; luz en
## mano; sonda de interacción contextual; envío de la posición al servidor (15 Hz) y
## corrección cuando el servidor rechaza un movimiento. No modifica inventario ni estados.
## Datos: estado de movimiento (flags del Protocol). Señales: target_changed(interactable).
## Autoridad online: predicción local; el servidor valida velocidad, altura y muros.

signal target_changed(target: Interactable)

const WALK := 3.5
const SPRINT := 6.2
const CROUCH := 1.6
const SWIM := 1.7
const JUMP := 5.4
const GRAVITY := 19.0
const STEP := 0.34
const EYE := 1.62
const EYE_CROUCH := 1.02

var world: WorldMap
var head: Node3D
var cam: Camera3D
var arms: Node3D
var arms_anim: AnimationPlayer
var shape: CapsuleShape3D
var coll: CollisionShape3D
var spot: SpotLight3D
var lamp: OmniLight3D
var held: Node3D
var yaw := 0.0
var pitch := 0.0
var crouched := false
var swimming := false
var light_on := false
var frozen := false
var down := false
var stamina := 100.0
var target: Interactable = null
var water_target := false
var indoors := false
var _seq := 0
var _send_acc := 0.0
var _step_acc := 0.0
var _bob := 0.0
var _eye := EYE
var _land := 0.0
var _was_floor := true
var _fall_speed := 0.0
var _one_shot := ""
var _one_shot_until := 0
var _held_id := "-"
var _probe_acc := 0.0
var _border_note := 0

func _ready() -> void:
	world = GameData.world
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(47.0)
	floor_snap_length = 0.4
	shape = CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.78
	coll = CollisionShape3D.new()
	coll.shape = shape
	coll.position.y = 0.89
	add_child(coll)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.06
	cam.far = 900.0
	head.add_child(cam)
	cam.current = true
	arms = AssetLib.model("characters/fp_arms")
	cam.add_child(arms)
	arms_anim = arms.find_child("AnimationPlayer", true, false)
	CharacterLook.fix_loops(arms_anim, "res://data/models/fp_arms.json")
	CharacterLook.tint(arms, Profile.cosmetics, false)
	for mi: Node in arms.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot = SpotLight3D.new()
	spot.spot_range = 26.0
	spot.spot_angle = 26.0
	spot.light_energy = 3.2
	spot.light_color = Color(1.0, 0.95, 0.84)
	spot.shadow_enabled = false
	spot.position = Vector3(0.18, -0.12, -0.2)
	spot.visible = false
	cam.add_child(spot)
	lamp = OmniLight3D.new()
	lamp.omni_range = 9.0
	lamp.light_energy = 1.6
	lamp.light_color = Color(1.0, 0.8, 0.52)
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.22, -0.2, -0.4)
	lamp.visible = false
	cam.add_child(lamp)
	Controls.pressed.connect(_on_pressed)
	Session.corrected.connect(_on_corrected)
	Session.inventory_changed.connect(_refresh_held)
	Session.notified.connect(_on_notify)
	Session.action_changed.connect(_on_action)
	Session.went_down.connect(func(_w: float) -> void: down = true)
	Session.respawned.connect(func(p: Vector3) -> void:
		down = false
		global_position = p)
	_refresh_held()

func place(pos: Vector3, facing: float) -> void:
	global_position = pos
	yaw = facing
	rotation.y = yaw
	velocity = Vector3.ZERO

func _on_pressed(action: String) -> void:
	if frozen or down or Controls.blocked:
		return
	match action:
		"jump":
			if is_on_floor() and not crouched and not swimming:
				velocity.y = JUMP
			elif crouched:
				_set_crouch(false)
		"crouch":
			_set_crouch(not crouched)
		"interact":
			_do_interact(false)
		"interact2":
			_do_interact(true)
		"light":
			if Session.equipped("mano") == "linterna":
				light_on = not light_on
				AudioDirector.play_ui("ui_click")

func _do_interact(secondary: bool) -> void:
	if target != null and is_instance_valid(target):
		if secondary:
			if target.prompt2() != "":
				target.interact2()
				play_arms("fp_interact", 0.6)
		else:
			target.interact()
			play_arms("fp_pickup" if target is Interactables.Pickup else ("fp_door" if target is Interactables.Door else "fp_interact"), 0.8)
	elif water_target:
		Session.request_interact(Protocol.I.WATER_FILL if secondary else Protocol.I.WATER_DRINK, 0)
		play_arms("fp_consume" if not secondary else "fp_pickup", 1.4)

func _on_notify(code: String, _params: Dictionary) -> void:
	match code:
		"used": play_arms("fp_consume", 1.6)
		"creature_hit":
			_land = 0.25
			AudioDirector.play_ui("hit")

func _on_action(code: int, _id: int, seconds: float) -> void:
	if code == Protocol.T.NONE:
		_one_shot_until = 0
	elif code in [Protocol.T.BUILD, Protocol.T.DISMANTLE]:
		play_arms("fp_build", seconds)
	else:
		play_arms("fp_search", seconds)

func play_arms(clip: String, seconds: float) -> void:
	_one_shot = clip
	_one_shot_until = Time.get_ticks_msec() + int(seconds * 1000.0)

func _set_crouch(on: bool) -> void:
	if on == crouched:
		return
	if not on:      # ¿hay sitio para levantarse?
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.95, 0), 1)
		if not space.intersect_ray(q).is_empty():
			return
	crouched = on
	shape.height = 1.15 if on else 1.78
	coll.position.y = shape.height * 0.5

func _on_corrected(_seq_id: int, pos: Vector3, why: String) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if why == "limite" and Time.get_ticks_msec() - _border_note > 4000:
		_border_note = Time.get_ticks_msec()
		Session.notified.emit("border", {})

func _refresh_held() -> void:
	var id := Session.equipped("mano")
	if id == _held_id:
		return
	_held_id = id
	if held != null:
		held.queue_free()
		held = null
	if id != "":
		var sk: Skeleton3D = arms.find_child("Skeleton3D", true, false)
		if sk != null:
			var att := BoneAttachment3D.new()
			att.bone_name = "item.R"
			sk.add_child(att)
			var m := AssetLib.model("items/" + id)
			m.rotation_degrees = Vector3(0, 90, 0) if id in ["linterna", "hachuela", "martillo", "palanca", "espantador"] else Vector3.ZERO
			m.position = Vector3(0, -0.02, 0)
			att.add_child(m)
			held = att
	if id != "linterna":
		light_on = false

func flags() -> int:
	var f := 0
	if crouched:
		f |= Protocol.F_CROUCH
	if Controls.sprint and velocity.length() > 4.2:
		f |= Protocol.F_SPRINT
	if is_on_floor():
		f |= Protocol.F_ON_FLOOR
	if spot.visible or lamp.visible:
		f |= Protocol.F_LIGHT
	if swimming:
		f |= Protocol.F_SWIM
	return f

func _physics_process(delta: float) -> void:
	if frozen:
		return
	# ---- cámara ----
	var look := Controls.consume_look()
	if not down:
		yaw -= deg_to_rad(look.x * Config.f("control", "sens_h"))
		var dy := look.y * Config.f("control", "sens_v") * (-1.0 if Config.b("control", "invert_y") else 1.0)
		pitch = clampf(pitch - deg_to_rad(dy), -1.45, 1.45)
	rotation.y = yaw
	# ---- estado ----
	var srv_sta := float(Session.stats.get("sta", 100.0))
	stamina = lerpf(stamina, srv_sta, clampf(delta * 2.0, 0.0, 1.0))
	var can_sprint := stamina > 2.0 and not Session.has_effect("agotado") and not crouched
	var wdepth := world.water_depth(global_position.x, global_position.z)
	var deck := (world.cell_flags(global_position.x, global_position.z) & WorldMap.F_DECK) != 0
	swimming = wdepth > 1.25 and global_position.y < world.water_level - 0.9 and not deck
	var speed := WALK
	if swimming:
		speed = SWIM
	elif crouched:
		speed = CROUCH
	elif Controls.sprint and can_sprint and Controls.move.y > 0.3:
		speed = SPRINT
		stamina = maxf(0.0, stamina - 9.0 * delta)
	elif wdepth > 0.35 and not deck:
		speed = WALK * 0.6
	if Session.has_effect("aturdido"):
		speed *= 0.6
	if float(Session.stats.get("w", 0.0)) > float(Session.stats.get("wmax", 22.0)):
		speed *= 0.7
	var wish := Vector3.ZERO
	if not down:
		wish = (global_transform.basis * Vector3(Controls.move.x, 0, -Controls.move.y))
		wish.y = 0
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 11.0 if is_on_floor() else 3.0
	hv = hv.move_toward(wish * speed, accel * speed * delta) if wish.length() > 0.01 else hv.move_toward(Vector3.ZERO, (13.0 if is_on_floor() else 2.0) * maxf(speed, 2.0) * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if swimming:
		var surface_y := world.water_level - 1.3
		velocity.y = clampf((surface_y - global_position.y) * 4.0, -2.0, 2.0)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	_fall_speed = velocity.y if not is_on_floor() else _fall_speed
	_step_up(delta)
	move_and_slide()
	if is_on_floor() and not _was_floor:
		_land = clampf(-_fall_speed * 0.03, 0.05, 0.3)
		AudioDirector.footstep(_surface(), global_position, 4.0)
	_was_floor = is_on_floor()
	# ---- presentación ----
	_eye = lerpf(_eye, EYE_CROUCH if crouched else EYE, clampf(delta * 9.0, 0.0, 1.0))
	_land = maxf(0.0, _land - delta * 0.9)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector3.ZERO
	if Config.b("control", "head_bob") and not Config.b("access", "reduce_motion") and is_on_floor() and flat_speed > 0.4:
		_bob += delta * flat_speed * 1.9
		bob = Vector3(sin(_bob * 0.5) * 0.018, absf(sin(_bob)) * 0.03 - 0.015, 0)
	head.position = Vector3(bob.x, _eye + bob.y - _land, 0)
	head.rotation.x = pitch
	cam.fov = lerpf(cam.fov, 78.0 if speed >= SPRINT and flat_speed > 4.5 and not Config.b("access", "reduce_motion") else 72.0, clampf(delta * 5.0, 0.0, 1.0))
	if is_on_floor() and flat_speed > 0.8:
		_step_acc += flat_speed * delta
		if _step_acc > (1.25 if speed < SPRINT else 1.7):
			_step_acc = 0.0
			AudioDirector.footstep(_surface(), global_position, -4.0 if crouched else (3.0 if speed >= SPRINT else 0.0))
	var hand := Session.equipped("mano")
	spot.visible = hand == "linterna" and light_on and Session.equipped_charge("mano") > 0
	lamp.visible = hand == "farol" and Session.equipped_charge("mano") > 0
	_update_arms(flat_speed, speed)
	# ---- red ----
	_send_acc += delta
	if _send_acc >= 1.0 / float(Protocol.MOVE_HZ) and Session.active and not down:
		_send_acc = 0.0
		_seq += 1
		var p := global_position
		Net.send(Protocol.C.MOVE, [_seq, p.x, p.y, p.z, yaw, pitch, flags()], false)
	_probe_acc += delta
	if _probe_acc > 0.08:
		_probe_acc = 0.0
		_probe()

func _surface() -> String:
	if indoors:
		return "wood"
	return world.surface(global_position.x, global_position.z)

func _step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.004 or not test_move(global_transform, motion):
		return
	var up := Vector3(0, STEP, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion * 1.6):
		return
	var hit := KinematicCollision3D.new()
	var over := raised.translated(motion * 1.6)
	if test_move(over, -up * 1.1, hit):
		var n := hit.get_normal()
		if n.y > 0.72:
			global_position = over.origin + hit.get_travel()

func _update_arms(flat_speed: float, speed: float) -> void:
	if arms_anim == null:
		return
	var clip := "fp_idle"
	if Time.get_ticks_msec() < _one_shot_until:
		clip = _one_shot
	elif Session.container_key >= 0:
		clip = "fp_search"
	elif _held_id in ["linterna", "farol"]:
		clip = "fp_hold"
	elif flat_speed > 4.6 and speed >= SPRINT:
		clip = "fp_sprint"
	elif flat_speed > 0.6:
		clip = "fp_walk"
	elif Session.has_effect("frio"):
		clip = "fp_cold"
	elif Session.has_effect("agotado"):
		clip = "fp_tired"
	if arms_anim.current_animation != clip and arms_anim.has_animation(clip):
		arms_anim.play(clip, 0.22)
	arms.visible = not down

## Busca el mejor objeto interactivo: distancia, ángulo respecto a la mira, prioridad y visibilidad.
func _probe() -> void:
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var best: Interactable = null
	var best_score := -1e9
	for it: Interactable in WorldRoot.interactables:
		if not it.is_visible_in_tree() or not it.available():
			continue
		var fp := it.focus_point()
		var to := fp - origin
		var d := to.length()
		if d > it.reach + 0.6 or d < 0.05:
			continue
		var ang := rad_to_deg(fwd.angle_to(to))
		var allowed := clampf(40.0 / maxf(d, 0.6), 9.0, 38.0)
		if ang > allowed:
			continue
		if it.prompt() == "":
			continue
		var score := float(it.priority) * 6.0 - ang - d * 2.0
		if score > best_score:
			var q := PhysicsRayQueryParameters3D.create(origin, fp - to.normalized() * minf(0.5, d * 0.5), 1)
			q.exclude = [get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				best = it
				best_score = score
	water_target = false
	if best == null and pitch < -0.35 and not swimming:
		var ahead := global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 1.8
		water_target = world.height(ahead.x, ahead.z) < world.water_level - 0.05 and absf(global_position.y - world.water_level) < 2.2
	if best != target:
		if target != null and is_instance_valid(target):
			target.set_highlight(false)
		target = best
		if target != null:
			target.set_highlight(true)
		target_changed.emit(target)
	indoors = world.building_at(global_position + Vector3(0, 0.6, 0)) >= 0
