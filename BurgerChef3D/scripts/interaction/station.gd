class_name Station
extends Interactable
## Base de las estaciones con ranuras (mostradores, plancha, freidora, tabla de montaje, bandejas).
## Las ranuras son posiciones fijas: colocar un objeto lo encaja en una ranura libre, así que nunca queda en una posición imposible.

var kind: String = "counter"
var slot_nodes: Array = []     # Marker3D
var slot_items: Array = []     # Carryable o null

func add_slot(local_pos: Vector3) -> int:
	var m := Marker3D.new()
	m.position = local_pos
	add_child(m)
	slot_nodes.append(m)
	slot_items.append(null)
	return slot_nodes.size() - 1

# ------------------------------------------------------------------ puntos de extensión (se sobrescriben)
func slot_enabled(_idx: int) -> bool:
	return true

## Clave de traducción con el motivo del rechazo, o "" si el objeto es aceptado.
func reject_reason(_item: Carryable) -> String:
	return ""

func on_item_placed(_idx: int, _item: Carryable) -> void:
	pass

func on_item_removed(_idx: int, _item: Carryable) -> void:
	pass

# ------------------------------------------------------------------ lógica común
func free_slot_index(_item: Carryable, near_world: Vector3 = Vector3.INF) -> int:
	var best := -1
	var best_d := INF
	for i in slot_nodes.size():
		if slot_items[i] != null or not slot_enabled(i):
			continue
		if not near_world.is_finite():
			return i
		var d := (slot_nodes[i] as Marker3D).global_position.distance_to(near_world)
		if d < best_d:
			best_d = d
			best = i
	return best

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null or p.held == null:
		return {}
	var why := reject_reason(p.held)
	if why != "":
		return {"icon": "blocked", "text": why, "ok": false}
	if free_slot_index(p.held) < 0:
		return {"icon": "blocked", "text": "reject.no_space", "ok": false}
	return {"icon": "drop", "text": "prompt.place"}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or p.held == null:
		return
	var item := p.held
	var why := reject_reason(item)
	if why != "":
		_reject(why)
		return
	var idx := free_slot_index(item, p.get_aim_point())
	if idx < 0:
		_reject("reject.no_space")
		return
	p.release_held()
	place(item, idx)

func _reject(key: String) -> void:
	AudioManager.play_sfx("error", -6.0)
	Events.toast.emit(Loc.t(key), "warn")

## Encaja el objeto en la ranura con una pequeña animación desde donde estaba (la mano).
func place(item: Carryable, idx: int) -> void:
	var gt := item.global_transform
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	(slot_nodes[idx] as Marker3D).add_child(item)
	item.global_transform = gt
	slot_items[idx] = item
	item.station = self
	item.set_pickable(true)
	var tw := item.create_tween().set_parallel(true)
	tw.tween_property(item, "position", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector3.ONE, 0.12)
	tw.tween_property(item, "rotation", Vector3.ZERO, 0.12)
	AudioManager.play_sfx("place")
	var item_id := "burger"
	if item is FoodItem:
		item_id = (item as FoodItem).ingredient_id
	elif item is DirtyTray:
		item_id = "dirty_tray"
	Events.item_placed.emit(item_id, kind)
	on_item_placed(idx, item)

## Quita el objeto de su ranura (lo llama el propio objeto al ser recogido).
func release(item: Carryable) -> void:
	for i in slot_items.size():
		if slot_items[i] == item:
			slot_items[i] = null
			item.station = null
			on_item_removed(i, item)
			return

func clear_slot_of(item: Carryable) -> void:
	for i in slot_items.size():
		if slot_items[i] == item:
			slot_items[i] = null
			on_item_removed(i, item)
			return

func items_present() -> Array:
	var out: Array = []
	for it in slot_items:
		if it != null:
			out.append(it)
	return out
