class_name WeaponHolder
extends Node3D
## Player inventory + first-person viewmodel + hitscan shooting.
## Bullets are raycasts (no projectile bodies): cheap and precise on mobile.

signal weapon_changed(slot: WeaponSlot)
signal ammo_changed(mag: int, reserve: int)
signal fired(slot: WeaponSlot)
signal hit_confirmed(headshot: bool, kill: bool)
signal reload_started(duration: float)
signal reload_finished

const MAX_SLOTS := 2
const VIEW_SCALE := 0.42
const ZOMBIE_MASK := 4
const WORLD_MASK := 1

class WeaponSlot:
	var data: WeaponData
	var upgraded := false
	var mag := 0
	var reserve := 0
	var view: Node3D
	var muzzle: Node3D
	var flash: Node3D
	var overlay: Material

	func display_name() -> String:
		return data.title(upgraded)

	func max_mag() -> int:
		return data.get_mag(upgraded)

	func max_reserve() -> int:
		return data.get_reserve(upgraded)


var slots: Array[WeaponSlot] = []
var current := -1
var aiming := false
var reloading := false

var _player: Player
var _pivot: Node3D
var _cooldown := 0.0
var _semi_ready := true
var _switching := 0.0
var _reload_timer := 0.0
var _kick := 0.0
var _kick_rot := 0.0
var _recoil_pitch_pending := 0.0
var _recoil_yaw_pending := 0.0
var _bloom := 0.0
var _ads_t := 0.0
var _sway := Vector2.ZERO
var _last_cam_basis: Basis
var _flash_timer := 0.0
var _flash_light: OmniLight3D
var _throw_anim := 0.0
var _dead := false
var _arms: Node3D
var _rng := RandomNumberGenerator.new()
var _model_cache := {}


func setup(player: Player) -> void:
	_player = player
	_pivot = Node3D.new()
	_pivot.name = "ViewPivot"
	add_child(_pivot)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.omni_range = 7.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	_flash_light.position = Vector3(0.1, -0.05, -0.6)
	_build_arms()


# --------------------------------------------------------------------------------
# inventory
# --------------------------------------------------------------------------------

func give_weapon(data: WeaponData, upgraded: bool = false) -> void:
	var existing := find_slot(data.id)
	if existing:
		existing.mag = existing.max_mag()
		existing.reserve = existing.max_reserve()
		if upgraded and not existing.upgraded:
			set_upgraded(existing, true)
		_select(slots.find(existing))
		return
	var s := WeaponSlot.new()
	s.data = data
	s.upgraded = upgraded
	s.mag = s.max_mag()
	s.reserve = s.max_reserve()
	_build_view(s)
	if slots.size() < MAX_SLOTS:
		slots.append(s)
		_select(slots.size() - 1)
	else:
		var old := slots[current]
		if old.view:
			old.view.queue_free()
		slots[current] = s
		_select(current, true)


func find_slot(id: String) -> WeaponSlot:
	for s in slots:
		if s.data.id == id:
			return s
	return null


func has_weapon(id: String) -> bool:
	return find_slot(id) != null


func current_slot() -> WeaponSlot:
	return slots[current] if current >= 0 and current < slots.size() else null


func refill(id: String) -> bool:
	var s := find_slot(id)
	if s == null:
		return false
	if s.reserve >= s.max_reserve() and s.mag >= s.max_mag():
		return false
	s.reserve = s.max_reserve()
	if s == current_slot():
		ammo_changed.emit(s.mag, s.reserve)
	return true


func refill_all() -> void:
	for s in slots:
		s.mag = s.max_mag()
		s.reserve = s.max_reserve()
	var c := current_slot()
	if c:
		ammo_changed.emit(c.mag, c.reserve)


