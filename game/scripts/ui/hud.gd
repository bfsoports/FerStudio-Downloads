class_name HUD
extends CanvasLayer
## In-game HUD. Keeps the screen centre clear (only a light dynamic reticle),
## large readable numbers, military-arcade plates. Layout is anchor-based so it
## adapts to any landscape aspect ratio.

var player: Player
var rounds: RoundManager
var touch: TouchControls

var _root: Control
var _round_label: Label
var _remaining_label: Label
var _health_bar: Control
var _health_value := 1.0
var _health_shown := 1.0
var _perk_row: HBoxContainer
var _points_label: Label
var _points_shown := 0.0
var _popup_anchor: Control
var _weapon_icon: TextureRect
var _weapon_name: Label
var _mag_label: Label
var _reserve_label: Label
var _grenade_label: Label
var _ammo_warn: Label
var _reticle: Control
var _hitmarker: Control
var _hit_t := 0.0
var _hit_head := false
var _hit_kill := false
var _prompt: PanelContainer
var _prompt_icon: TextureRect
var _prompt_title: Label
var _prompt_price: Label
var _prompt_sub: Label
var _prompt_action: Label
var _banner: Label
var _banner_sub: Label
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss: Zombie
var _vignette: ColorRect
var _vignette_a := 0.0
var _dmg_arrows: Control
var _dmg_dirs: Array = []
var _fps_label: Label
var _intermission: Label
var _reload_ring: Control
var _reload_t := 0.0
var _reload_dur := 0.0


func _ready() -> void:
	layer = 4
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)
	_build_damage_layer()
	_build_round_and_health()
	_build_points_and_weapon()
	_build_center()
	_build_prompt()
	_build_banner()
	_build_boss_bar()
	_fps_label = UIStyle.make_label("", 18, UIStyle.TEXT_DIM)
	_fps_label.position = Vector2(12, 4)
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_top = -26
	_root.add_child(_fps_label)


func bind(p: Player, rm: RoundManager, tc: TouchControls) -> void:
	player = p
	rounds = rm
	touch = tc
	p.health_changed.connect(func(c, m): _health_value = c / m)
	p.damaged.connect(_on_damaged)
	p.perks_changed.connect(_on_perks)
	p.interact_target_changed.connect(_on_target)
	p.grenades_changed.connect(func(n): _grenade_label.text = "x%d" % n)
	p.weapons.weapon_changed.connect(_on_weapon)
	p.weapons.ammo_changed.connect(_on_ammo)
	p.weapons.reload_started.connect(func(d): _reload_t = d; _reload_dur = d)
	p.weapons.reload_finished.connect(func(): _reload_t = 0.0)
	FX.hit_marker.connect(_on_hit)
	GameState.points_changed.connect(_on_points)
	rm.round_started.connect(_on_round_started)
	rm.round_ended.connect(_on_round_ended)
	rm.remaining_changed.connect(func(n): _remaining_label.text = "ZOMBIS: %d" % n)
	rm.boss_spawned.connect(_on_boss)
	rm.boss_died.connect(func(): _boss_box.visible = false; show_banner("¡EL CAPATAZ HA CAÍDO!", "+2500 puntos", UIStyle.GOLD))
	_grenade_label.text = "x%d" % p.grenades
	var cs = p.weapons.current_slot()
	if cs:
		_on_weapon(cs)
		_on_ammo(cs.mag, cs.reserve)
	_points_shown = GameState.points
	_points_label.text = str(GameState.points)


# ------------------------------------------------------------------------------
# construction
# ------------------------------------------------------------------------------

