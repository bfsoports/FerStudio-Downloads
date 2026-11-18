class_name ZState_Chase
extends ZombieState
## Hunts the player across the navigation mesh.

var _walk_clip := ""


func state_id() -> String:
	return "chase"


func uses_navigation() -> bool:
	return true


func enter() -> void:
	_walk_clip = zombie.data.anim_walk if randf() < 0.6 else zombie.data.anim_walk_alt
	_update_anim()
	if zombie.target:
		zombie.set_nav_target(zombie.target.global_position, true)


func _update_anim() -> void:
	var clip := zombie.data.anim_run if zombie.running else _walk_clip
	var base := 4.6 if zombie.running else 1.1
	zombie.animator.play(clip, 0.25, clampf(zombie.speed / base, 0.6, 1.7))


func physics_update(delta: float) -> void:
	var t := zombie.target
	if t == null or not t.alive:
		zombie.stand_still(delta)
		zombie.animator.play(zombie.data.anim_idle, 0.4)
		return
	if zombie.boss_brain and zombie.boss_brain.call("think", delta):
		return
	var d := zombie.distance_to_target()
	if d <= zombie.data.attack_range * zombie.data.scale * 0.85 + 0.3:
		zombie.change_state("attack")
		return
	_update_anim()
	if d < 2.2 and absf(t.global_position.y - zombie.global_position.y) < 1.0:
		zombie.move_direct(delta, t.global_position - zombie.global_position, zombie.speed)
	else:
		zombie.set_nav_target(t.global_position)
		zombie.move_along_path(delta, zombie.speed)
