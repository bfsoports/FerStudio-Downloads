class_name ZState_Dead
extends ZombieState
## Death animation, then sink into the ground and return to the pool.

var _t := 0.0
var _sinking := false


func state_id() -> String:
	return "dead"


func enter() -> void:
	var clip := zombie.data.anim_death if randf() < 0.55 else zombie.data.anim_death_alt
	zombie.animator.play(clip, 0.1, 1.25, true)
	zombie.collision_layer = 0
	zombie.collision_mask = 1
	zombie.velocity = Vector3.ZERO
	_t = 2.6 if not zombie.data.is_boss else 4.0
	_sinking = false


func exit() -> void:
	zombie.collision_layer = 4
	zombie.collision_mask = 1 | 4 | 32


func physics_update(delta: float) -> void:
	_t -= delta
	if _t <= 0.0 and not _sinking:
		_sinking = true
		_t = 1.2
	if _sinking:
		zombie.global_position.y -= delta * 0.8
		if _t <= 0.0:
			ZombiePool.release(zombie)
