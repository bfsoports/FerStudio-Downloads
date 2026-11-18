class_name TrashBin
extends Interactable
## Papelera: descarta lo que el jugador lleve en la mano.

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p != null and p.held != null:
		if p.held is DirtyTray:
			return {"icon": "blocked", "text": "reject.trash_tray", "ok": false}
		return {"icon": "trash", "text": "prompt.discard"}
	return {}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or p.held == null:
		return
	if p.held is DirtyTray:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("reject.trash_tray"), "warn")
		return
	var item := p.release_held()
	if item is FoodItem:
		Events.item_discarded.emit((item as FoodItem).ingredient_id)
	else:
		Events.item_discarded.emit("burger")
	if item != null:
		item.queue_free()
	AudioManager.play_sfx("place", -2.0, 0.8)
	GameState.add_stat("items_discarded", 1)
