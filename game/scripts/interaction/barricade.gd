class_name Barricade
extends Interactable
## Boarded window. Zombies rip planks off (one per attack) and climb through
## when it is open; the player repairs it plank by plank (hold) for points.
## Planks are pre-built and only toggled/tweened: no physics, no instancing.

signal planks_changed(count: int)

const PLANKS := 6
const REPAIR_TIME := 0.55
const POINTS_PER_PLANK := 10
const MAX_REPAIR_POINTS_PER_ROUND := 60

@export var width := 1.6
@export var height := 1.5
@export var sill := 0.8
@export var zone_id := "start"

var planks := PLANKS
var _mm: MultiMeshInstance3D
var _plank_rest: Array[Transform3D] = []
var _plank_xf: Array[Transform3D] = []
var _slots: Array = []
var _repair_t := 0.0
var _round_points := 0
var _last_round := 0
var _blocker: StaticBody3D


func _ready() -> void:
	super._ready()
	continuous = true
	interact_radius = 2.0
	focus_offset = Vector3(0, sill + height * 0.5, 0.3)
	var bm := BoxMesh.new()
	bm.size = Vector3(width + 0.35, 0.17, 0.06)
	bm.material = MapKit.mat("plank")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = PLANKS
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.visibility_range_end = 40.0
	add_child(_mm)
	for i in PLANKS:
		var y := sill + 0.15 + (height - 0.3) * (float(i) / float(PLANKS - 1))
		var rot := deg_to_rad(randf_range(-14, 14)) if i % 2 == 0 else deg_to_rad(randf_range(-6, 6))
		var xf := Transform3D(Basis(Vector3.BACK, rot), Vector3(randf_range(-0.05, 0.05), y, 0.05 + 0.02 * (i % 2)))
		_plank_rest.append(xf)
		_plank_xf.append(xf)
		mm.set_instance_transform(i, xf)
	# collision that stops the player from walking through the opening
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = 32   # blocks player + zombies, not bullets
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height + sill, 0.3)
	cs.shape = bs
	cs.position = Vector3(0, (height + sill) * 0.5, 0)
	_blocker.add_child(cs)
	add_child(_blocker)


func outside_point() -> Vector3:
	return global_position - global_basis.z * 0.85


func inside_point() -> Vector3:
	return global_position + global_basis.z * 1.0


func blocks_zombies() -> bool:
	return planks > 0


func request_slot(z: Zombie) -> bool:
	_slots = _slots.filter(func(x): return is_instance_valid(x) and x.is_alive() and x.state_name == "break_barrier")
	if _slots.has(z):
		return true
	if _slots.size() < 2:
		_slots.append(z)
		return true
	return false


func release_slot(z: Zombie) -> void:
	_slots.erase(z)


func remove_plank() -> void:
	if planks <= 0:
		return
	planks -= 1
	var idx := planks
	var from := _plank_xf[idx]
	var to := Transform3D(from.basis.rotated(Vector3.BACK, randf_range(-1.5, 1.5)), from.origin + Vector3(randf_range(-0.6, 0.6), -0.8, -1.5))
	var tw := create_tween()
	tw.tween_method(func(k: float): _set_plank(idx, from.interpolate_with(to, k)), 0.0, 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): if idx >= planks: _set_plank(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)))
	Audio.play_at("plank_break", global_position + Vector3.UP * 1.3, 0.0, 0.12, 30.0)
	FX.impact(global_position + Vector3.UP * (sill + height * 0.5), global_basis.z, "wood")
	planks_changed.emit(planks)


func add_plank() -> bool:
	if planks >= PLANKS:
		return false
	var idx := planks
	var rest := _plank_rest[idx]
	var start := Transform3D(rest.basis.rotated(Vector3.UP, 0.4), rest.origin + Vector3(0, 0.25, 0.9))
	var tw := create_tween()
	tw.tween_method(func(k: float): _set_plank(idx, start.interpolate_with(rest, k)), 0.0, 1.0, 0.18).set_ease(Tween.EASE_IN)
	planks += 1
	Audio.play_at("plank_repair", global_position + Vector3.UP * 1.3, -2.0, 0.1, 25.0)
	FX.shake(0.08, 0.1)
	planks_changed.emit(planks)
	return true


func _set_plank(i: int, xf: Transform3D) -> void:
	_plank_xf[i] = xf
	_mm.multimesh.set_instance_transform(i, xf)


func is_available(_p: Player) -> bool:
	return planks < PLANKS


func get_prompt(_p: Player) -> Dictionary:
	return {"title": "REPARAR BARRICADA", "subtitle": "Mantén pulsado: +%d puntos por tabla" % POINTS_PER_PLANK,
		"price": 0, "icon": "repair", "can_afford": true, "action": "REPARAR"}


func interact(p: Player) -> void:
	# Tap repairs one plank immediately (desktop "E").
	_repair_one(p)


func _hold_start(_p: Player) -> void:
	_repair_t = 0.15


func _process(delta: float) -> void:
	if not _holding:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.current_target != self:
		_holding = false
		return
	_repair_t -= delta
	if _repair_t <= 0.0:
		_repair_t = REPAIR_TIME * (0.7 if p.has_perk("speed") else 1.0)
		_repair_one(p)


func _repair_one(_p: Player) -> void:
	# zombies tearing at this window prevent repairs right in their face
	if GameState.current_round != _last_round:
		_last_round = GameState.current_round
		_round_points = 0
	if add_plank():
		if _round_points < MAX_REPAIR_POINTS_PER_ROUND:
			GameState.add_points(POINTS_PER_PLANK)
			_round_points += POINTS_PER_PLANK
