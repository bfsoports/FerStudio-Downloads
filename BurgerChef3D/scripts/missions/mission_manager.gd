extends Node
## Misiones, desafíos y logros. El progreso sale de las estadísticas reales (GameState.stats),
## que se actualizan solo a partir de eventos del juego. Las recompensas se reclaman una única vez.

func _ready() -> void:
	Events.stat_changed.connect(_on_stat_changed)

func progress(m: Dictionary) -> int:
	return mini(GameState.stat(str(m.get("stat", ""))), Util.to_int(m.get("target", 1)))

func is_complete(m: Dictionary) -> bool:
	return GameState.stat(str(m.get("stat", ""))) >= Util.to_int(m.get("target", 1))

func is_claimed(id: String) -> bool:
	return bool(GameState.missions.get(id, {}).get("claimed", false))

func claimable_count() -> int:
	var n := 0
	for m in Catalog.missions:
		if is_complete(m) and not is_claimed(str(m["id"])):
			n += 1
	return n

func _on_stat_changed(stat_key: String, _value: int) -> void:
	for m in Catalog.missions:
		if str(m["stat"]) != stat_key or not is_complete(m):
			continue
		var id := str(m["id"])
		var st: Dictionary = GameState.missions.get(id, {"claimed": false, "notified": false})
		if not bool(st.get("notified", false)):
			st["notified"] = true
			GameState.missions[id] = st
			Events.mission_completed.emit(id)
			Events.toast.emit(Loc.t("toast.mission_done", [Loc.pick(m["name"])]), "success")
			SaveManager.request_save()

## Entrega la recompensa de una misión completada. Devuelve false si no está completa o ya se reclamó.
func claim(id: String) -> bool:
	for m in Catalog.missions:
		if str(m["id"]) != id:
			continue
		if not is_complete(m) or is_claimed(id):
			return false
		var st: Dictionary = GameState.missions.get(id, {})
		st["claimed"] = true
		st["notified"] = true
		GameState.missions[id] = st
		EconomyManager.earn(Util.to_int(m.get("reward_coins", 0)), "mission:" + id)
		GameState.add_xp(Util.to_int(m.get("reward_xp", 0)))
		SaveManager.request_save()
		return true
	return false
