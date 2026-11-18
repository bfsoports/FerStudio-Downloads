class_name BossBrain
extends Node
## Special abilities for "El Capataz": charge, shock-slam and a horde call at
## half health. Plugs into ZState_Chase through think().

signal phase_changed(phase: int)

var zombie: Zombie
var _charge_cd := 6.0
var _slam_cd := 4.0
var _summoned := false
var _mode := ""
var _t := 0.0
var _charge_dir := Vector3.ZERO
var _hit_player := false


func reset() -> void:
	_charge_cd = 6.0
	_slam_cd = 4.0
	_summoned = false
	_mode = ""


func on_damaged(_amount: float) -> void:
	if not _summoned and zombie.health < zombie.max_health * 0.5:
		_summoned = true
		_mode = "summon"
		_t = 1.6
		zombie.animator.play("roar", 0.15, 1.2, true)
		Audio.play_at("tank_roar", zombie.global_position + Vector3.UP * 2.5, 8.0, 0.0, 80.0)
		FX.shake(0.8, 1.0)
		phase_changed.emit(2)
		var rm := zombie.get_tree().get_first_node_in_group("round_manager")
		if rm:
			rm.call("spawn_extra", "runner", 5)


## Returns true while an ability is controlling the boss.
func think(delta: float) -> bool:
	_charge_cd -= delta
	_slam_cd -= delta
	var d := zombie.distance_to_target()
	match _mode:
		"":
			if _charge_cd <= 0.0 and d > 7.0 and d < 20.0 and zombie.can_see_target():
				_mode = "windup"
				_t = 0.9
				zombie.animator.play("roar", 0.15, 1.6, true)
				Audio.play_at("tank_roar", zombie.global_position + Vector3.UP * 2.5, 4.0, 0.1, 60.0)
				return true
			if _slam_cd <= 0.0 and d < 5.0:
				_mode = "slam"
				_t = 1.3
				_hit_player = false
				zombie.animator.play("attack_slam", 0.1, 1.15, true)
				return true
			return false
		"windup":
			_t -= delta
			zombie.stand_still(delta)
			zombie.face_point(zombie.target.global_position, delta * 3.0)
			if _t <= 0.0:
				_mode = "charge"
				_t = 1.7
				_hit_player = false
				_charge_dir = (zombie.target.global_position - zombie.global_position)
				_charge_dir.y = 0
				_charge_dir = _charge_dir.normalized()
				zombie.animator.play("run", 0.1, 1.6)
			return true
		"charge":
			_t -= delta
			zombie.move_direct(delta, _charge_dir, 9.5)
			if not _hit_player and d < 2.2:
				_hit_player = true
				zombie.target.take_damage(45.0, zombie.global_position)
				zombie.target.velocity += _charge_dir * 9.0 + Vector3.UP * 3.0
				FX.shake(0.9, 0.4)
			if _t <= 0.0 or zombie.get_slide_collision_count() > 0 and _t < 1.4:
				_mode = ""
				_charge_cd = randf_range(7.0, 10.0)
				FX.impact(zombie.global_position + _charge_dir, Vector3.UP, "dirt")
			return true
		"slam":
			_t -= delta
			zombie.stand_still(delta)
			if not _hit_player and _t < 0.65:
				_hit_player = true
				var p := zombie.global_position
				FX.shockwave(p + Vector3.UP * 0.15, Color(0.5, 1.0, 0.25), 7.0)
				FX.energy_burst(p + Vector3.UP * 0.5, Color(0.5, 1.0, 0.25))
				FX.shake(1.0, 0.5)
				Audio.play_at("slam", p, 6.0, 0.05, 60.0)
				if zombie.target.global_position.distance_to(p) < 5.5 and zombie.target.is_on_floor():
					zombie.target.take_damage(40.0, p)
			if _t <= 0.0:
				_mode = ""
				_slam_cd = randf_range(5.0, 7.0)
			return true
		"summon":
			_t -= delta
			zombie.stand_still(delta)
			if _t <= 0.0:
				_mode = ""
			return true
	return false
