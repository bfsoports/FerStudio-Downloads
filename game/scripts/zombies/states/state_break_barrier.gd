class_name ZState_BreakBarrier
extends ZombieState
## Tears planks off a window, one per attack, until the way is open.

var _t := 0.0
var _has_slot := false


func state_id() -> String:
	return "break_barrier"


func enter() -> void:
	_t = randf_range(0.3, 0.8)
	_has_slot = zombie.barrier.request_slot(zombie)
	zombie.animator.play(zombie.data.anim_idle, 0.25)


func exit() -> void:
	if _has_slot:
		zombie.barrier.release_slot(zombie)
	_has_slot = false


func physics_update(delta: float) -> void:
	var b := zombie.barrier
	zombie.stand_still(delta)
	zombie.face_point(b.inside_point(), delta)
	if not b.blocks_zombies():
		zombie.change_state("vault")
		return
	if not _has_slot:
		_has_slot = b.request_slot(zombie)
		return
	_t -= delta
	if _t <= 0.0:
		_t = maxf(1.1, zombie.data.attack_cooldown * 1.1)
		zombie.animator.play(zombie.data.anim_attack, 0.15, 1.2, true)
		zombie.get_tree().create_timer(0.45).timeout.connect(_rip)


func _rip() -> void:
	if zombie.is_alive() and zombie.state_name == "break_barrier":
		zombie.barrier.remove_plank()
