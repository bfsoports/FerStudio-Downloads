extends RefCounted
## Misiones basadas en estadísticas reales; recompensa reclamada una sola vez.

func _find(id: String) -> Dictionary:
	for m in Catalog.missions:
		if str(m["id"]) == id:
			return m
	return {}

func run(t) -> void:
	GameState.reset_to_defaults()
	var m := _find("m_burgers_10")
	t.ok(not m.is_empty(), "existe la misión de 10 hamburguesas")
	t.ok(not MissionManager.is_complete(m), "empieza sin completar")
	GameState.add_stat("burgers_made", 9)
	t.ok(not MissionManager.is_complete(m), "9 de 10 no completa")
	t.eq(MissionManager.progress(m), 9, "el progreso refleja las estadísticas")
	GameState.add_stat("burgers_made", 1)
	t.ok(MissionManager.is_complete(m), "10 de 10 completa")
	t.ok(not MissionManager.claim("m_burgers_50"), "no se reclama una misión incompleta")
	var coins := GameState.coins
	t.ok(MissionManager.claim("m_burgers_10"), "se reclama la recompensa")
	t.eq(GameState.coins, coins + int(m["reward_coins"]), "se reciben las monedas de la misión")
	t.ok(MissionManager.is_claimed("m_burgers_10"), "queda marcada como reclamada")
	t.ok(not MissionManager.claim("m_burgers_10"), "no se reclama dos veces")
	t.eq(GameState.coins, coins + int(m["reward_coins"]), "la segunda reclamación no da monedas")
	GameState.set_stat_max("best_streak", 5)
	GameState.set_stat_max("best_streak", 3)
	t.eq(GameState.stat("best_streak"), 5, "las estadísticas de máximo no retroceden")
	GameState.reset_to_defaults()
