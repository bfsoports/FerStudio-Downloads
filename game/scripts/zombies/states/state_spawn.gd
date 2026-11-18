class_name ZState_Spawn
extends ZombieState
## Emerges from the ground (or roars, for big archetypes) before hunting.

var _t := 0.0


func state_id() -> String:
	return "spawn"


func enter() -> void:
	var clip := zombie.data.anim_spawn
	var spd := 1.5
	_t = minf(zombie.animator.length_of(clip) / spd, 2.4)
	zombie.animator.play(clip, 0.0, spd, true)
	if zombie.data.is_boss or zombie.data.id == "tank":
		Audio.play_at(zombie.data.groan_sound, zombie.global_position + Vector3.UP * 2.0, 6.0, 0.05, 60.0)
		FX.shake(0.5, 0.6)
	else:
		FX.impact(zombie.global_position + Vector3.UP * 0.1, Vector3.UP, "dirt")


func physics_update(delta: float) -> void:
	zombie.stand_still(delta)
	if zombie.target:
		zombie.face_point(zombie.target.global_position, delta * 0.5)
	_t -= delta
	if _t <= 0.0:
		if zombie.barrier and zombie.barrier.blocks_zombies():
			zombie.change_state("to_barrier")
		elif zombie.barrier:
			zombie.change_state("vault")
		else:
			zombie.change_state("chase")