func set_upgraded(s: WeaponSlot, value: bool) -> void:
	s.upgraded = value
	s.mag = s.max_mag()
	s.reserve = s.max_reserve()
	_apply_pap_look(s)
	if s == current_slot():
		weapon_changed.emit(s)
		ammo_changed.emit(s.mag, s.reserve)


func take_current() -> WeaponSlot:
	## Removes the current weapon (used by the Forge while it upgrades).
	var s := current_slot()
	if s == null:
		return null
	s.view.visible = false
	slots.remove_at(current)
	current = clampi(current, 0, slots.size() - 1) if slots.size() > 0 else -1
	if current >= 0:
		_select(current, true)
	else:
		weapon_changed.emit(null)
	return s


func return_slot(s: WeaponSlot) -> void:
	if slots.size() >= MAX_SLOTS:
		var old := slots[current]
		if old.view:
			old.view.queue_free()
		slots[current] = s
		_select(current, true)
	else:
		slots.append(s)
		_select(slots.size() - 1, true)


func weapons_changed_restore(s: WeaponSlot) -> void:
	## Gives back a weapon that was processed by the Forge (upgraded).
	var same := find_slot(s.data.id)
	if same:
		if same.view:
			same.view.queue_free()
		var idx := slots.find(same)
		slots[idx] = s
		_select(idx, true)
	else:
		return_slot(s)
	set_upgraded(s, true)


func switch_next() -> void:
	if slots.size() < 2 or busy():
		return
	_select((current + 1) % slots.size())


func _select(i: int, force: bool = false) -> void:
	if not force and i == current:
		return
	if reloading:
		reloading = false
	for k in slots.size():
		if slots[k].view:
			slots[k].view.visible = (k == i)
	current = i
	aiming = false
	var spd := 0.6 if _player and _player.has_perk("speed") else 1.0
	_switching = slots[i].data.switch_time * spd
	_pivot.position.y = -0.35
	Audio.play("weapon_switch", -6.0)
	weapon_changed.emit(slots[i])
	ammo_changed.emit(slots[i].mag, slots[i].reserve)
	_update_arms()


func busy() -> bool:
	return _switching > 0.0 or _throw_anim > 0.0


func move_speed_mult() -> float:
	var s := current_slot()
	return s.data.move_speed_mult if s else 1.0


func set_dead() -> void:
	_dead = true
	aiming = false
	var tw := create_tween()
	tw.tween_property(_pivot, "position:y", -0.6, 0.6)


# --------------------------------------------------------------------------------
# view model
# --------------------------------------------------------------------------------

func _build_view(s: WeaponSlot) -> void:
	var root := Node3D.new()
	root.name = "View_" + s.data.id
	var scn: PackedScene = _model_cache.get(s.data.model_path)
	if scn == null and ResourceLoader.exists(s.data.model_path):
		scn = load(s.data.model_path)
		_model_cache[s.data.model_path] = scn
	var model: Node3D = scn.instantiate() if scn else Node3D.new()
	root.add_child(model)
	root.scale = Vector3.ONE * VIEW_SCALE
	_pivot.add_child(root)
	s.view = root
	s.muzzle = model.find_child("Muzzle", true, false)
	if s.muzzle == null:
		s.muzzle = Node3D.new()
		model.add_child(s.muzzle)
		s.muzzle.position = Vector3(0, 0.03, -0.5)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = 2
	s.flash = _make_flash(s.data.muzzle_scale)
	s.muzzle.add_child(s.flash)
	if s.upgraded:
		_apply_pap_look(s)


func _make_flash(scale_: float) -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _flash_texture()
	mat.albedo_color = Color(1.0, 0.75, 0.35)
	for k in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.22, 0.22) * scale_
		q.mesh = qm
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.rotation = Vector3(0, deg_to_rad(90) if k == 1 else 0.0, 0)
		if k == 2:
			q.rotation = Vector3(deg_to_rad(90), 0, 0)
			qm.size = Vector2(0.12, 0.3) * scale_
		q.position.z = -0.06 * scale_
		n.add_child(q)
	n.visible = false
	return n


