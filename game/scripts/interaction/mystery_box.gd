class_name MysteryBox
extends Interactable
## Random weapon box: light beam, cycling weapon models, weighted odds,
## occasional relocation. Never blocks the round flow (all async tweens).

signal relocated(new_index: int)

const PRICE := 950
const CYCLE_TIME := 3.2
const OFFER_TIME := 7.0

enum State { IDLE, ROLLING, OFFER, LEAVING, AWAY }

var locations: Array[Transform3D] = []
var location_index := 0
var state := State.IDLE
var uses := 0
var _pool: Array[WeaponData] = []
var _offer: WeaponData
var _offer_owner: Player
var _display: Node3D
var _display_model: Node3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _lid: Node3D
var _t := 0.0
var _cycle_t := 0.0
var _models := {}


func _ready() -> void:
	super._ready()
	interact_radius = 2.4
	focus_offset = Vector3(0, 0.9, 0)
	for id in ["shotgun", "smg", "rifle", "sniper", "lmg"]:
		var d: WeaponData = load("res://resources/weapons/%s.tres" % id)
		if d.in_box:
			_pool.append(d)
	var body := MapKit.mystery_box_visual()
	add_child(body)
	_lid = body.get_node_or_null("Lid")
	_display = Node3D.new()
	_display.position = Vector3(0, 1.1, 0)
	add_child(_display)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.55
	cm.height = 9.0
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(0.5, 1.0, 0.3, 0.16)
	_beam.material_override = bm
	_beam.position.y = 4.8
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 1.0, 0.35)
	_light.omni_range = 5.0
	_light.light_energy = 1.0
	_light.position.y = 1.4
	_light.shadow_enabled = false
	add_child(_light)
	var lbl := make_price_label("? %d" % PRICE, Color(0.6, 1.0, 0.35))
	lbl.position = Vector3(0, 1.6, 0)
	lbl.name = "PriceLabel"
	add_child(lbl)


func is_available(p: Player) -> bool:
	match state:
		State.IDLE:
			return true
		State.OFFER:
			return p == _offer_owner
	return false


func get_prompt(p: Player) -> Dictionary:
	if state == State.OFFER and _offer:
		var owned := p.weapons.has_weapon(_offer.id)
		return {"title": "TOMAR " + _offer.display_name, "subtitle": _offer.description + (" (ya la tienes: recarga)" if owned else ""),
			"price": 0, "icon": _offer.icon_name, "can_afford": true, "action": "TOMAR"}
	return {"title": "CAJA MISTERIOSA", "subtitle": "Un arma al azar. ¿Te sientes con suerte?", "price": PRICE,
		"icon": "mystery", "can_afford": GameState.can_afford(PRICE), "action": "ABRIR"}


func interact(p: Player) -> void:
	if state == State.IDLE:
		if not try_buy(PRICE):
			return
		_start_roll(p)
	elif state == State.OFFER and p == _offer_owner:
		p.weapons.give_weapon(_offer)
		Audio.play("weapon_take", -2.0)
		_close()
	used.emit(p)


func _start_roll(p: Player) -> void:
	state = State.ROLLING
	uses += 1
	_offer_owner = p
	_t = CYCLE_TIME
	_cycle_t = 0.0
	Audio.play_at("box_open", global_position + Vector3.UP, 2.0, 0.0, 40.0)
	FX.energy_burst(global_position + Vector3.UP, Color(0.55, 1.0, 0.3))
	if _lid:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", deg_to_rad(-100), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_light.light_energy = 3.0
	# decide outcome now (weighted, excluding weapons already owned)
	var leave := uses >= 4 and locations.size() > 1 and randf() < 0.12
	_offer = null if leave else _roll_weapon(p)


func _roll_weapon(p: Player) -> WeaponData:
	var total := 0.0
	var candidates: Array[WeaponData] = []
	for d in _pool:
		if p.weapons.has_weapon(d.id):
			continue
		candidates.append(d)
		total += d.box_weight
	if candidates.is_empty():
		return _pool[randi() % _pool.size()]
	var r := randf() * total
	for d in candidates:
		r -= d.box_weight
		if r <= 0.0:
			return d
	return candidates.back()


func _process(delta: float) -> void:
	_beam.rotation.y += delta * 0.6
	match state:
		State.ROLLING:
			_t -= delta
			_cycle_t -= delta
			_display.position.y = lerpf(_display.position.y, 1.55, delta * 3.0)
			if _cycle_t <= 0.0:
				_cycle_t = lerpf(0.06, 0.28, 1.0 - _t / CYCLE_TIME)
				_show_model(_pool[randi() % _pool.size()])
				Audio.play_at("box_tick", global_position + Vector3.UP, -8.0, 0.1, 20.0)
			_display.rotation.y += delta * 4.0
			if _t <= 0.0:
				if _offer == null:
					_leave()
				else:
					_show_model(_offer)
					state = State.OFFER
					_t = OFFER_TIME
					Audio.play_at("box_reveal", global_position + Vector3.UP, 0.0, 0.0, 40.0)
					FX.energy_burst(_display.global_position, Color(1.0, 0.85, 0.3))
		State.OFFER:
			_t -= delta
			_display.rotation.y += delta * 1.2
			_display.position.y = 1.55 - (1.0 - _t / OFFER_TIME) * 0.6
			if _t <= 0.0:
				_close()
		State.LEAVING:
			_t -= delta
			position.y += delta * 2.5
			rotation.y += delta * 6.0
			if _t <= 0.0:
				_relocate()


func _show_model(d: WeaponData) -> void:
	if _display_model:
		_display_model.visible = false
	if not _models.has(d.id):
		var m: Node3D = load(d.model_path).instantiate()
		m.scale = Vector3.ONE * 1.1
		m.rotation_degrees = Vector3(0, 90, 0)
		_display.add_child(m)
		_models[d.id] = m
	_display_model = _models[d.id]
	_display_model.visible = true


func _close() -> void:
	state = State.IDLE
	_offer = null
	if _display_model:
		_display_model.visible = false
	_display.position.y = 1.1
	_light.light_energy = 1.0
	if _lid:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", 0.0, 0.35)
	Audio.play_at("box_close", global_position + Vector3.UP, -4.0, 0.0, 25.0)


func _leave() -> void:
	# "Bad luck": refund and fly away to another location
	state = State.LEAVING
	_t = 2.0
	if _display_model:
		_display_model.visible = false
	GameState.add_points(PRICE)
	Audio.play_at("box_leave", global_position + Vector3.UP, 4.0, 0.0, 60.0)
	FX.energy_burst(global_position + Vector3.UP, Color(1.0, 0.3, 0.2))


func _relocate() -> void:
	var choices := []
	for i in locations.size():
		if i != location_index:
			choices.append(i)
	location_index = choices[randi() % choices.size()]
	global_transform = locations[location_index]
	uses = 0
	_close()
	FX.energy_burst(global_position + Vector3.UP, Color(0.55, 1.0, 0.3))
	relocated.emit(location_index)
