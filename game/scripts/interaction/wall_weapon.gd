class_name WallWeapon
extends Interactable
## Weapon bought from a wall mount. Buying it again refills ammo.

@export var weapon_id := "smg"
var data: WeaponData


func _ready() -> void:
	super._ready()
	interact_radius = 2.2
	focus_offset = Vector3(0, 1.45, 0.15)
	data = load("res://resources/weapons/%s.tres" % weapon_id)
	# chalk-style plate + real weapon model
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.5, 0.75, 0.04)
	plate.mesh = pm
	plate.material_override = MapKit.mat("wallbuy")
	plate.position = Vector3(0, 1.45, 0.02)
	add_child(plate)
	if ResourceLoader.exists(data.model_path):
		var m: Node3D = load(data.model_path).instantiate()
		var length := 1.0
		match data.category:
			WeaponData.Category.PISTOL: length = 0.6
			WeaponData.Category.SMG: length = 1.0
			_: length = 1.0
		m.scale = Vector3.ONE * length
		m.rotation_degrees = Vector3(0, 90, 0)
		m.position = Vector3(0.35 if data.category != WeaponData.Category.PISTOL else 0.15, 1.45, 0.12)
		add_child(m)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.omni_range = 2.2
	glow.light_energy = 0.6
	glow.position = Vector3(0, 1.5, 0.6)
	glow.shadow_enabled = false
	add_child(glow)
	var lbl := make_price_label("%s  %d" % [data.display_name, data.wall_cost])
	lbl.font_size = 34
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.position = Vector3(0, 1.0, 0.08)
	add_child(lbl)


func _ammo_price(p: Player) -> int:
	var s := p.weapons.find_slot(weapon_id)
	if s and s.upgraded:
		return data.ammo_cost * 4
	return data.ammo_cost


func get_prompt(p: Player) -> Dictionary:
	var owned := p.weapons.has_weapon(weapon_id)
	var price := _ammo_price(p) if owned else data.wall_cost
	return {
		"title": ("MUNICIÓN: " if owned else "") + data.display_name,
		"subtitle": data.description if not owned else "Recarga toda la munición de reserva",
		"price": price, "icon": data.icon_name if not owned else "ammo",
		"can_afford": GameState.can_afford(price), "action": "COMPRAR",
	}


func interact(p: Player) -> void:
	var owned := p.weapons.has_weapon(weapon_id)
	if owned:
		var s := p.weapons.find_slot(weapon_id)
		if s.reserve >= s.max_reserve():
			Audio.play("deny", -4.0)
			return
		if try_buy(_ammo_price(p)):
			p.weapons.refill(weapon_id)
			Audio.play("ammo_pickup", -2.0)
	else:
		if try_buy(data.wall_cost):
			p.weapons.give_weapon(data)
	used.emit(p)