static var _flash_tex: Texture2D
static func _flash_texture() -> Texture2D:
	if _flash_tex:
		return _flash_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var v := Vector2(x - c, y - c) / c
			var ang := atan2(v.y, v.x)
			var star := 0.55 + 0.45 * absf(cos(ang * 3.0))
			var d := v.length() / star
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


func _apply_pap_look(s: WeaponSlot) -> void:
	if s.view == null:
		return
	var ov: StandardMaterial3D = null
	if s.upgraded:
		ov = StandardMaterial3D.new()
		ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ov.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ov.albedo_color = Color(s.data.pap_tint.r, s.data.pap_tint.g, s.data.pap_tint.b, 0.32)
		ov.rim_enabled = false
	for mi in s.view.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() == s.flash:
			continue
		(mi as MeshInstance3D).material_overlay = ov


func _build_arms() -> void:
	_arms = Node3D.new()
	_arms.name = "Arms"
	_pivot.add_child(_arms)
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.27, 0.32, 0.2)
	sleeve.roughness = 0.9
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.16, 0.13, 0.1)
	glove.roughness = 0.8
	for side in [1, -1]:
		var arm := Node3D.new()
		arm.name = "Right" if side == 1 else "Left"
		_arms.add_child(arm)
		var fore := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.045
		cm.height = 0.42
		cm.radial_segments = 8
		cm.rings = 2
		fore.mesh = cm
		fore.material_override = sleeve
		fore.rotation_degrees = Vector3(80, 0, 0)
		fore.position = Vector3(0, -0.04, 0.2)
		arm.add_child(fore)
		var hand := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.06, 0.09)
		hand.mesh = bm
		hand.material_override = glove
		arm.add_child(hand)
		for mi in [fore, hand]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers = 2


func _update_arms() -> void:
	var s := current_slot()
	if s == null or _arms == null:
		return
	var right := _arms.get_node("Right") as Node3D
	var left := _arms.get_node("Left") as Node3D
	# grip is at the weapon origin; fore-grip along the barrel
	var length := 0.22
	match s.data.category:
		WeaponData.Category.PISTOL:
			length = 0.05
		WeaponData.Category.SMG:
			length = 0.18
		WeaponData.Category.SHOTGUN:
			length = 0.38
		WeaponData.Category.SNIPER:
			length = 0.34
		_:
			length = 0.3
	right.position = Vector3(0.0, -0.035, 0.03) * VIEW_SCALE * 2.2
	left.position = Vector3(-0.01, -0.03, -length) * VIEW_SCALE * 2.2
	left.rotation_degrees = Vector3(0, -25, 0)
	right.rotation_degrees = Vector3(0, 8, 0)


