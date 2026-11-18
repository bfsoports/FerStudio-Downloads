class_name RoundManager
extends Node
## Round flow: horde size, spawn pacing, simultaneous cap, difficulty scaling,
## special archetype probabilities and boss rounds. Infinite rounds.

signal round_started(number: int)
signal round_ended(number: int)
signal remaining_changed(remaining: int)
signal boss_spawned(boss: Zombie)
signal boss_died

const INTERMISSION := 9.0
const FIRST_DELAY := 2.5
const BOSS_EVERY := 5

var round_number := 0
var to_spawn := 0
var remaining := 0
var in_intermission := true
var player: Player
var pool: ZombiePool
var spawn_points: Array[SpawnPoint] = []
var zone_open: Callable          # func(zone_id: String) -> bool
var archetypes := {}             # id -> ZombieData

var _spawn_timer := 0.0
var _intermission_t := FIRST_DELAY
var _boss_pending := false
var _boss_alive: Zombie
var _extra_queue: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("round_manager")
	for id in ["walker", "runner", "armored", "tank", "boss"]:
		var path := "res://resources/zombies/%s.tres" % id
		if ResourceLoader.exists(path):
			archetypes[id] = load(path)


func setup(p: Player, zp: ZombiePool, points: Array[SpawnPoint], zone_check: Callable) -> void:
	player = p
	pool = zp
	spawn_points = points
	zone_open = zone_check
	pool.zombie_released.connect(func(_z): pass)
	# Pre-instance enough zombies so rounds never instantiate on the fly.
	var cap := Settings.max_active_zombies()
	pool.prewarm(archetypes["walker"], cap)
	pool.prewarm(archetypes["runner"], maxi(4, cap / 3))
	pool.prewarm(archetypes["armored"], 4)
	pool.prewarm(archetypes["tank"], 2)
	pool.prewarm(archetypes["boss"], 1)


func zombies_for_round(r: int) -> int:
	if r <= 5:
		return [6, 9, 13, 17, 22][r - 1]
	return mini(int(22.0 + (r - 5) * 5.0 + pow(r - 5, 1.35)), 220)


func spawn_interval(r: int) -> float:
	return maxf(0.3, 2.1 - r * 0.13)


func _process(delta: float) -> void:
	if player == null or not player.alive:
		return
	if in_intermission:
		_intermission_t -= delta
		if _intermission_t <= 0.0:
			_start_round(round_number + 1)
		return
	_spawn_timer -= delta
	var active := pool.alive_count()
	if _spawn_timer <= 0.0 and active < Settings.max_active_zombies():
		if not _extra_queue.is_empty():
			_spawn_type(_extra_queue.pop_back(), false)
			_spawn_timer = 0.25
		elif _boss_pending and to_spawn <= int(zombies_for_round(round_number) * 0.6):
			_boss_pending = false
			_spawn_boss()
			_spawn_timer = 2.0
		elif to_spawn > 0:
			if _spawn_one():
				to_spawn -= 1
			_spawn_timer = spawn_interval(round_number) * _rng.randf_range(0.7, 1.3)
	if to_spawn <= 0 and not _boss_pending and _extra_queue.is_empty() and active == 0 and remaining <= 0:
		_end_round()


func _start_round(n: int) -> void:
	round_number = n
	GameState.set_round(n)
	to_spawn = zombies_for_round(n)
	remaining = to_spawn
	_boss_pending = (n % BOSS_EVERY == 0)
	if _boss_pending:
		remaining += 1
	in_intermission = false
	_spawn_timer = 1.0
	if n > 1:
		player.add_grenades(2)
	round_started.emit(n)
	remaining_changed.emit(remaining)
	Audio.play("round_start", 0.0, 0.0)
	Audio.play_music("tension" if n >= 6 else "ambient_game", 3.0, -8.0 if n >= 6 else -10.0)


func _end_round() -> void:
	in_intermission = true
	_intermission_t = INTERMISSION
	round_ended.emit(round_number)
	Audio.play("round_end", 0.0, 0.0)


func on_zombie_died(z: Zombie, _headshot: bool) -> void:
	if z.data.is_boss:
		_boss_alive = null
		boss_died.emit()
		FX.explosion(z.global_position + Vector3.UP, 6.0)
	if z.get_meta("counts", true):
		remaining = maxi(0, remaining - 1)
		remaining_changed.emit(remaining)


func _pick_archetype() -> String:
	var weights := {}
	var special := 0.0
	for id in ["runner", "armored", "tank"]:
		var d: ZombieData = archetypes[id]
		var w := d.weight_for_round(round_number)
		if w > 0.0 and pool.alive_count(id) < d.max_alive:
			weights[id] = w
			special += w
	var r := _rng.randf()
	var acc := 0.0
	for id in weights:
		acc += weights[id]
		if r < acc:
			return id
	return "walker"


func _spawn_one() -> bool:
	return _spawn_type(_pick_archetype(), true)


func _spawn_type(id: String, counts: bool) -> bool:
	var sp := _choose_spawn_point()
	if sp == null:
		return false
	var z := pool.acquire(id)
	if z == null:
		return false
	var d := z.data
	var sprint := false
	if round_number >= d.run_from_round:
		sprint = _rng.randf() < clampf((round_number - d.run_from_round + 1) * d.sprint_chance_per_round, 0.0, 0.95)
	z.set_meta("counts", counts)
	if not z.died.is_connected(on_zombie_died):
		z.died.connect(on_zombie_died)
	var xf := Transform3D(Basis.IDENTITY, sp.global_position + Vector3(_rng.randf_range(-0.6, 0.6), 0.05, _rng.randf_range(-0.6, 0.6)))
	z.activate(xf, round_number, player, sp, sprint)
	return true


func _spawn_boss() -> void:
	var z := pool.acquire("boss")
	if z == null:
		return
	var sp := _choose_spawn_point(true)
	if sp == null:
		return
	z.set_meta("counts", true)
	if not z.died.is_connected(on_zombie_died):
		z.died.connect(on_zombie_died)
	z.activate(Transform3D(Basis.IDENTITY, sp.global_position), round_number, player, null if sp.barricade else sp, false)
	_boss_alive = z
	boss_spawned.emit(z)
	Audio.play_music("boss", 1.0, -6.0)


func spawn_extra(id: String, count: int) -> void:
	for i in count:
		_extra_queue.append(id)


func _choose_spawn_point(prefer_open: bool = false) -> SpawnPoint:
	var candidates: Array[SpawnPoint] = []
	var weights: Array[float] = []
	var total := 0.0
	var ppos := player.global_position
	for sp in spawn_points:
		if not zone_open.call(sp.zone_id):
			continue
		if prefer_open and sp.barricade != null:
			continue
		var d := sp.global_position.distance_to(ppos)
		if d < 6.0:
			continue
		var w := 1.0 / maxf(d - 4.0, 1.0)
		if d > 45.0:
			w *= 0.2
		candidates.append(sp)
		weights.append(w)
		total += w
	if candidates.is_empty():
		if prefer_open:
			return _choose_spawn_point(false)
		return null
	var r := _rng.randf() * total
	for i in candidates.size():
		r -= weights[i]
		if r <= 0.0:
			return candidates[i]
	return candidates.back()


func skip_intermission() -> void:
	if in_intermission:
		_intermission_t = minf(_intermission_t, 0.5)


func intermission_left() -> float:
	return _intermission_t if in_intermission else 0.0
