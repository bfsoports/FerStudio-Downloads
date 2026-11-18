class_name IngredientCrate
extends Interactable
## Caja o nevera de un ingrediente. Tiene existencias limitadas (la mejora de almacenamiento las amplía) y se repone
## pagando su coste; si no hay monedas se concede una reposición de emergencia gratuita para no bloquear al jugador.

const LABEL_HIDE_NEAR := 1.8   # distancia (m) por debajo de la cual se oculta el rótulo

var ingredient_id: String = ""
var stock: int = 0
var max_stock: int = 8
var restock_free: bool = false
var _top_y: float = 1.0
var _label: Label3D = null

func setup(id: String, top_y: float, label_pos: Vector3) -> void:
	ingredient_id = id
	_top_y = top_y
	# rótulo más pequeño para que los de neveras y cajas contiguas (separadas 1,4 m) no se pisen
	_label = Prims.label3d(self, "", label_pos, 0.0034, 38, Color.WHITE, true, 8)
	# de cerca el rótulo se oculta (el indicador de abajo ya dice qué se coge) para no tapar la vista; de lejos
	# sirve para encontrar cada ingrediente
	_label.visibility_range_begin = LABEL_HIDE_NEAR
	Events.upgrade_changed.connect(_on_upgrade_changed)
	refill()

func _on_upgrade_changed(_id: String, _level: int) -> void:
	max_stock = EconomyManager.crate_stock()
	_update_label()

func refill() -> void:
	max_stock = EconomyManager.crate_stock()
	stock = max_stock
	_update_label()

func restock_cost() -> int:
	if restock_free:
		return 0
	var unit := Util.to_int(Catalog.ingredient(ingredient_id).get("unit_price", 1), 1)
	return int(ceil(unit * max_stock * 0.5))

func _update_label() -> void:
	_label.text = "%s\nx%d" % [Catalog.ingredient_name(ingredient_id), stock]
	_label.modulate = Color.WHITE if stock > 0 else Color(1.0, 0.55, 0.5)

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null:
		return {}
	var nm := Catalog.ingredient_name(ingredient_id)
	if p.held == null:
		if stock > 0:
			return {"icon": "grab", "text": "prompt.take", "args": [nm]}
		return {"icon": "use", "text": "prompt.restock", "args": [restock_cost()]}
	var fi := p.held as FoodItem
	if fi != null and fi.ingredient_id == ingredient_id and fi.state == FoodItem.State.RAW and stock < max_stock:
		return {"icon": "drop", "text": "prompt.return", "args": [nm]}
	return {"icon": "blocked", "text": "reject.hands_full", "ok": false}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null:
		return
	if p.held == null:
		if stock > 0:
			var it := FoodItem.new().setup(ingredient_id)
			add_child(it)
			it.position = Vector3(0, _top_y, 0)
			stock -= 1
			_update_label()
			p.hold(it)
			AudioManager.play_sfx("pickup")
			Events.item_picked.emit(ingredient_id)
		else:
			_restock()
		return
	var fi := p.held as FoodItem
	if fi != null and fi.ingredient_id == ingredient_id and fi.state == FoodItem.State.RAW and stock < max_stock:
		p.release_held()
		fi.queue_free()
		stock += 1
		_update_label()
		AudioManager.play_sfx("place", -5.0)
	else:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("reject.hands_full"), "warn")

func _restock() -> void:
	var cost := restock_cost()
	if cost > 0 and not EconomyManager.spend(cost, "restock:" + ingredient_id):
		stock = mini(3, max_stock)
		Events.toast.emit(Loc.t("toast.emergency_restock"), "info")
		AudioManager.play_sfx("ding")
	else:
		stock = max_stock
		if cost > 0:
			Events.toast.emit(Loc.t("toast.restocked", [Catalog.ingredient_name(ingredient_id), cost]), "info")
			AudioManager.play_sfx("buy")
		else:
			AudioManager.play_sfx("ding")
	_update_label()