func _plate_panel(color: Color = UIStyle.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.plate(color, UIStyle.BORDER, 2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_round_and_health() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(26, 14)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var skull := TextureRect.new()
	skull.texture = UIStyle.icon("skull")
	skull.custom_minimum_size = Vector2(46, 46)
	skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull.modulate = UIStyle.DANGER
	row.add_child(skull)
	_round_label = UIStyle.make_label("1", 64, UIStyle.DANGER, true)
	row.add_child(_round_label)
	_remaining_label = UIStyle.make_label("", 30, UIStyle.TEXT)
	_remaining_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_remaining_label)
	# health bar (slanted)
	_health_bar = Control.new()
	_health_bar.custom_minimum_size = Vector2(300, 30)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.draw.connect(_draw_health)
	box.add_child(_health_bar)
	_perk_row = HBoxContainer.new()
	_perk_row.add_theme_constant_override("separation", 6)
	_perk_row.custom_minimum_size = Vector2(0, 50)
	box.add_child(_perk_row)


func _draw_health() -> void:
	var w := _health_bar.size.x
	var h := _health_bar.size.y
	var sk := 12.0
	var pts := PackedVector2Array([Vector2(sk, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(0, h)])
	_health_bar.draw_colored_polygon(pts, Color(0.05, 0.06, 0.05, 0.75))
	var fw := maxf(0.0, (w - sk) * _health_shown)
	var col := UIStyle.TOXIC.lerp(UIStyle.DANGER, clampf(1.0 - _health_shown * 1.6, 0, 1))
	if fw > 1.0:
		var fp := PackedVector2Array([Vector2(sk + 3, 4), Vector2(sk + fw - 3, 4), Vector2(fw - 3, h - 4), Vector2(3, h - 4)])
		_health_bar.draw_colored_polygon(fp, col)
	_health_bar.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), UIStyle.BORDER, 2.0, true)
	var ic := UIStyle.icon("health")
	if ic:
		_health_bar.draw_texture_rect(ic, Rect2(w + 8, 2, h - 4, h - 4), false, col)


func _build_points_and_weapon() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -470
	col.offset_right = -112
	col.offset_top = 10
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	var pp := _plate_panel()
	pp.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(pp)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	pp.add_child(prow)
	var pic := TextureRect.new()
	pic.texture = UIStyle.icon("points")
	pic.custom_minimum_size = Vector2(36, 36)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.modulate = UIStyle.GOLD
	prow.add_child(pic)
	_points_label = UIStyle.make_label("500", 44, UIStyle.GOLD, true)
	prow.add_child(_points_label)
	_popup_anchor = Control.new()
	_popup_anchor.custom_minimum_size = Vector2(10, 0)
	_popup_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_popup_anchor)
	var wp := _plate_panel(Color(0.08, 0.09, 0.075, 0.82))
	wp.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(wp)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 12)
	wp.add_child(wrow)
	var wcol := VBoxContainer.new()
	wcol.add_theme_constant_override("separation", -4)
	wrow.add_child(wcol)
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(130, 44)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wcol.add_child(_weapon_icon)
	_weapon_name = UIStyle.make_label("", 22, UIStyle.TEXT_DIM)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wcol.add_child(_weapon_name)
	_mag_label = UIStyle.make_label("10", 52, UIStyle.TEXT, true)
	wrow.add_child(_mag_label)
	var rcol := VBoxContainer.new()
	rcol.alignment = BoxContainer.ALIGNMENT_CENTER
	wrow.add_child(rcol)
	_reserve_label = UIStyle.make_label("/ 80", 28, UIStyle.TEXT_DIM)
	rcol.add_child(_reserve_label)
	var grow := HBoxContainer.new()
	rcol.add_child(grow)
	var gic := TextureRect.new()
	gic.texture = UIStyle.icon("grenade")
	gic.custom_minimum_size = Vector2(24, 24)
	gic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grow.add_child(gic)
	_grenade_label = UIStyle.make_label("x2", 22, UIStyle.TEXT)
	grow.add_child(_grenade_label)


func _build_center() -> void:
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	_root.add_child(_reticle)
	_hitmarker = Control.new()
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker.draw.connect(_draw_hitmarker)
	_root.add_child(_hitmarker)
	_reload_ring = Control.new()
	_reload_ring.set_anchors_preset(Control.PRESET_CENTER)
	_reload_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_ring.draw.connect(_draw_reload)
	_root.add_child(_reload_ring)
	_ammo_warn = UIStyle.make_label("", 26, UIStyle.ACCENT, true)
	_ammo_warn.set_anchors_preset(Control.PRESET_CENTER)
	_ammo_warn.offset_top = 46
	_ammo_warn.offset_left = -150
	_ammo_warn.offset_right = 150
	_ammo_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_ammo_warn)
	_intermission = UIStyle.make_label("", 28, UIStyle.TEXT)
	_intermission.anchor_left = 0.5
	_intermission.anchor_right = 0.5
	_intermission.offset_left = -300
	_intermission.offset_right = 300
	_intermission.offset_top = 150
	_intermission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_intermission)