# --------------------------------------------------------------------------------
# per-frame
# --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var s := current_slot()
	if s == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_switching = maxf(0.0, _switching - delta)
	_throw_anim = maxf(0.0, _throw_anim - delta)
	if not _player.fire_held:
		_semi_ready = true
	_update_reload(delta, s)
	# ADS blend
	_ads_t = move_toward(_ads_t, 1.0 if aiming else 0.0, delta * 6.5)
	var base := s.data.view_offset.lerp(s.data.ads_offset, _smooth(_ads_t))
	# sway from camera rotation
	var cam_basis := get_parent().global_basis as Basis
	if _last_cam_basis != Basis():
		var dq := (_last_cam_basis.inverse() * cam_basis).get_euler()
		_sway = _sway.lerp(Vector2(-dq.y, dq.x) * 1.8, delta * 10.0)
	_last_cam_basis = cam_basis
	_sway = _sway.lerp(Vector2.ZERO, delta * 6.0)
	var sway_amt := 1.0 - _ads_t * 0.8
	# walk bob
	var hv := Vector2(_player.velocity.x, _player.velocity.z).length()
	var t := Time.get_ticks_msec() / 1000.0
	var bob := Vector3(sin(t * 8.0) * 0.006, absf(cos(t * 8.0)) * 0.008, 0) * clampf(hv / 4.0, 0, 1.4) * sway_amt
	if _player.is_sprinting():
		bob *= 2.2
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	_kick_rot = lerpf(_kick_rot, 0.0, delta * 14.0)
	var target := base + Vector3(_sway.x * 0.04, _sway.y * 0.04, 0) * sway_amt + bob + Vector3(0, 0, _kick)
	var target_rot := Vector3(deg_to_rad(_kick_rot), 0, 0)
	if reloading:
		target += Vector3(-0.02, -0.06, 0.02)
		target_rot += Vector3(deg_to_rad(-18), deg_to_rad(12), deg_to_rad(28))
	if _player.is_sprinting():
		target += Vector3(-0.04, -0.03, 0.03)
		target_rot += Vector3(deg_to_rad(-12), deg_to_rad(35), deg_to_rad(10))
	if _switching > 0.0 or _throw_anim > 0.0:
		target.y -= 0.25 * clampf(maxf(_switching, _throw_anim) * 3.0, 0, 1)
	_pivot.position = _pivot.position.lerp(target, delta * 16.0)
	_pivot.rotation = _pivot.rotation.lerp(target_rot, delta * 14.0)
	# recoil applied to the camera over a few frames
	if absf(_recoil_pitch_pending) > 0.001:
		var step := _recoil_pitch_pending * minf(1.0, delta * 25.0)
		var ystep := _recoil_yaw_pending * minf(1.0, delta * 25.0)
		_player.add_recoil(step, ystep)
		_recoil_pitch_pending -= step
		_recoil_yaw_pending -= ystep
	_bloom = move_toward(_bloom, 0.0, delta * s.data.recoil_recovery * 0.6)
	# muzzle flash
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			s.flash.visible = false
			_flash_light.light_energy = 0.0


func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func target_fov(base_fov: float) -> float:
	var s := current_slot()
	if s == null:
		return base_fov
	return lerpf(base_fov, s.data.ads_fov, _smooth(_ads_t))


func ads_zoom_factor() -> float:
	var s := current_slot()
	return (s.data.ads_fov / 75.0) if s else 1.0


func toggle_aim() -> void:
	if _dead or current_slot() == null:
		return
	aiming = not aiming
	if aiming and reloading and not current_slot().data.reload_per_shell:
		aiming = false
	Audio.play("aim", -14.0)


func current_spread() -> float:
	var s := current_slot()
	if s == null:
		return 2.0
	var base := lerpf(s.data.spread_hip, s.data.spread_ads, _smooth(_ads_t))
	var hv := Vector2(_player.velocity.x, _player.velocity.z).length()
	base += clampf(hv / 4.5, 0.0, 1.0) * s.data.spread_move_penalty * (1.0 - _ads_t * 0.7)
	if not _player.is_on_floor():
		base += 2.0
	return base + _bloom


func play_throw() -> void:
	_throw_anim = 0.45


# --------------------------------------------------------------------------------
# shooting
# --------------------------------------------------------------------------------

