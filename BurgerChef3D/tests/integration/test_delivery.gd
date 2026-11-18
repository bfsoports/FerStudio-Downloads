extends RefCounted
## Entrega de pedidos de principio a fin con objetos reales: correcta, incorrecta, caducada y con componentes que faltan.

func _cooked(id: String) -> FoodItem:
	var it := FoodItem.new().setup(id)
	if it.is_cookable():
		it.cook_progress = float(Catalog.cook_config(id)["cook_time"]) + 0.5
		it.state = FoodItem.State.COOKED
	return it

func _burger(t, ids: Array) -> BurgerStack:
	var s := BurgerStack.new().setup()
	t.add_child(s)
	for id in ids:
		var it := _cooked(str(id))
		s.add_layer(it)
		it.free()
	return s

func run(t) -> void:
	GameState.reset_to_defaults()
	var shift := ShiftManager.new()
	t.add_child(shift)
	shift.start({"mode": "campaign", "level_id": 1, "duration": 100.0, "recipes": ["classic", "combo"], "win": {"orders": 1},
		"lose": {"max_failed": 5}, "star_income": [10, 20], "patience": 60.0, "spawn_interval": 20.0, "max_active": 1})
	var orders := OrderManager.new()
	orders.shift = shift
	t.add_child(orders)
	var sp := ServicePoint.new()
	sp.configure(0, 1.0, Vector3(0, 0, -1), Vector3(0, 0, -2))
	t.add_child(sp)
	sp.orders = orders
	var cust := Customer.new()
	cust.setup({})
	t.add_child(cust)
	sp.customer = cust

	# A) entrega correcta
	var o := orders.create_order(sp, cust, "classic", 60.0)
	t.eq(o.state, Order.State.WAITING, "el pedido nace esperando")
	t.eq(o.components.size(), 1, "una hamburguesa = un componente")
	sp.place(_burger(t, ["bun_bottom", "patty", "lettuce", "tomato", "bun_top"]), 0)
	t.eq(o.state, Order.State.READY, "con la hamburguesa cerrada el pedido está listo")
	var before := GameState.coins
	orders.deliver(sp)
	t.eq(o.state, Order.State.DELIVERED, "el pedido se entrega")
	t.ok(GameState.coins > before, "se cobran monedas")
	t.eq(int(shift.stats["orders_ok"]), 1, "cuenta como pedido correcto")
	t.eq(int(shift.stats["customers"]), 1, "cuenta como cliente atendido")
	t.ok(sp.order == null, "el puesto queda sin pedido")
	t.ok(GameState.xp > 0 or GameState.level > 1, "se concede experiencia")

	# B) entrega incorrecta (falta la lechuga)
	var o2 := orders.create_order(sp, cust, "classic", 60.0)
	sp.place(_burger(t, ["bun_bottom", "patty", "tomato", "bun_top"]), 0)
	before = GameState.coins
	orders.deliver(sp)
	t.eq(o2.state, Order.State.DELIVERED, "un pedido incorrecto también se entrega")
	t.eq(int(shift.stats["orders_wrong"]), 1, "cuenta como incorrecto")
	t.ok(GameState.coins <= before + 2, "un pedido incorrecto no da la recompensa completa")
	t.ok(o2.satisfaction < 0.3, "el cliente queda insatisfecho")

	# C) pedido caducado
	var o3 := orders.create_order(sp, cust, "classic", 0.5)
	orders._process(1.0)
	t.eq(o3.state, Order.State.CANCELLED, "un pedido sin paciencia se cancela")
	t.eq(int(shift.stats["orders_expired"]), 1, "cuenta como caducado")
	t.eq(int(shift.stats["failed"]), 2, "los fallos se acumulan")
	t.ok(not orders.has_open_orders(), "no quedan pedidos abiertos")

	# D) menú: faltan componentes y luego se completa
	var o4 := orders.create_order(sp, cust, "combo", 60.0)
	t.eq(o4.components.size(), 3, "el menú tiene tres componentes")
	sp.place(_burger(t, ["bun_bottom", "patty", "cheese", "bun_top"]), 0)
	t.eq(o4.state, Order.State.PREPARING, "con solo la hamburguesa está en preparación")
	orders.deliver(sp)
	t.ok(o4.is_open(), "si faltan componentes el pedido sigue abierto")
	t.eq(int(shift.stats["customers"]), 2, "no se atendió a nadie más")
	var fries := _cooked("fries")
	t.add_child(fries)
	sp.place(fries, 1)
	var drink := FoodItem.new().setup("drink")
	t.add_child(drink)
	sp.place(drink, 2)
	t.eq(o4.state, Order.State.READY, "con los tres componentes está listo")
	orders.deliver(sp)
	t.eq(o4.state, Order.State.DELIVERED, "el menú se entrega")
	t.eq(GameState.stat("combos_served"), 1, "se registra el menú servido")
	shift.finish("quit")
	for n in [shift, orders, sp, cust]:
		n.queue_free()
	GameState.reset_to_defaults()
