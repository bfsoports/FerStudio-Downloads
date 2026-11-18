class_name ZombieAnimator
extends Node
## Thin wrapper over the imported AnimationPlayer:
## logical clips -> per-archetype clip names, cross-fades, speed scaling and
## animation LOD (distant / off-screen zombies are updated at a lower rate).

var player: AnimationPlayer
var zombie: Zombie
var current := ""
var _accum := 0.0
var _frame := 0
var _lod_step := 1
var _cam: Camera3D


func setup(ap: AnimationPlayer, z: Zombie) -> void:
	player = ap
	zombie = z
	if player == null:
		push_warning("Zombie model has no AnimationPlayer: %s" % z.data.model_path)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for loop_name in ["idle", "walk", "walk2", "run", "roar"]:
		if player.has_animation(loop_name):
			var a := player.get_animation(loop_name)
			a.loop_mode = Animation.LOOP_LINEAR if loop_name != "roar" else Animation.LOOP_NONE
	for once in ["attack", "attack2", "attack_jab", "attack_slam", "hit", "hit2", "death", "death2", "rise"]:
		if player.has_animation(once):
			player.get_animation(once).loop_mode = Animation.LOOP_NONE


func reset() -> void:
	current = ""
	_frame = randi() % 4


func play(clip: String, blend: float = 0.2, speed: float = 1.0, restart: bool = false) -> void:
	if player == null or not player.has_animation(clip):
		return
	if clip == current and not restart:
		player.speed_scale = speed
		return
	current = clip
	player.play(clip, blend, speed)
	if restart:
		player.seek(0.0, false)


func length_of(clip: String) -> float:
	if player and player.has_animation(clip):
		return player.get_animation(clip).length
	return 1.0


func lod_update(delta: float) -> void:
	if player == null:
		return
	if _cam == null or not is_instance_valid(_cam):
		_cam = zombie.get_viewport().get_camera_3d()
	var step := 1
	if _cam:
		var to := zombie.global_position - _cam.global_position
		var d := to.length()
		var full := Settings.zombie_anim_full_rate_distance()
		var in_front := (-_cam.global_basis.z).dot(to / maxf(d, 0.01)) > -0.2
		if not in_front:
			step = 6
		elif d > full * 2.0:
			step = 3
		elif d > full:
			step = 2
	_accum += delta
	_frame += 1
	if _frame % step == 0:
		player.advance(_accum)
		_accum = 0.0
