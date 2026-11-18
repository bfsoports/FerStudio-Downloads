class_name ZState_Vault
extends ZombieState
## Climbs through the (now open) window into the play area.

var _t := 0.0
var _dur := 1.0
var _from: Vector3
var _to: Vector3


func state_id() -> String:
	return "vault"


func enter() -> void:
	_from = zombie.global_position
	_to = zombie.barrier.inside_point()
	_dur = clampf(_from.distance_to(_to) / maxf(zombie.speed, 1.2), 0.7, 1.6)
	_t = 0.0
	zombie.collision_mask = 0
	zombie.animator.play(zombie.data.anim_run if zombie.running else zombie.data.anim_walk, 0.2, 1.3)
	Audio.play_at("vault", zombie.global_position, -6.0, 0.1, 25.0, 200)


func exit() -> void:
	zombie.collision_mask = 1 | 4 | 32


func physics_update(delta: float) -> void:
	_t += delta / _dur
	var k := clampf(_t, 0.0, 1.0)
	var p := _from.lerp(_to, k)
	p.y += sin(k * PI) * 0.9
	zombie.global_position = p
	zombie.face_point(_to + (_to - _from), delta * 2.0)
	if _t >= 1.0:
		zombie.velocity = Vector3.ZERO
		zombie.change_state("chase")
