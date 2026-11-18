extends Node
## Match statistics, global gameplay signals and local records (user://records.cfg).

signal points_changed(points: int, delta: int)
signal round_changed(round_number: int)
signal kills_changed(kills: int)
signal match_ended(stats: Dictionary)

const RECORDS_PATH := "user://records.cfg"

var points: int = 0
var kills: int = 0
var headshots: int = 0
var current_round: int = 0
var total_points_earned: int = 0
var match_time: float = 0.0
var match_running := false
var paused := false

var best_round: int = 0
var best_kills: int = 0
var best_score: int = 0
var games_played: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_records()


func _process(delta: float) -> void:
	if match_running and not get_tree().paused:
		match_time += delta


func start_match(start_points: int = 500) -> void:
	points = start_points
	kills = 0
	headshots = 0
	current_round = 0
	total_points_earned = 0
	match_time = 0.0
	match_running = true
	points_changed.emit(points, 0)
	kills_changed.emit(kills)


func add_points(amount: int) -> void:
	if amount <= 0:
		return
	points += amount
	total_points_earned += amount
	points_changed.emit(points, amount)


func can_afford(cost: int) -> bool:
	return points >= cost


func spend(cost: int) -> bool:
	if points < cost:
		return false
	points -= cost
	points_changed.emit(points, -cost)
	return true


func register_kill(headshot: bool) -> void:
	kills += 1
	if headshot:
		headshots += 1
	kills_changed.emit(kills)


func set_round(r: int) -> void:
	current_round = r
	round_changed.emit(r)


func end_match() -> Dictionary:
	match_running = false
	games_played += 1
	var stats := {
		"round": current_round,
		"kills": kills,
		"headshots": headshots,
		"score": total_points_earned,
		"time": match_time,
		"new_round_record": current_round > best_round,
		"new_kill_record": kills > best_kills,
		"new_score_record": total_points_earned > best_score,
	}
	best_round = maxi(best_round, current_round)
	best_kills = maxi(best_kills, kills)
	best_score = maxi(best_score, total_points_earned)
	save_records()
	match_ended.emit(stats)
	return stats


func load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return
	best_round = cfg.get_value("records", "best_round", 0)
	best_kills = cfg.get_value("records", "best_kills", 0)
	best_score = cfg.get_value("records", "best_score", 0)
	games_played = cfg.get_value("records", "games_played", 0)


func save_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_round", best_round)
	cfg.set_value("records", "best_kills", best_kills)
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("records", "games_played", games_played)
	cfg.save(RECORDS_PATH)


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]
