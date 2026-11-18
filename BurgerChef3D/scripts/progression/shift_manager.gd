class_name ShiftManager
extends Node
## Controla un turno de juego (campaña, modo libre): tiempo, estadísticas, victoria/derrota, estrellas y recompensas.

var config: Dictionary = {}
var mode: String = Const.MODE_CAMPAIGN
var running := false
var time_left := 0.0
var elapsed := 0.0
var stats: Dictionary = {}
var _ended := false
var _last_sec := -1
## Segunda oportunidad (anuncio recompensado): si hay un manejador, al ir a perder un nivel de campaña se le llama en
## lugar de terminar; él decide si se revive (revive) o se termina de verdad (finish con force).
var revive_handler: Callable = Callable()
var revive_used := false

func _ready() -> void:
	reset_stats()
	Events.item_burnt.connect(_on_item_burnt)
	Events.burger_closed.connect(_on_burger_closed)

func reset_stats() -> void:
	stats = {"orders_ok": 0, "orders_wrong": 0, "orders_expired": 0, "failed": 0, "customers": 0, "income": 0,
		"penalties": 0, "burnt": 0, "sat_sum": 0.0, "sat_count": 0, "recipe_counts": {}, "streak": 0,
		"best_streak": 0, "perfect": 0, "burgers": 0, "xp": 0}

func start(cfg: Dictionary) -> void:
	config = cfg
	mode = str(cfg.get("mode", Const.MODE_CAMPAIGN))
	reset_stats()
	time_left = float(cfg.get("duration", 0.0))
	elapsed = 0.0
	_ended = false
	_last_sec = -1
	revive_used = false
	running = true
	GameState.add_stat("shifts_played", 1)
	Events.shift_started.emit(cfg)

func has_time_limit() -> bool:
	return float(config.get("duration", 0.0)) > 0.0

## Factor de la economía según el modo: el modo libre paga la mitad para no devaluar la campaña y el tutorial no
## paga nada (su recompensa única se da al terminarlo, ver Tutorial).
func mode_factor() -> float:
	if mode == Const.MODE_TUTORIAL:
		return 0.0
	return 0.5 if mode == Const.MODE_FREE else 1.0

## Si las bandejas se ensucian al entregar en este turno (hay que lavarlas en el fregadero).
func dirty_trays() -> bool:
	return bool(config.get("dirty_trays", false))

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if has_time_limit():
		time_left = maxf(0.0, time_left - delta)
		var sec := int(ceil(time_left))
		if sec != _last_sec:
			_last_sec = sec
			Events.shift_tick.emit(time_left)
		if time_left <= 0.0:
			finish("time")
			return
	if ShiftRules.has_lost(config.get("lose", {}), stats):
		finish("failed")

func register_delivery(order: Order, info: Dictionary) -> void:
	stats["customers"] = int(stats["customers"]) + 1
	GameState.add_stat("customers_served", 1)
	stats["xp"] = int(stats["xp"]) + int(info["xp"])
	stats["income"] = int(stats["income"]) + int(info["coins"])
	stats["penalties"] = int(stats["penalties"]) + int(info["penalty"])
	stats["sat_sum"] = float(stats["sat_sum"]) + float(info["satisfaction"])
	stats["sat_count"] = int(stats["sat_count"]) + 1
	if bool(info["ok"]):
		stats["orders_ok"] = int(stats["orders_ok"]) + 1
		stats["streak"] = int(stats["streak"]) + 1
		stats["best_streak"] = maxi(int(stats["best_streak"]), int(stats["streak"]))
		var rc: Dictionary = stats["recipe_counts"]
		rc[order.recipe_id] = int(rc.get(order.recipe_id, 0)) + 1
		GameState.add_stat("orders_correct", 1)
		GameState.set_stat_max("best_streak", int(stats["streak"]))
		if str(Catalog.recipe(order.recipe_id).get("kind", "")) == "combo":
			GameState.add_stat("combos_served", 1)
		if bool(info["perfect"]):
			stats["perfect"] = int(stats["perfect"]) + 1
			GameState.add_stat("perfect_burgers", 1)
	else:
		stats["orders_wrong"] = int(stats["orders_wrong"]) + 1
		stats["failed"] = int(stats["failed"]) + 1
		stats["streak"] = 0

func register_expired(_order: Order, taken: int) -> void:
	stats["orders_expired"] = int(stats["orders_expired"]) + 1
	stats["failed"] = int(stats["failed"]) + 1
	stats["penalties"] = int(stats["penalties"]) + taken
	stats["sat_count"] = int(stats["sat_count"]) + 1
	stats["streak"] = 0

