class_name PerkMachine
extends Interactable
## Vending machine that grants a perk.

@export var perk_id := "vitality"
var perk: PerkData
var _screen_light: OmniLight3D


func _ready() -> void:
	super._ready()
	interact_radius = 2.3
	focus_offset = Vector3(0, 1.3, 0.6)
	perk = load("res://resources/perks/%s.tres" % perk_id)
	add_child(MapKit.perk_machine_visual(perk.color, perk.icon_name))
	_screen_light = OmniLight3D.new()
	_screen_light.light_color = perk.color
	_screen_light.omni_range = 4.0
	_screen_light.light_energy = 1.4
	_screen_light.position = Vector3(0, 1.6, 0.9)
	_screen_light.shadow_enabled = false
	add_child(_screen_light)
	var lbl := make_price_label("%s  %d" % [perk.display_name, perk.price], perk.color.lightened(0.3))
	lbl.position = Vector3(0, 2.55, 0)
	add_child(lbl)


func _process(_d: float) -> void:
	_screen_light.light_energy = 1.2 + sin(Time.get_ticks_msec() * 0.004 + global_position.x) * 0.25


func is_available(p: Player) -> bool:
	return not p.has_perk(perk_id)


func get_prompt(_p: Player) -> Dictionary:
	return {"title": perk.display_name, "subtitle": perk.description, "price": perk.price,
		"icon": perk.icon_name, "can_afford": GameState.can_afford(perk.price), "action": "BEBER"}


func interact(p: Player) -> void:
	if p.has_perk(perk_id) or not try_buy(perk.price):
		return
	Audio.play("perk_drink", 0.0)
	FX.energy_burst(global_position + Vector3.UP * 1.4 + global_basis.z * 0.8, perk.color)
	p.weapons.play_throw()
	get_tree().create_timer(0.8).timeout.connect(func():
		p.add_perk(perk_id)
		Audio.play("perk_gain", -2.0))
	used.emit(p)
