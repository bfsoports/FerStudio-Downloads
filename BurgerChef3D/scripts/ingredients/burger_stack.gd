class_name BurgerStack
extends Carryable
## Hamburguesa en construcción: pila de capas reales (cada una con su estado de cocción) que se dibuja capa a capa.

var layers: Array = []     # [{"id": String, "state": int, "quality": float}]
var closed: bool = false   # true cuando se ha colocado el pan superior
var _visual: Node3D = null
var _col: CollisionShape3D = null

func setup() -> BurgerStack:
	_col = add_box_collider(Vector3(0.5, 0.2, 0.5), Vector3(0, 0.1, 0))
	refresh()
	return self

func add_layer(item: FoodItem) -> void:
	layers.append({"id": item.ingredient_id, "state": item.state, "quality": item.doneness_quality()})
	if item.ingredient_id == "bun_top":
		closed = true
		Events.burger_closed.emit(layers)
	refresh()
	if _visual != null:
		_visual.scale = Vector3(1.1, 0.88, 1.1)
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func ids() -> Array:
	var out: Array = []
	for l in layers:
		out.append(str(l["id"]))
	return out

func height() -> float:
	var h := 0.0
	for l in layers:
		h += FoodModels.layer_height(str(l["id"]))
	return h

func refresh() -> void:
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var y := 0.0
	var i := 0
	for l in layers:
		var id := str(l["id"])
		FoodModels.add_layer(_visual, id, y, FoodModels.progress_for_state(id, int(l["state"])), i)
		y += FoodModels.layer_height(id)
		i += 1
	var h := maxf(y, 0.1)
	var shape := _col.shape as BoxShape3D
	shape.size = Vector3(0.5, h + 0.05, 0.5)
	_col.position = Vector3(0, h * 0.5, 0)

func display_name() -> String:
	if closed:
		return Loc.t("item.burger", [layers.size()])
	return Loc.t("item.burger_open", [layers.size()])

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null:
		return {}
	if p.held == null:
		return {"icon": "grab", "text": "prompt.take", "args": [display_name()]}
	if station != null:
		return station.get_prompt(player)
	return {}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null:
		return
	if p.held != null:
		if station != null:
			station.interact(player)
		return
	if station != null:
		station.release(self)
	p.hold(self)
	AudioManager.play_sfx("pickup")
	Events.item_picked.emit("burger")
