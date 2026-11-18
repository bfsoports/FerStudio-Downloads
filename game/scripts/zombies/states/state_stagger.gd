class_name ZState_Stagger
extends ZombieState
## Short flinch after a heavy hit.

var _t := 0.0


func state_id() -> String:
	return "stagger"


func enter() -> void:
	_t = minf(zombie.animator.length_of(zombie.data.anim_hit), 0.6)
	zombie.animator.play(zombie.data.anim_hit, 0.08, 1.0, true)


func physics_update(delta: float) -> void:
	zombie.stand_still(delta)
	_t -= delta
	if _t <= 0.0:
		zombie.change_state("chase")
