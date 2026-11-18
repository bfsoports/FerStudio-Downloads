class_name CustomerSpawner
extends Node
## Genera clientes según el ritmo del nivel, los coloca en los puestos o en la fila de detrás (sin amontonarse),
## crea su pedido al llegar al mostrador y gestiona su salida. Nunca elimina clientes al azar.

var restaurant: Restaurant = null
var orders: OrderManager = null
var shift: ShiftManager = null
var _timer := 0.0
var _customers: Array = []

func setup(r: Restaurant, o: OrderManager, s: ShiftManager) -> void:
	restaurant = r
	orders = o
	shift = s
	Events.shift_started.connect(_on_shift_started)
	Events.order_closed.connect(_on_order_closed)

func _on_shift_started(_cfg: Dictionary) -> void:
	_timer = 1.5

func _process(delta: float) -> void:
	if shift == null or not shift.running or not bool(shift.config.get("auto_spawn", true)):
		return
	_timer -= delta
	if _timer <= 0.0:
		_try_spawn()
		_timer = float(shift.config.get("spawn_interval", 20.0)) * randf_range(0.85, 1.15)

func _lane_count() -> int:
	var want := mini(Util.to_int(shift.config.get("max_active", 1), 1), EconomyManager.service_points())
	return clampi(want, 1, restaurant.service_points.size())

## Hace entrar a un cliente ahora mismo (lo usa el tutorial, que desactiva la llegada automática con auto_spawn).
func spawn_now() -> bool:
	if shift == null or not shift.running:
		return false
	return _try_spawn()

func _try_spawn() -> bool:
	var lanes := _lane_count()
	var chosen: ServicePoint = null
	var to_back := false
	for i in lanes:
		var sp := restaurant.service_points[i] as ServicePoint
		if sp.customer == null:
			chosen = sp
			break
	if chosen == null:
		for i in lanes:
			var sp2 := restaurant.service_points[i] as ServicePoint
			if sp2.waiting == null:
				chosen = sp2
				to_back = true
				break
	if chosen == null:
		return false
	_spawn_customer(chosen, to_back)
	return true

func _spawn_customer(sp: ServicePoint, to_back: bool) -> void:
	var route: Dictionary = Catalog.layout.get("customer_route", {})
	var spawn: Dictionary = route.get("spawn", {})
	var c := Customer.new()
	c.setup(_random_look())
	restaurant.add_child(c)
	c.position = Vector3(float(spawn.get("x", 7.0)), 0.0, float(spawn.get("z", -12.5)))
	c.service_point = sp
	if to_back:
		sp.waiting = c
	else:
		sp.customer = c
	c.walk(_entry_path(sp, to_back))
	c.arrived.connect(_on_arrived.bind(c, sp, to_back), CONNECT_ONE_SHOT)
	_customers.append(c)

func _entry_path(sp: ServicePoint, to_back: bool) -> Array:
	var route: Dictionary = Catalog.layout.get("customer_route", {})
	var door: Dictionary = route.get("door", {})
	var dx := float(door.get("x", 7.0))
	var turn_z := float(route.get("turn_z", -4.8))
	var lane_x := sp.global_position.x
	var path: Array = [Vector3(dx, 0, float(door.get("z", -8.2))), Vector3(dx, 0, turn_z), Vector3(lane_x, 0, turn_z), Vector3(lane_x, 0, sp.back_pos.z)]
	if not to_back:
		path.append(Vector3(lane_x, 0, sp.front_pos.z))
	return path

func _exit_path(sp: ServicePoint) -> Array:
	var route: Dictionary = Catalog.layout.get("customer_route", {})
	var door: Dictionary = route.get("door", {})
	var spawn: Dictionary = route.get("spawn", {})
	var dx := float(door.get("x", 7.0))
	var turn_z := float(route.get("turn_z", -4.8))
	var side_x := sp.global_position.x + 1.6
	return [Vector3(side_x, 0, sp.front_pos.z), Vector3(side_x, 0, turn_z), Vector3(dx, 0, turn_z), Vector3(dx, 0, float(door.get("z", -8.2))), Vector3(dx, 0, float(spawn.get("z", -12.5)))]

func _on_arrived(c: Customer, sp: ServicePoint, to_back: bool) -> void:
	if not is_instance_valid(c):
		return
	if to_back:
		if sp.customer == null and sp.waiting == c:
			_promote(sp)
		else:
			c.state = Customer.State.QUEUING
			c.face_counter()
		return
	_start_order(c, sp)

## El cliente de la fila de detrás avanza al puesto libre.
func _promote(sp: ServicePoint) -> void:
	var c := sp.waiting
	if c == null:
		return
	sp.customer = c
	sp.waiting = null
	c.walk([Vector3(sp.global_position.x, 0, sp.front_pos.z)])
	c.arrived.connect(_start_order.bind(c, sp), CONNECT_ONE_SHOT)

func _start_order(c: Customer, sp: ServicePoint) -> void:
	if not is_instance_valid(c) or shift == null or not shift.running:
		return
	c.state = Customer.State.WAITING
	c.face_counter()
	var patience := float(shift.config.get("patience", 60.0)) * EconomyManager.patience_mult()
	var o := orders.create_order(sp, c, _pick_recipe(), patience)
	c.show_order(o)

func _pick_recipe() -> String:
	var pool: Array = shift.config.get("recipes", ["classic"])
	if pool.size() > 2 and randf() < 0.5:
		return str(pool[randi_range(pool.size() - 2, pool.size() - 1)])
	return str(pool[randi() % pool.size()])

func _random_look() -> Dictionary:
	var l: Dictionary = Catalog.customer_look
	var out: Dictionary = {}
	for key in ["skin", "shirt", "pants", "hair", "hats"]:
		var arr: Array = l.get(key, [])
		if not arr.is_empty():
			out["hat" if key == "hats" else key] = arr[randi() % arr.size()]
	# cuerpo real (maniquí o esqueleto de KayKit); el color de "shirt" tiñe al maniquí
	out["body"] = CharacterLib.random_body()
	return out

func _on_order_closed(order: RefCounted, outcome: String) -> void:
	var o := order as Order
	if o == null:
		return
	var c := o.customer as Customer
	var sp := o.service_point
	if c == null or not is_instance_valid(c):
		return
	c.react(o.satisfaction, outcome)
	await get_tree().create_timer(0.9, false).timeout
	if not is_instance_valid(c):
		return
	c.state = Customer.State.LEAVING
	c.walk(_exit_path(sp))
	c.arrived.connect(_on_left.bind(c), CONNECT_ONE_SHOT)
	sp.release_customer()
	if sp.waiting != null:
		_promote(sp)

func _on_left(c: Customer) -> void:
	_customers.erase(c)
	if is_instance_valid(c):
		c.queue_free()
