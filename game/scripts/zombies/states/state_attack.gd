class_name ZState_Attack
extends ZombieState
## Melee swipe. Damage lands mid-animation if the player is still in reach.

var _t := 0.0
var _hit_at := 0.0
var _done_hit := false


func state_id() -> String:
	return "attack"


func enter() -> void:
	var clip := zombie.data.anim_attack if randf() < 0.65 else zombie.data.anim_attack_alt
	var spd := 1.35 if zombie.data.id != "tank" and not zombie.data.is_boss else 1.0
	var len := zombie.animator.length_of(clip) / spd
	_t = minf(len, zombie.data.attack_cooldown + 0.3)
	_hit_at = _t * 0.45
	_done_hit = false
	zombie.animator.play(clip, 0.12, spd, true)
	Audio.play_at("zombie_attack", zombie.global_position + Vector3.UP * 1.5, -4.0, 0.15, 20.0, 120)


func physics_update(delta: float) -> void:
	zombie.stand_still(delta)
	if zombie.target:
		zombie.face_point(zombie.target.global_position, delta * 1.5)
	_t -= delta
	if not _done_hit and _t <= _hit_at:
		_done_hit = true
		var reach := zombie.data.attack_range * zombie.data.scale + 0.6
		if zombie.target and zombie.target.alive and zombie.distance_to_target() <= reach:
			var dmg := zombie.data.damage * (1.0 + 0.04 * float(maxi(0, zombie.round_spawned - 10)))
			zombie.target.take_damage(dmg, zombie.global_position)
			Audio.play_at("zombie_hit_player", zombie.target.global_position, -2.0, 0.1, 10.0)
		if zombie.data.attack_shockwave:
			var p := zombie.global_position - zombie.global_basis.z * 1.2 * zombie.data.scale
			FX.shockwave(p + Vector3.UP * 0.1, Color(0.6, 1.0, 0.3), 3.0 * zombie.data.scale)
			FX.impact(p, Vector3.UP, "dirt")
			FX.shake(0.6, 0.3)
			Audio.play_at("slam", p, 2.0, 0.08, 40.0)
	if _t <= 0.0:
		zombie.change_state("chase")