func _draw_reticle() -> void:
	if player == null or player.weapons.current_slot() == null or not player.alive:
		return
	var s := player.weapons.current_spread()
	var aim := player.weapons.aiming
	var sniper := player.weapons.current_slot().data.category == WeaponData.Category.SNIPER
	var gap := 6.0 + s * 7.0
	var col := Color(0.94, 0.92, 0.86, 0.85)
	if aim and sniper:
		_reticle.draw_arc(Vector2.ZERO, 120, 0, TAU, 64, Color(0, 0, 0, 0.6), 4.0, true)
		_reticle.draw_line(Vector2(-120, 0), Vector2(120, 0), Color(0, 0, 0, 0.7), 2.0)
		_reticle.draw_line(Vector2(0, -120), Vector2(0, 120), Color(0, 0, 0, 0.7), 2.0)
		_reticle.draw_circle(Vector2.ZERO, 2.5, UIStyle.DANGER)
		return
	if aim:
		_reticle.draw_circle(Vector2.ZERO, 3.0, col)
		_reticle.draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color(col, 0.5), 1.5, true)
		return
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		_reticle.draw_line(d * gap, d * (gap + 11.0), Color(0, 0, 0, 0.6), 4.0)
		_reticle.draw_line(d * gap, d * (gap + 11.0), col, 2.0)
	_reticle.draw_circle(Vector2.ZERO, 1.8, col)


func _draw_hitmarker() -> void:
	if _hit_t <= 0.0:
		return
	var col := UIStyle.DANGER if _hit_kill else (UIStyle.GOLD if _hit_head else Color(1, 1, 1))
	col.a = clampf(_hit_t / 0.25, 0, 1)
	var r := 14.0 if _hit_kill else 10.0
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hitmarker.draw_line(d * 6.0, d * r, col, 3.0, true)


func _draw_reload() -> void:
	if _reload_t <= 0.0 or _reload_dur <= 0.0:
		return
	var k := 1.0 - _reload_t / _reload_dur
	_reload_ring.draw_arc(Vector2.ZERO, 34, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(UIStyle.ACCENT, 0.9), 4.0, true)


func _build_prompt() -> void:
	_prompt = _plate_panel(Color(0.07, 0.08, 0.065, 0.9))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.62
	_prompt.anchor_bottom = 0.62
	_prompt.offset_left = -290
	_prompt.offset_right = 290
	_prompt.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_prompt.add_child(row)
	_prompt_icon = TextureRect.new()
	_prompt_icon.custom_minimum_size = Vector2(76, 56)
	_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_prompt_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -6)
	row.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	_prompt_title = UIStyle.make_label("", 28, UIStyle.TEXT, true)
	_prompt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_title.clip_text = true
	top.add_child(_prompt_title)
	_prompt_price = UIStyle.make_label("", 30, UIStyle.GOLD, true)
	top.add_child(_prompt_price)
	_prompt_sub = UIStyle.make_label("", 22, UIStyle.TEXT_DIM)
	_prompt_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prompt_sub)
	_prompt_action = UIStyle.make_label("", 20, UIStyle.ACCENT)
	col.add_child(_prompt_action)
	_prompt.visible = false


func _build_banner() -> void:
	_banner = UIStyle.make_label("", 58, UIStyle.TEXT, true)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.2
	_banner.anchor_bottom = 0.2
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_sub = UIStyle.make_label("", 28, UIStyle.TEXT_DIM)
	_banner_sub.anchor_left = 0.0
	_banner_sub.anchor_right = 1.0
	_banner_sub.anchor_top = 0.2
	_banner_sub.anchor_bottom = 0.2
	_banner_sub.offset_top = 70
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate.a = 0.0
	_root.add_child(_banner_sub)


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = 92
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	var l := UIStyle.make_label("EL CAPATAZ", 30, UIStyle.TOXIC, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(l)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(520, 20)
	var bg := UIStyle.plate(Color(0.05, 0.05, 0.05, 0.85), UIStyle.BORDER, 2, 0.15)
	var fill := UIStyle.plate(Color(0.5, 0.95, 0.25), Color(0, 0, 0, 0), 0, 0.15)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _build_damage_layer() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.0;
uniform float low_health = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(uv * vec2(1.25, 1.0)));
	float pulse = 0.75 + 0.25 * sin(TIME * 5.0);
	float a = v * (strength + low_health * pulse * 0.55);
	COLOR = vec4(0.55, 0.02, 0.02, clamp(a, 0.0, 0.85));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vignette.material = m
	_root.add_child(_vignette)
	_dmg_arrows = Control.new()
	_dmg_arrows.set_anchors_preset(Control.PRESET_CENTER)
	_dmg_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dmg_arrows.draw.connect(_draw_dmg_arrows)
	_root.add_child(_dmg_arrows)


