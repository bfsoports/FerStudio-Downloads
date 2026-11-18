class_name AssemblyStation
extends Station
## Tabla de montaje: aquí se construye la hamburguesa capa a capa con los ingredientes reales que lleva el jugador.
## El número de tablas disponibles depende de la mejora "Más espacio de montaje".

const MAX_LAYERS := 12

var board_index: int = 0
var stack: BurgerStack = null
var _lock_mark: MeshInstance3D = null

func configure(index: int, slot_y: float) -> void:
	kind = "assembly"
	board_index = index
	add_slot(Vector3(0, slot_y, 0))
	_lock_mark = Prims.box(self, Vector3(0.9, 0.012, 0.6), Vector3(0, slot_y + 0.006, 0), Prims.mat(Color(0.2, 0.15, 0.13)), false)
	Events.upgrade_changed.connect(_on_upgrade_changed)
	refresh()

func _on_upgrade_changed(_id: String, _level: int) -> void:
	refresh()

func is_unlocked() -> bool:
	return board_index < EconomyManager.prep_boards()

func refresh() -> void:
	_lock_mark.visible = not is_unlocked()

func slot_enabled(_idx: int) -> bool:
	return is_unlocked()

func reject_reason(item: Carryable) -> String:
	if not is_unlocked():
		return "reject.board_locked"
	if item is BurgerStack:
		return "reject.board_busy" if stack != null else ""
	var fi := item as FoodItem
	if fi == null or not bool(Catalog.ingredient(fi.ingredient_id).get("stackable", false)):
		return "reject.not_stackable"
	if fi.is_cookable() and fi.state != FoodItem.State.COOKED and fi.state != FoodItem.State.BURNT:
		return "reject.not_cooked"
	if stack == null:
		return "" if fi.ingredient_id == "bun_bottom" else "reject.start_bun"
	if stack.closed:
		return "reject.burger_closed"
	if stack.layers.size() >= MAX_LAYERS:
		return "reject.too_tall"
	return ""

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null or p.held == null:
		return {}
	var why := reject_reason(p.held)
	if why != "":
		return {"icon": "blocked", "text": why, "ok": false}
	if p.held is BurgerStack:
		return {"icon": "drop", "text": "prompt.place"}
	return {"icon": "drop", "text": "prompt.add_layer"}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or p.held == null:
		return
	var item := p.held
	var why := reject_reason(item)
	if why != "":
		_reject(why)
		return
	if item is BurgerStack:
		p.release_held()
		place(item, 0)
		return
	var fi := item as FoodItem
	p.release_held()
	if stack == null:
		stack = BurgerStack.new().setup()
		(slot_nodes[0] as Marker3D).add_child(stack)
		stack.station = self
		slot_items[0] = stack
		Events.item_placed.emit("burger", kind)
	stack.add_layer(fi)
	AudioManager.play_sfx("place", -5.0)
	Events.item_placed.emit(fi.ingredient_id, kind)
	fi.queue_free()

func on_item_placed(_idx: int, item: Carryable) -> void:
	if item is BurgerStack:
		stack = item as BurgerStack

func on_item_removed(_idx: int, item: Carryable) -> void:
	if item == stack:
		stack = null
