extends RefCounted
## Anuncios: configuración (IDs de prueba), recompensas, límites del intersticial y segunda oportunidad del turno.

var _offered := ""

func run(t) -> void:
	GameState.reset_to_defaults()
	t.ok(Ads.cfg.has("test_rewarded_id"), "ads_config.json se carga")
	t.eq(Ads.unit_id("rewarded"), "ca-app-pub-3940256099942544/5224354917", "con use_test_ids se usa el ID de prueba de Google")
	t.eq(Ads.unit_id("interstitial"), "ca-app-pub-3940256099942544/1033173712", "intersticial de prueba")
	t.ok(Ads.is_test_mode(), "el modo de prueba está activo por defecto")
	t.eq(Ads.double_amount({"net_income": 3, "coins_bonus": 0}), 20, "el x2 da al menos el mínimo")
	t.eq(Ads.double_amount({"net_income": 90, "coins_bonus": 40}), 130, "el x2 da lo ganado en el turno")
	t.eq(Ads.double_amount({"net_income": 5000, "coins_bonus": 0}), 400, "el x2 tiene un máximo")
	GameState.level = 3
	t.eq(Ads.free_coins_amount(), 50, "monedas gratis = base + 5 por nivel")
	GameState.ad_coins_at = 0
	t.eq(Ads.free_coins_wait(), 0, "las primeras monedas gratis están disponibles")
	var before := GameState.coins
	var got := Ads.claim_free_coins()
	t.eq(GameState.coins, before + got, "se cobran las monedas gratis")
	t.ok(Ads.free_coins_wait() > 0, "después hay que esperar")
	# intersticial: nunca en los primeros turnos ni sin varias derrotas
	Ads._losses = 0
	t.ok(not Ads.interstitial_due(), "sin derrotas no hay intersticial")
	GameState.stats["shifts_played"] = 10
	Ads.register_loss()
	Ads.register_loss()
	t.eq(Ads.interstitial_due(), Ads.backend != Ads.Backend.NONE and (Ads.backend == Ads.Backend.SIMULATED or Ads._interstitial != null), "tras dos derrotas toca (si hay anuncios)")
	Ads._losses = 0

	# segunda oportunidad en el turno
	var shift := ShiftManager.new()
	t.add_child(shift)
	shift.start({"mode": "campaign", "level_id": 1, "duration": 30.0, "recipes": ["classic"], "win": {"orders": 3},
		"lose": {"max_failed": 2}, "star_income": [10, 20], "patience": 60.0, "spawn_interval": 20.0, "max_active": 1})
	shift.revive_handler = _on_revive
	shift.time_left = 0.0
	shift.finish("time")
	t.eq(_offered, "time", "al perder por tiempo se ofrece la segunda oportunidad")
	t.ok(not shift.running, "el turno queda detenido mientras se decide")
	shift.revive("time", 45.0)
	t.ok(shift.running, "al revivir el turno sigue")
	t.eq(shift.time_left, 45.0, "con los segundos extra")
	_offered = ""
	shift.finish("time")
	t.eq(_offered, "", "la segunda oportunidad solo se ofrece una vez")
	shift.queue_free()
	var shift2 := ShiftManager.new()
	t.add_child(shift2)
	shift2.start({"mode": "campaign", "level_id": 1, "duration": 30.0, "recipes": ["classic"], "win": {"orders": 3},
		"lose": {"max_failed": 2}, "star_income": [10, 20], "patience": 60.0, "spawn_interval": 20.0, "max_active": 1})
	shift2.revive_handler = _on_revive
	shift2.stats["failed"] = 3
	shift2.finish("failed")
	shift2.revive("failed", 45.0)
	t.eq(int(shift2.stats["failed"]), 0, "revivir por fallos los perdona")
	shift2.finish("quit", true)
	t.ok(not shift2.running, "terminar a la fuerza no ofrece nada")
	shift2.queue_free()
	GameState.reset_to_defaults()

func _on_revive(reason: String) -> void:
	_offered = reason
