class_name PackAPunch
extends Interactable
## "LA FORJA": upgrades the held weapon (damage, magazine, fire rate, special
## round effect, new name and glowing camo) after a short processing sequence.

const PRICE := 5000
const PROCESS_TIME := 3.6
const OFFER_TIME := 10.0

enum State { IDLE, PROCESSING, READY }

var state := State.IDLE
var _slot: WeaponHolder.WeaponSlot
var _owner_player: Player
var _t := 0.0
var _core: MeshInstance3D
var _light: OmniLight3D
var _rings: Array[Node3D] = []
var _display: Node3D


func _ready() -> void:
	super._ready()
	interact_radius = 2.6
	focus_offset = Vector3(0, 1.2, 0.9)
	var vis := MapKit.forge_visual()
	add_child(vis)
	_core = vis.get_node_or_null("Core")
	for c in vis.get_children():
		if c.name.begins_with("Ring"):
			_rings.append(c)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 1.0, 0.3)
	_light.omni_range = 6.0
	_light.light_energy = 1.5
	_light.position = Vector3(0, 1.4, 0.8)
	_light.shadow_enabled = false
	add_child(_light)
	_display = Node3D.new()
	_display.position = Vector3(0, 1.25, 0.95)
	add_child(_display)
	var lbl := make_price_label("LA FORJA  %d" % PRICE, Color(0.6, 1.0, 0.35))
	lbl.position = Vector3(0, 3.1, 0)
	add_child(lbl)


func is_available(p: Player) -> bool:
	if state == State.PROCESSING:
		return false
	if state == State.READY:
		return p == _owner_player
	var s := p.weapons.current_slot()
	return s != null and not s.upgraded


func get_prompt(p: Player) -> Dictionary:
	if state == State.READY and _slot:
		return {"title": "TOMAR " + _slot.display_name(), "subtitle": "Arma mejorada lista", "price": 0,
			"icon": _slot.data.icon_name, "can_afford": true, "action": "TOMAR"}
	var s := p.weapons.current_slot()
	var nm := s.data.upgraded_name if s else ""
	return {"title": "LA FORJA", "subtitle": "Mejora tu arma a %s: más daño, munición y efecto especial." % nm,
		"price": PRICE, "icon": "forge", "can_afford": GameState.can_afford(PRICE), "action": "MEJORAR"}


func interact(p: Player) -> void:
	match state:
		State.IDLE:
			var s := p.weapons.current_slot()
			if s == null or s.upgraded or p.weapons.slots.size() == 0:
				return
			if not try_buy(PRICE):
				return
			_owner_player = p
			_slot = p.weapons.take_current()
			if p.weapons.slots.is_empty():
				# never leave the player unarmed: lend a pistol while forging
				p.weapons.give_weapon(load("res://resources/weapons/pistol.tres"))
			state = State.PROCESSING
			_t = PROCESS_TIME
			Audio.play_at("forge_start", global_position + Vector3.UP, 4.0, 0.0, 50.0)
			_show_weapon()
		State.READY:
			if p != _owner_player:
				return
			p.weapons.weapons_changed_restore(_slot)
			Audio.play("weapon_take", 0.0)
			FX.energy_burst(p.global_position + Vector3.UP * 1.3, _slot.data.pap_tint)
			_reset()
	used.emit(p)


func _show_weapon() -> void:
	for c in _display.get_children():
		c.queue_free()
	var m: Node3D = load(_slot.data.model_path).instantiate()
	m.rotation_degrees = Vector3(0, 90, 0)
	_display.add_child(m)
	_display.position.z = -0.4


func _process(delta: float) -> void:
	var k := 1.0
	match state:
		State.PROCESSING:
			_t -= delta
			k = 4.0
			_display.position.z = lerpf(-0.4, 0.95, 1.0 - _t / PROCESS_TIME)
			if randf() < delta * 10.0:
				FX.impact(global_position + Vector3(randf_range(-0.6, 0.6), 1.3, 0.6), Vector3.UP, "metal")
			if _t <= 0.0:
				_slot.upgraded = true
				_apply_camo()
				state = State.READY
				_t = OFFER_TIME
				FX.energy_burst(_display.global_position, _slot.data.pap_tint)
				FX.shockwave(global_position + Vector3.UP * 0.1, _slot.data.pap_tint, 4.0)
				Audio.play_at("forge_done", global_position + Vector3.UP, 4.0, 0.0, 50.0)
		State.READY:
			_t -= delta
			k = 2.0
			_display.rotation.y += delta * 1.5
			if _t <= 0.0:
				# unclaimed weapons go back to the owner anyway (no frustration)
				if is_instance_valid(_owner_player) and _owner_player.alive:
					_owner_player.weapons.weapons_changed_restore(_slot)
				_reset()
	for i in _rings.size():
		_rings[i].rotation.y += delta * k * (1.0 if i % 2 == 0 else -1.3)
	_light.light_energy = 1.3 + sin(Time.get_ticks_msec() * 0.006) * 0.3 * k


func _apply_camo() -> void:
	var ov := StandardMaterial3D.new()
	ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ov.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ov.albedo_color = Color(_slot.data.pap_tint.r, _slot.data.pap_tint.g, _slot.data.pap_tint.b, 0.35)
	for mi in _display.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = ov


func _reset() -> void:
	state = State.IDLE
	_slot = null
	_owner_player = null
	for c in _display.get_children():
		c.queue_free()
