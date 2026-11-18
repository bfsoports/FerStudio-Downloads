class_name Door
extends Interactable
## Purchasable debris / gate that blocks access to another zone.

signal opened(door: Door)

@export var price := 750
@export var title := "DESPEJAR ESCOMBROS"
@export var zone_a := ""
@export var zone_b := ""
@export var size := Vector3(3.0, 3.0, 0.6)
@export var style := "debris"      # debris | gate

var is_open := false
var _body: StaticBody3D
var _visual: Node3D


func _ready() -> void:
	super._ready()
	interact_radius = 2.6
	focus_offset = Vector3(0, 1.2, 0)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	_body.add_child(cs)
	add_child(_body)
	_visual = MapKit.door_visual(style, size)
	add_child(_visual)
	var lbl := make_price_label(str(price))
	lbl.position = Vector3(0, size.y + 0.35, 0)
	add_child(lbl)


func is_available(_p: Player) -> bool:
	return not is_open


func get_prompt(_p: Player) -> Dictionary:
	return {"title": title, "subtitle": "Abre el acceso a una nueva zona", "price": price, "icon": "door",
		"can_afford": GameState.can_afford(price), "action": "COMPRAR"}


func interact(p: Player) -> void:
	if is_open or not try_buy(price):
		return
	open_door()
	used.emit(p)


func open_door() -> void:
	is_open = true
	remove_from_group("interactable")
	_body.collision_layer = 0
	for c in get_children():
		if c is Label3D:
			c.queue_free()
	Audio.play_at("door_open", global_position + Vector3.UP, 2.0, 0.05, 40.0)
	FX.impact(global_position + Vector3.UP * 0.5, Vector3.UP, "dirt")
	FX.shake(0.3, 0.4)
	var tw := create_tween().set_parallel(true)
	if style == "gate":
		tw.tween_property(_visual, "position:y", size.y + 0.2, 1.4).set_trans(Tween.TRANS_SINE)
	else:
		tw.tween_property(_visual, "position:y", -size.y - 0.2, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_visual, "rotation:z", 0.25, 1.3)
	tw.chain().tween_callback(func(): _visual.visible = false)
	opened.emit(self)
