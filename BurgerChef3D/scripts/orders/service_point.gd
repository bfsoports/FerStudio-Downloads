class_name ServicePoint
extends Station
## Puesto del mostrador: la bandeja (3 ranuras: hamburguesa, acompañamiento y bebida) donde se prepara el pedido
## del cliente que espera delante. Se entrega con la campana (ServiceBell). Con las bandejas sucias activadas, tras
## cada entrega la bandeja queda sucia (DirtyTray) y el puesto no admite nada hasta que se lava en el fregadero.

const SLOT_MAIN := 0
const SLOT_SIDE := 1
const SLOT_DRINK := 2

var index: int = 0
var customer: Customer = null      # cliente asignado al puesto (puede estar aún caminando)
var waiting: Customer = null       # cliente que espera detrás
var order: Order = null
var orders: OrderManager = null
var open: bool = true
var front_pos: Vector3 = Vector3.ZERO
var back_pos: Vector3 = Vector3.ZERO
var has_tray: bool = true
var dirty_tray: DirtyTray = null   # bandeja sucia de este puesto (en el mostrador, en la mano o en el fregadero)
var tray_model: Node3D = null
var _tray_scale := Vector3.ONE
var _slot_y := 1.0
var _closed_label: Label3D = null

func configure(i: int, slot_y: float, front: Vector3, back: Vector3) -> void:
	kind = "tray"
	index = i
	_slot_y = slot_y
	front_pos = front
	back_pos = back
	add_slot(Vector3(-0.45, slot_y, 0.0))
	add_slot(Vector3(0.05, slot_y, 0.0))
	add_slot(Vector3(0.5, slot_y, 0.0))
	_closed_label = Prims.label3d(self, Loc.t("label.closed"), Vector3(0, slot_y + 0.45, 0), 0.006, 56, Palette.CREAM)
	set_open(true)

func set_open(v: bool) -> void:
	open = v
	_closed_label.visible = not v

func slot_for(item: Carryable) -> int:
	if item is BurgerStack:
		return SLOT_MAIN
	var fi := item as FoodItem
	if fi != null:
		if fi.ingredient_id == "fries":
			return SLOT_SIDE
		if fi.ingredient_id == "drink":
			return SLOT_DRINK
	return -1

func set_tray_model(m: Node3D) -> void:
	tray_model = m
	_tray_scale = m.scale

## La bandeja del puesto se ensucia tras una entrega: desaparece la limpia y queda una DirtyTray en el mostrador.
func make_dirty() -> void:
	if not has_tray:
		return
	has_tray = false
	if tray_model != null:
		tray_model.visible = false
	var t := DirtyTray.new().setup(self)
	add_child(t)
	t.position = Vector3(0.0, _slot_y - 0.03, 0.0)
	dirty_tray = t
	Events.tray_dirtied.emit(index)

## La bandeja vuelve limpia al puesto (al terminar de lavarse en el fregadero).
func restore_tray() -> void:
	has_tray = true
	dirty_tray = null
	if tray_model != null:
		tray_model.visible = true
		tray_model.scale = Vector3(_tray_scale.x, _tray_scale.y * 0.4, _tray_scale.z)
		create_tween().tween_property(tray_model, "scale:y", _tray_scale.y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Events.tray_restored.emit(index)

func reject_reason(item: Carryable) -> String:
	if not open:
		return "reject.closed"
	if not has_tray:
		return "reject.no_tray"
	var s := slot_for(item)
	if s < 0:
		return "reject.not_servable"
	if slot_items[s] != null:
		return "reject.slot_busy"
	return ""

func free_slot_index(item: Carryable, _near_world: Vector3 = Vector3.INF) -> int:
	var s := slot_for(item)
	if s >= 0 and slot_items[s] == null:
		return s
	return -1

func on_item_placed(_idx: int, _item: Carryable) -> void:
	if orders != null:
		orders.tray_changed(self)

func on_item_removed(_idx: int, _item: Carryable) -> void:
	if orders != null:
		orders.tray_changed(self)

func tray_contents() -> Dictionary:
	return {"main": slot_items[SLOT_MAIN], "side": slot_items[SLOT_SIDE], "drink": slot_items[SLOT_DRINK]}

func try_deliver() -> void:
	if orders != null:
		orders.deliver(self)

func release_customer() -> void:
	customer = null
	order = null