func _on_item_burnt(_ingredient_id: String) -> void:
	if not running:
		return
	stats["burnt"] = int(stats["burnt"]) + 1
	if mode_factor() > 0.0:
		stats["penalties"] = int(stats["penalties"]) + EconomyManager.penalize(RewardCalc.burn_penalty(), "burnt_food")

func _on_burger_closed(_layers: Array) -> void:
	if not running:
		return
	stats["burgers"] = int(stats["burgers"]) + 1
	GameState.add_stat("burgers_made", 1)

## Termina el turno. reason: "time" (se acabó el tiempo), "failed" (demasiados fallos) o "quit" (el jugador termina).
## force = true termina sin ofrecer la segunda oportunidad.
func finish(reason: String, force: bool = false) -> void:
	if _ended:
		return
	if not force and _can_offer_revive(reason):
		running = false
		revive_handler.call(reason)
		return
	_ended = true
	running = false
	var win: Dictionary = config.get("win", {})
	var won := false
	if mode == Const.MODE_CAMPAIGN:
		won = reason == "time" and ShiftRules.is_won(win, stats)
	var stars := ShiftRules.stars(config, stats, won)
	var level_id := Util.to_int(config.get("level_id", 0))
	var result := {
		"mode": mode, "level_id": level_id, "won": won, "stars": stars, "reason": reason,
		"orders_ok": int(stats["orders_ok"]), "orders_wrong": int(stats["orders_wrong"]),
		"orders_expired": int(stats["orders_expired"]), "customers": int(stats["customers"]),
		"income": int(stats["income"]), "penalties": int(stats["penalties"]), "net_income": ShiftRules.net_income(stats),
		"satisfaction": int(ShiftRules.avg_satisfaction(stats)), "burnt": int(stats["burnt"]),
		"perfect": int(stats["perfect"]), "best_streak": int(stats["best_streak"]), "xp_gained": int(stats["xp"]),
		"coins_bonus": 0, "xp_bonus": 0, "first_time": false, "stars_gained": 0, "new_recipes": [],
		"time_played": int(elapsed), "objectives": ShiftRules.objective_progress(win, stats),
		"next_level": 0, "records": [],
	}
	if mode == Const.MODE_CAMPAIGN:
		_apply_campaign_rewards(result)
	elif mode == Const.MODE_FREE:
		_update_records(result)
	SaveManager.request_save()
	Events.shift_ended.emit(result)

func _can_offer_revive(reason: String) -> bool:
	if mode != Const.MODE_CAMPAIGN or reason == "quit" or revive_used or not revive_handler.is_valid():
		return false
	# se acabó el tiempo pero se cumplieron los objetivos: es una victoria, no hay nada que revivir
	return not (reason == "time" and ShiftRules.is_won(config.get("win", {}), stats))

## Segunda oportunidad: «time» da segundos extra; «failed» perdona los fallos acumulados. Solo una vez por turno.
func revive(reason: String, seconds: float) -> void:
	revive_used = true
	if reason == "time":
		time_left = maxf(time_left, 0.0) + seconds
	else:
		stats["failed"] = 0
	_last_sec = -1
	running = true

func _apply_campaign_rewards(result: Dictionary) -> void:
	if not bool(result["won"]):
		return
	var level_id := int(result["level_id"])
	var info := GameState.complete_level(level_id, int(result["stars"]))
	var first := bool(info["first_time"])
	result["first_time"] = first
	result["stars_gained"] = int(info["stars_gained"])
	var coins := Util.to_int(config.get("reward_coins", 0))
	var xp := Util.to_int(config.get("reward_xp", 0))
	if first:
		result["coins_bonus"] = coins
		EconomyManager.earn(coins, "level_reward")
	else:
		xp = int(xp * 0.5)
	result["xp_bonus"] = xp
	GameState.add_xp(xp)
	if int(stats["burnt"]) == 0:
		GameState.add_stat("no_burn_shifts", 1)
	var new_recipes: Array = []
	for rid in Catalog.recipe_order:
		if Util.to_int(Catalog.recipes[rid].get("unlock_level", 0)) == level_id + 1 and GameState.recipe_upgrade_ok(str(rid)):
			new_recipes.append(rid)
	result["new_recipes"] = new_recipes
	result["next_level"] = level_id + 1 if level_id < Catalog.levels.size() else 0

func _update_records(result: Dictionary) -> void:
	var recs: Array = []
	var pairs := [["best_orders", int(result["orders_ok"])], ["best_income", int(result["net_income"])], ["longest_session", int(result["time_played"])]]
	for p in pairs:
		var key: String = p[0]
		var value: int = p[1]
		if value > Util.to_int(GameState.records.get(key, 0)):
			GameState.records[key] = value
			if value > 0:
				recs.append(key)
	result["records"] = recs