func try_fire() -> void:
	var s := current_slot()
	if s == null or _dead or busy():
		return
	if _cooldown > 0.0:
		return
	if not s.data.automatic and not _semi_ready:
		return
	if reloading:
		if s.data.reload_per_shell and s.mag > 0:
			reloading = false
		else:
			return
	if s.mag <= 0:
		_semi_ready = false
		if s.reserve > 0:
			reload()
		else:
			Audio.play("dry_fire", -6.0, 0.02, 200)
		return
	_semi_ready = false
	_player.wants_sprint = false
	_cooldown = s.data.seconds_per_shot(s.upgraded)
	s.mag -= 1
	_fire_rays(s)
	# feedback
	s.flash.visible = true
	s.flash.rotation.z = randf() * TAU
	_flash_timer = 0.05
	_flash_light.light_energy = 2.2
	_kick = s.data.kick_back * (0.4 if aiming else 1.0)
	_kick_rot = s.data.kick_up * (0.4 if aiming else 1.0)
	var rec := 0.55 if aiming else 1.0
	_recoil_pitch_pending += s.data.recoil_pitch * rec
	_recoil_yaw_pending += _rng.randf_range(-s.data.recoil_yaw, s.data.recoil_yaw) * rec
	_bloom = minf(_bloom + s.data.recoil_pitch * 0.35, 4.0)
	var snd := s.data.fire_sound + ("_pap" if s.upgraded and ResourceLoader.exists("res://assets/audio/sfx/%s_pap.wav" % s.data.fire_sound) else "")
	Audio.play(snd, -1.0, 0.05)
	if s.data.category == WeaponData.Category.SHOTGUN or s.data.category == WeaponData.Category.SNIPER:
		FX.shake(0.25, 0.12)
		get_tree().create_timer(0.35).timeout.connect(func(): Audio.play("pump" if s.data.category == WeaponData.Category.SHOTGUN else "bolt", -6.0))
	fired.emit(s)
	ammo_changed.emit(s.mag, s.reserve)
	if s.mag == 0 and s.reserve > 0:
		get_tree().create_timer(0.25).timeout.connect(func():
			if current_slot() == s and s.mag == 0:
				reload())


func _fire_rays(s: WeaponSlot) -> void:
	var cam := get_parent() as Camera3D
	var origin := cam.global_position
	var space := get_world_3d().direct_space_state
	var spread := deg_to_rad(current_spread())
	var dmg := s.data.get_damage(s.upgraded) * _player.damage_multiplier()
	var penetration := s.data.penetration + (3 if s.upgraded and s.data.pap_effect == "piercing" else 0)
	var hits := {}     # zombie -> {damage, headshot, pos, dir}
	var muzzle_pos := s.muzzle.global_position
	var traced := false
	for p in maxi(1, s.data.pellets):
		var dir := -cam.global_basis.z
		if spread > 0.0:
			var r := sqrt(_rng.randf()) * tan(spread)
			var a := _rng.randf() * TAU
			dir = (dir + cam.global_basis.x * cos(a) * r + cam.global_basis.y * sin(a) * r).normalized()
		var from := origin
		var exclude: Array[RID] = [_player.get_rid()]
		var remaining := penetration + 1
		var end_point := origin + dir * s.data.max_range
		while remaining > 0:
			var q := PhysicsRayQueryParameters3D.create(from, origin + dir * s.data.max_range, WORLD_MASK | ZOMBIE_MASK, exclude)
			q.collide_with_areas = false
			var res := space.intersect_ray(q)
			if res.is_empty():
				break
			var col: Object = res.collider
			end_point = res.position
			if col is Zombie:
				var z := col as Zombie
				var dist := origin.distance_to(res.position)
				var falloff := 1.0
				if dist > s.data.falloff_start:
					falloff = lerpf(1.0, s.data.min_damage_factor, clampf((dist - s.data.falloff_start) / maxf(1.0, s.data.max_range - s.data.falloff_start), 0, 1))
				var head := z.is_headshot(res.position)
				var entry: Dictionary = hits.get(z, {"damage": 0.0, "headshot": false, "pos": res.position, "dir": dir})
				var d := dmg * falloff * (s.data.headshot_multiplier if head else 1.0)
				entry.damage += d * (0.75 if remaining <= penetration else 1.0)
				entry.headshot = entry.headshot or head
				hits[z] = entry
				FX.blood(res.position, -dir, 0.6 if s.data.pellets > 1 else 1.0)
				exclude.append(z.get_rid())
				from = res.position + dir * 0.05
				remaining -= 1
			else:
				var surf := "metal" if (col is Node and (col as Node).is_in_group("metal")) else "concrete"
				FX.impact(res.position, res.normal, surf)
				if s.upgraded and s.data.pap_effect == "explosive":
					_explosive_round(res.position, dmg)
				break
		if not traced and _rng.randf() < s.data.tracer_chance:
			traced = true
			FX.tracer(muzzle_pos, end_point, s.data.pap_tint if s.upgraded else Color(1.0, 0.85, 0.5))
	for z in hits:
		var e: Dictionary = hits[z]
		if not is_instance_valid(z):
			continue
		var killed: bool = (z as Zombie).take_hit(e.damage, e.pos, e.dir, e.headshot, self)
		hit_confirmed.emit(e.headshot, killed)
		FX.hit_marker.emit(e.headshot, killed)
		if s.upgraded and not killed:
			_apply_pap_effect(s, z as Zombie, e.damage, e.pos)
		elif s.upgraded and s.data.pap_effect == "explosive":
			_explosive_round(e.pos, dmg)


