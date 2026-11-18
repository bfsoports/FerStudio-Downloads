class_name ZombieState
extends RefCounted
## Base class for zombie behaviour states.

var zombie: Zombie


func state_id() -> String:
	return ""


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func uses_navigation() -> bool:
	return false
