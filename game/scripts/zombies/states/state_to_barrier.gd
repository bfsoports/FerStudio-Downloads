class_name ZState_ToBarrier
extends ZombieState
## Walks (outside the play area) to the window it has to break through.


func state_id() -> String:
	return "to_barrier"


func uses_navigation() -> bool:
	return true


func enter() -> void:
	zombie.set_nav_target(zombie.barrier.outside_point(), true)
	_play_move_anim()


func _play_move_anim() -> void:
	var clip := zombie.data.anim_run if zombie.running else zombie.data.anim_walk
	var base := 4.6 if zombie.running else 1.1
	zombie.animator.play(clip, 0.25, clampf(zombie.speed / base, 0.6, 1.6))


func physics_update(delta: float) -> void:
	var goal := zombie.barrier.outside_point()
	var flat := Vector2(zombie.global_position.x - goal.x, zombie.global_position.z - goal.z).length()
	if flat < 0.9:
		if zombie.barrier.blocks_zombies():
			zombie.change_state("break_barrier")
		else:
			zombie.change_state("vault")
		return
	if flat < 2.5:
		zombie.move_direct(delta, goal - zombie.global_position, zombie.speed)
	else:
		zombie.set_nav_target(goal)
		zombie.move_along_path(delta, zombie.speed)