func _apply_pap_effect(s: WeaponSlot, z: Zombie, dmg: float, pos: Vector3) -> void:
	match s.data.pap_effect:
		"incendiary":
			z.ignite(dmg * 0.35, 3.0, self)
		"shock":
			var chained := 0
			for other in get_tree().get_nodes_in_group("zombie"):
				if other == z or not (other is Zombie) or not other.is_alive():
					continue
				if other.global_position.distance_to(z.global_position) < 4.5:
					FX.tracer(pos, (other as Zombie).global_position + Vector3.UP * 1.2, Color(0.4, 0.85, 1.0))
					(other as Zombie).take_hit(dmg * 0.6, other.global_position + Vector3.UP, Vector3.ZERO, false, self)
					chained += 1
					if chained >= 2:
						break
		"explosive":
			_explosive_round(pos, dmg)


func _explosive_round(pos: Vector3, dmg: float) -> void:
	FX.shockwave(pos, Color(1.0, 0.5, 0.2), 2.2)
	FX.flash_light(pos, Color(1.0, 0.5, 0.2), 3.0, 5.0, 0.2)
	Audio.play_at("explosion_small", pos, -4.0, 0.1, 40.0, 60)
	for z in get_tree().get_nodes_in_group("zombie"):
		if z is Zombie and z.is_alive() and z.global_position.distance_to(pos) < 2.4:
			(z as Zombie).take_hit(dmg * 0.7, z.global_position + Vector3.UP, Vector3.ZERO, false, self)


# --------------------------------------------------------------------------------
# reload
# --------------------------------------------------------------------------------

func reload() -> void:
	var s := current_slot()
	if s == null or reloading or busy() or _dead:
		return
	if s.mag >= s.max_mag() or s.reserve <= 0:
		return
	reloading = true
	aiming = false if not s.data.reload_per_shell else aiming
	var dur := s.data.reload_time * _player.reload_multiplier()
	_reload_timer = dur
	reload_started.emit(dur if not s.data.reload_per_shell else dur * (s.max_mag() - s.mag))
	Audio.play(s.data.reload_sound, -4.0)


func _update_reload(delta: float, s: WeaponSlot) -> void:
	if not reloading:
		return
	_reload_timer -= delta
	if _reload_timer > 0.0:
		return
	if s.data.reload_per_shell:
		s.mag += 1
		s.reserve -= 1
		ammo_changed.emit(s.mag, s.reserve)
		if s.mag < s.max_mag() and s.reserve > 0:
			_reload_timer = s.data.reload_time * _player.reload_multiplier()
			Audio.play(s.data.reload_sound, -5.0)
			return
		Audio.play("pump", -6.0)
	else:
		var need := s.max_mag() - s.mag
		var take := mini(need, s.reserve)
		s.mag += take
		s.reserve -= take
		ammo_changed.emit(s.mag, s.reserve)
	reloading = false
	reload_finished.emit()
