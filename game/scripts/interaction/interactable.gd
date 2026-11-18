class_name Interactable
extends Node3D
## Base for everything the player can buy or use. The HUD reads get_prompt()
## to show name, price, icon and description; TouchControls requires a short
## hold to confirm purchases (prevents accidental buys on touch screens).

signal used(by: Player)

@export var interact_radius := 2.0
@export var focus_offset := Vector3(0, 1.2, 0)
## Continuous interactables (barricade repair) act while the button is held.
var continuous := false
var _holding := false


func _ready() -> void:
	add_to_group("interactable")


func focus_point() -> Vector3:
	return global_position + global_basis * focus_offset


func is_available(_p: Player) -> bool:
	return true


## {title, subtitle, price, icon, can_afford, action}
func get_prompt(_p: Player) -> Dictionary:
	return {"title": "", "subtitle": "", "price": 0, "icon": "interact", "can_afford": true, "action": "USAR"}


func interact(_p: Player) -> void:
	pass


func hold(p: Player, active: bool) -> void:
	_holding = active
	if active:
		_hold_start(p)


func _hold_start(_p: Player) -> void:
	pass


func try_buy(cost: int) -> bool:
	if cost <= 0:
		return true
	if GameState.spend(cost):
		Audio.play("purchase", -2.0, 0.0)
		return true
	Audio.play("deny", -4.0, 0.0)
	return false


static func make_price_label(text: String, color: Color = Color(1, 0.82, 0.3)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.title_font()
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.double_sided = true
	l.visibility_range_end = 14.0
	return l
