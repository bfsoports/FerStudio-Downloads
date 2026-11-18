class_name OrderManager
extends Node
## Gestiona los pedidos activos: paciencia, estado según la bandeja, entrega, evaluación de la receta y recompensas.

var shift: ShiftManager = null
var active: Array = []
var _next_id := 1

func create_order(sp: ServicePoint, customer: Customer, recipe_id: String, patience: float) -> Order:
	var recipe := Catalog.recipe(recipe_id)
	var o := Order.new()
	o.id = _next_id
	_next_id += 1
	o.recipe_id = recipe_id
	o.components = Order.components_for(recipe)
	o.patience_total = patience
	o.patience_left = patience
	o.customer = customer
	o.service_point = sp
	o.price = Util.to_int(recipe.get("price", 0))
	o.penalty = RewardCalc.expire_penalty(o.price)
	o.state = Order.State.WAITING
	sp.order = o
	customer.order = o
	active.append(o)
	Events.order_created.emit(o)
	AudioManager.play_sfx("ding")
	return o

func _process(delta: float) -> void:
	if shift == null or not shift.running:
		return
	for o in active.duplicate():
		var order := o as Order
		if not order.is_open():
			continue
		order.patience_left -= delta
		if not order.warned and order.patience_ratio() < 0.3:
			order.warned = true
			AudioManager.play_sfx("impatient", -6.0)
		if order.patience_left <= 0.0:
			_expire(order)

## Recalcula el estado del pedido (esperando / en preparación / listo) según lo que hay en la bandeja.
func tray_changed(sp: ServicePoint) -> void:
	var o := sp.order
	if o == null or not o.is_open():
		return
	var contents := sp.tray_contents()
	var any := false
	var all := true
	for comp in o.components:
		var present := _component_present(comp, contents)
		any = any or present
		all = all and present
	var new_state := Order.State.WAITING
	if all:
		new_state = Order.State.READY
	elif any:
		new_state = Order.State.PREPARING
	if new_state != o.state:
		o.state = new_state
		Events.order_changed.emit(o)

func _component_present(comp: Dictionary, contents: Dictionary) -> bool:
	if str(comp["type"]) == "burger":
		var stack := contents["main"] as BurgerStack
		return stack != null and stack.closed
	var it := contents["side" if str(comp["id"]) == "fries" else "drink"] as FoodItem
	return it != null and it.ingredient_id == str(comp["id"])

## Entrega la bandeja al cliente del puesto: comprueba que están todos los componentes y evalúa cada uno.
func deliver(sp: ServicePoint) -> void:
	var order := sp.order
	if order == null or not order.is_open() or sp.customer == null:
		Events.toast.emit(Loc.t("prompt.no_customer"), "warn")
		return
	var contents := sp.tray_contents()
	var results: Array = []
	var consumed: Array = []
	var missing: Array = []
	for comp in order.components:
		if str(comp["type"]) == "burger":
			var stack := contents["main"] as BurgerStack
			if stack == null:
				missing.append(Catalog.name_of(Catalog.recipe(str(comp["recipe"]))))
			elif not stack.closed:
				missing.append(Loc.t("deliver.open_burger"))
			else:
				results.append(RecipeValidator.validate(Catalog.recipe(str(comp["recipe"])), stack.layers))
				consumed.append(stack)
		else:
			var item_id := str(comp["id"])
			var it := contents["side" if item_id == "fries" else "drink"] as FoodItem
			if it == null or it.ingredient_id != item_id:
				missing.append(Catalog.ingredient_name(item_id))
			elif item_id == "fries" and it.state != FoodItem.State.COOKED and it.state != FoodItem.State.BURNT:
				missing.append(Loc.t("deliver.raw_fries"))
			else:
				results.append(RecipeValidator.validate_item(item_id, it.state))
				consumed.append(it)
	if not missing.is_empty():
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("deliver.missing", [", ".join(missing)]), "warn")
		return
	_settle(order, sp, RecipeValidator.combine(results), consumed)

func _settle(order: Order, sp: ServicePoint, combined: Dictionary, consumed: Array) -> void:
	var ok := bool(combined["ok"])
	var quality := float(combined["quality"])
	var ratio := order.patience_ratio()
	var recipe := Catalog.recipe(order.recipe_id)
	var factor := shift.mode_factor() if shift != null else 1.0
	var pay := RewardCalc.payout(order.price, quality, ok, ratio, EconomyManager.coin_mult(), factor)
	var coins := int(pay["coins"])
	var penalty := 0
	if not ok and factor > 0.0:
		penalty = EconomyManager.penalize(RewardCalc.wrong_penalty(order.price), "wrong_order")
	if coins > 0:
		EconomyManager.earn(coins, "order:" + order.recipe_id)
	var xp := RewardCalc.xp_for(Util.to_int(recipe.get("xp", 5)), quality, factor) if factor > 0.0 else 0
	GameState.add_xp(xp)
	order.satisfaction = RewardCalc.satisfaction(quality, ratio)
	order.state = Order.State.DELIVERED
	active.erase(order)
	for c in consumed:
		var carry := c as Carryable
		sp.clear_slot_of(carry)
		carry.queue_free()
	var info := {"ok": ok, "perfect": bool(combined["perfect"]), "coins": coins, "penalty": penalty,
		"satisfaction": order.satisfaction, "xp": xp, "status": int(combined["status"])}
	if shift != null:
		shift.register_delivery(order, info)
	if ok:
		AudioManager.play_sfx("deliver")
		Events.toast.emit(Loc.t("toast.delivered", [coins]), "success")
	else:
		AudioManager.play_sfx("error", -4.0)
		Events.toast.emit(Loc.t("toast.delivered_wrong", [Loc.t(RecipeValidator.status_key(int(combined["status"])))]), "warn")
	sp.order = null
	# con las bandejas sucias activadas, la bandeja usada se queda en el mostrador y hay que llevarla al fregadero
	if shift != null and shift.dirty_trays():
		sp.make_dirty()
	Events.order_closed.emit(order, "ok" if ok else "wrong")

func _expire(order: Order) -> void:
	order.state = Order.State.CANCELLED
	order.satisfaction = 0.0
	active.erase(order)
	var taken := EconomyManager.penalize(order.penalty, "expired_order") if shift == null or shift.mode_factor() > 0.0 else 0
	if shift != null:
		shift.register_expired(order, taken)
	AudioManager.play_sfx("lose", -10.0, 1.4)
	Events.toast.emit(Loc.t("toast.order_expired"), "warn")
	var sp := order.service_point
	if sp != null:
		sp.order = null
	Events.order_closed.emit(order, "expired")

func has_open_orders() -> bool:
	return not active.is_empty()