func _draw_dmg_arrows() -> void:
	if player == null:
		return
	var fwd := -player.global_basis.z
	var right := player.global_basis.x
	for e in _dmg_dirs:
		var dir: Vector3 = e.dir
		var ang := atan2(dir.dot(right), dir.dot(fwd))
		var a: float = clampf(e.t, 0.0, 1.0)
		var r := 150.0
		_dmg_arrows.draw_arc(Vector2.ZERO, r, ang - PI * 0.5 - 0.35, ang - PI * 0.5 + 0.35, 20, Color(0.9, 0.12, 0.08, a * 0.85), 10.0, true)


# ------------------------------------------------------------------------------
# events
# ------------------------------------------------------------------------------

func _on_damaged(dir: Vector3, amount: float) -> void:
	_vignette_a = minf(0.9, _vignette_a + amount / 60.0)
	_dmg_dirs.append({"dir": dir, "t": 1.4})


func _on_perks(perks: Array) -> void:
	for c in _perk_row.get_children():
		c.queue_free()
	for id in perks:
		var pd: PerkData = load("res://resources/perks/%s.tres" % id)
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(46, 46)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := UIStyle.icon(pd.icon_name)
		badge.draw.connect(func():
			badge.draw_circle(Vector2(23, 23), 22, pd.color.darkened(0.2))
			badge.draw_arc(Vector2(23, 23), 22, 0, TAU, 32, Color(1, 1, 1, 0.7), 2.0, true)
			if tex:
				badge.draw_texture_rect(tex, Rect2(9, 9, 28, 28), false))
		_perk_row.add_child(badge)
		badge.scale = Vector2.ONE * 1.6
		badge.pivot_offset = Vector2(23, 23)
		badge.create_tween().tween_property(badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	if perks.size() > 0:
		var last: PerkData = load("res://resources/perks/%s.tres" % perks.back())
		show_banner(last.display_name, last.description, last.color.lightened(0.25))


func _on_target(t: Interactable) -> void:
	if t == null:
		_prompt.visible = false
		return
	_refresh_prompt(t)
	_prompt.visible = true


func _refresh_prompt(t: Interactable) -> void:
	var d := t.get_prompt(player)
	_prompt_title.text = d.get("title", "")
	var price: int = d.get("price", 0)
	_prompt_price.text = ("%d" % price) if price > 0 else ""
	_prompt_price.add_theme_color_override("font_color", UIStyle.GOLD if d.get("can_afford", true) else UIStyle.DANGER)
	_prompt_sub.text = d.get("subtitle", "")
	var tex := UIStyle.icon(d.get("icon", "interact"))
	_prompt_icon.texture = tex
	var verb: String = d.get("action", "USAR")
	if t.continuous:
		_prompt_action.text = "MANTÉN [MANO] PARA " + verb
	elif price > 0 and Settings.hold_to_buy:
		_prompt_action.text = ("MANTÉN [MANO] PARA " + verb) if d.get("can_afford", true) else "PUNTOS INSUFICIENTES"
	else:
		_prompt_action.text = "PULSA [MANO] PARA " + verb


func _on_weapon(slot) -> void:
	if slot == null:
		return
	_weapon_icon.texture = UIStyle.icon(slot.data.icon_name)
	_weapon_icon.modulate = slot.data.pap_tint.lightened(0.3) if slot.upgraded else Color.WHITE
	_weapon_name.text = slot.display_name()
	_weapon_name.add_theme_color_override("font_color", slot.data.pap_tint if slot.upgraded else UIStyle.TEXT_DIM)


func _on_ammo(mag: int, reserve: int) -> void:
	_mag_label.text = str(mag)
	_reserve_label.text = "/ %d" % reserve
	var s = player.weapons.current_slot()
	var low: bool = s != null and mag <= int(s.max_mag() * 0.25)
	_mag_label.add_theme_color_override("font_color", UIStyle.DANGER if low else UIStyle.TEXT)
	if mag == 0 and reserve == 0:
		_ammo_warn.text = "SIN MUNICIÓN"
	elif low:
		_ammo_warn.text = "RECARGA"
	else:
		_ammo_warn.text = ""


func _on_points(points: int, delta: int) -> void:
	if delta == 0:
		return
	var l := UIStyle.make_label(("+%d" % delta) if delta > 0 else str(delta), 30 if absi(delta) < 100 else 38, UIStyle.GOLD if delta > 0 else UIStyle.DANGER, true)
	l.position = Vector2(_popup_anchor.size.x - 60 + randf_range(-20, 20), -6)
	_popup_anchor.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", 40.0 if delta > 0 else -30.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _on_hit(head: bool, kill: bool) -> void:
	_hit_t = 0.25
	_hit_head = head
	_hit_kill = kill
	if kill:
		Audio.play("hit_kill", -8.0, 0.0, 40)
	else:
		Audio.play("hit_marker", -12.0, 0.05, 40)


func _on_round_started(n: int) -> void:
	_round_label.text = str(n)
	_intermission.text = ""
	var tw := _round_label.create_tween()
	_round_label.pivot_offset = _round_label.size * 0.5
	tw.tween_property(_round_label, "scale", Vector2.ONE * 1.6, 0.2)
	tw.tween_property(_round_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE)
	show_banner("RONDA %d" % n, "Sobrevive." if n == 1 else ("Llega el jefe..." if n % 5 == 0 else ""), UIStyle.DANGER)


func _on_round_ended(n: int) -> void:
	show_banner("RONDA %d SUPERADA" % n, "Prepárate: repara barricadas, compra y mejora.", UIStyle.TOXIC)


func _on_boss(b: Zombie) -> void:
	_boss = b
	_boss_box.visible = true
	show_banner("¡EL CAPATAZ HA LLEGADO!", "Cuidado con su carga y su golpe sísmico.", UIStyle.TOXIC)


func show_banner(title: String, sub: String = "", color: Color = UIStyle.TEXT) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	for l: Label in [_banner, _banner_sub]:
		var tw := l.create_tween()
		l.modulate.a = 0.0
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_interval(2.4)
		tw.tween_property(l, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------------------------
# per frame
# ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_health_shown = lerpf(_health_shown, _health_value, delta * 8.0)
	_health_bar.queue_redraw()
	_points_shown = lerpf(_points_shown, float(GameState.points), minf(1.0, delta * 10.0))
	_points_label.text = str(int(round(_points_shown)))
	_reticle.queue_redraw()
	_hit_t = maxf(0.0, _hit_t - delta)
	_hitmarker.queue_redraw()
	if _reload_t > 0.0:
		_reload_t -= delta
	_reload_ring.queue_redraw()
	_vignette_a = maxf(0.0, _vignette_a - delta * 0.8)
	var low := clampf(1.0 - _health_value / 0.35, 0.0, 1.0) if player.alive else 0.0
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", _vignette_a)
	(_vignette.material as ShaderMaterial).set_shader_parameter("low_health", low)
	for e in _dmg_dirs:
		e.t -= delta
	_dmg_dirs = _dmg_dirs.filter(func(e): return e.t > 0.0)
	_dmg_arrows.queue_redraw()
	if _prompt.visible and player.current_target:
		_refresh_prompt(player.current_target)
	if _boss and is_instance_valid(_boss) and _boss.is_alive():
		_boss_bar.value = _boss.health / _boss.max_health * 100.0
	if rounds and rounds.in_intermission and rounds.round_number > 0:
		_intermission.text = "SIGUIENTE RONDA EN %d" % int(ceil(rounds.intermission_left()))
	elif rounds and rounds.in_intermission:
		_intermission.text = ""
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d FPS · %s" % [Engine.get_frames_per_second(), Settings.quality_name()]
