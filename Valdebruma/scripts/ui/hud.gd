extends Control
## Hud — interfaz en partida.
##
## Responsabilidad: mostrar el estado que envía el servidor (salud, hambre, sed, energía,
## temperatura, cansancio, estados temporales, peso), brújula con hora/clima/región, objetivo
## de interacción y progreso de acciones, accesos rápidos, avisos de descubrimiento, grupo,
## chat, señales de compañeros, estado de la conexión, controles táctiles y el tutorial.
## Solo lee de Session/Config y del jugador local; las pulsaciones pasan por Controls o Ui.

const TouchControlsScript := preload("res://scripts/ui/touch_controls.gd")
const ChatBoxScript := preload("res://scripts/ui/chat_box.gd")
const TUTORIAL := ["TUT_MOVE", "TUT_LOOK", "TUT_INTERACT", "TUT_INVENTORY", "TUT_EAT", "TUT_CRAFT", "TUT_BUILD", "TUT_MAP"]

var touch: Control = null
var chat: VBoxContainer
var use_touch := false
var _bars: Dictionary = {}          # clave -> ProgressBar
var _bar_icons: Dictionary = {}
var _temp_icon: TextureRect
var _temp_label: Label
var _weight_label: Label
var _effects: HBoxContainer
var _compass: Control
var _clock: Label
var _weather_icon: TextureRect
var _region: Label
var _net_icon: TextureRect
var _net_label: Label
var _prompt_panel: PanelContainer
var _prompt: Label
var _prompt2: Label
var _action_panel: PanelContainer
var _action_bar: ProgressBar
var _action_label: Label
var _quick: Array = []              # [panel, icono, cantidad]
var _banner: Control
var _banner_title: Label
var _banner_text: Label
var _banner_icon: TextureRect
var _group_box: VBoxContainer
var _vignette: TextureRect
var _hints: Label
var _tut_panel: PanelContainer
var _tut_label: Label
var _tut_step := -1
var _tut_start := Vector3.ZERO
var _tut_yaw := 0.0
var _marks: Control
var _build_panel: PanelContainer
var _build_label: Label
var _crosshair: Panel
var _acc := 0.0
var _menu_open := false
var _safe := Rect2()

func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")
	_safe = Ui.safe_margins()
	_build_vignette()
	_marks = Control.new()
	UiKit.full_rect(_marks)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_build_stats()
	_build_top()
	_build_center()
	_build_quick()
	_build_side()
	if use_touch:
		touch = TouchControlsScript.new()
		touch.name = "Touch"
		add_child(touch)
	Session.stats_changed.connect(_refresh_stats)
	Session.inventory_changed.connect(_refresh_quick)
	Session.env_changed.connect(_refresh_env)
	Session.group_changed.connect(_refresh_group)
	Session.action_changed.connect(func(_c: int, _i: int, _s: float) -> void: _refresh_action())
	Session.mark_received.connect(func(_p: int, pname: String, _pos: Vector3) -> void:
		Ui.toast(tr("N_MARK") % pname, "info", "mark")
		AudioDirector.play_ui("ping"))
	Session.emote_received.connect(func(_p: int, _c: int) -> void: pass)
	_refresh_stats()
	_refresh_quick()
	_refresh_env()
	_refresh_group()
	_refresh_action()

func _corner(preset: int, margin_x: float, margin_y: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(preset)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(_safe.position.x + margin_x))
	m.add_theme_constant_override("margin_right", int(_safe.size.x + margin_x))
	m.add_theme_constant_override("margin_top", int(_safe.position.y + margin_y))
	m.add_theme_constant_override("margin_bottom", int(_safe.size.y + margin_y))
	add_child(m)
	return m

# ---- construcción ------------------------------------------------------------------------------------
func _build_vignette() -> void:
	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(0.62, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_vignette.texture = gt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full_rect(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(0, 0, 0, 0)
	add_child(_vignette)

func _build_stats() -> void:
	var m := _corner(Control.PRESET_TOP_LEFT, 16, 12)
	var v := UiKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var p := UiKit.panel("hud", 10.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(p)
	var g := UiKit.vbox(5)
	p.add_child(g)
	for def: Array in [["hp", "health", UiKit.C_BAD], ["food", "food", UiKit.C_FOOD], ["water", "water", UiKit.C_WATER], ["sta", "stamina", UiKit.C_STA]]:
		var h := UiKit.hbox(8)
		var ic := UiKit.icon_rect(String(def[1]), 20, def[2])
		h.add_child(ic)
		var b := UiKit.bar(def[2], 11.0)
		b.custom_minimum_size = Vector2(170, 11)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		g.add_child(h)
		_bars[def[0]] = b
		_bar_icons[def[0]] = ic
	var h2 := UiKit.hbox(8)
	_temp_icon = UiKit.icon_rect("temp", 20, UiKit.C_TEXT)
	h2.add_child(_temp_icon)
	_temp_label = UiKit.label("", 15, UiKit.C_DIM, UiKit.f_medium)
	_temp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(_temp_label)
	h2.add_child(UiKit.icon_rect("weight", 18, UiKit.C_DIM))
	_weight_label = UiKit.label("", 15, UiKit.C_DIM, UiKit.f_medium)
	h2.add_child(_weight_label)
	g.add_child(h2)
	_effects = UiKit.hbox(6)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_effects)
	_group_box = UiKit.vbox(4)
	_group_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_group_box)
	chat = ChatBoxScript.new()
	v.add_child(UiKit.spacer(false, Vector2(0, 8)))
	v.add_child(chat)
	chat.focus_changed.connect(func(active: bool) -> void:
		Controls.blocked = active or _menu_open
		if not use_touch:
			Controls.capture_mouse(not active and not _menu_open))

func _build_top() -> void:
	var m := _corner(Control.PRESET_CENTER_TOP, 0, 10)
	m.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if use_touch:
		# la barra de menús táctil ocupa la derecha: la brújula y la hora se centran en el hueco libre
		m.add_theme_constant_override("margin_right", int(_safe.size.x) + 440)
	var v := UiKit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	m.add_child(v)
	_compass = Control.new()
	_compass.custom_minimum_size = Vector2(360, 34)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	v.add_child(_compass)
	var h := UiKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_icon = UiKit.icon_rect("sun", 18, UiKit.C_ACCENT)
	h.add_child(_weather_icon)
	_clock = UiKit.label("", 16, UiKit.C_TEXT, UiKit.f_semi)
	h.add_child(_clock)
	_region = UiKit.label("", 16, UiKit.C_DIM, UiKit.f_medium)
	h.add_child(_region)
	for l: Label in [_clock, _region]:      # legibles sobre cielo claro o niebla
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	v.add_child(h)
	# estado de la conexión: arriba a la derecha, bajo la barra de menús táctil
	var n := _corner(Control.PRESET_TOP_RIGHT, 16, 76 if use_touch else 12)
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var nh := UiKit.hbox(6)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.alignment = BoxContainer.ALIGNMENT_END
	_net_icon = UiKit.icon_rect("signal", 18, UiKit.C_GOOD)
	nh.add_child(_net_icon)
	_net_label = UiKit.label("", 14, UiKit.C_DIM, UiKit.f_medium)
	nh.add_child(_net_label)
	n.add_child(nh)
	# aviso de descubrimiento
	_banner = CenterContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y = 150
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)
	var bv := UiKit.vbox(2)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(bv)
	var bh := UiKit.hbox(8)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_icon = UiKit.icon_rect("mark", 22, UiKit.C_ACCENT)
	bh.add_child(_banner_icon)
	_banner_title = UiKit.caption("", UiKit.C_ACCENT)
	_banner_title.add_theme_font_size_override("font_size", 17)
	bh.add_child(_banner_title)
	bv.add_child(bh)
	_banner_text = UiKit.title("", 44)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.add_theme_constant_override("outline_size", 8)
	_banner_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	bv.add_child(_banner_text)

func _build_center() -> void:
	_crosshair = Panel.new()
	_crosshair.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.75), 6, Color(0, 0, 0, 0.5), 1))
	_crosshair.custom_minimum_size = Vector2(6, 6)
	_crosshair.size = Vector2(6, 6)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.position.y += 64
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var v := UiKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	_prompt_panel = UiKit.panel("hud", 10.0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := UiKit.vbox(2)
	_prompt = UiKit.label("", 19, UiKit.C_TEXT, UiKit.f_semi)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_prompt)
	_prompt2 = UiKit.label("", 16, UiKit.C_DIM, UiKit.f_medium)
	_prompt2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_prompt2)
	_prompt_panel.add_child(pv)
	_prompt_panel.visible = false
	v.add_child(_prompt_panel)
	_action_panel = UiKit.panel("hud", 10.0)
	_action_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var av := UiKit.vbox(6)
	_action_label = UiKit.label("", 17, UiKit.C_TEXT, UiKit.f_medium)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(_action_label)
	_action_bar = UiKit.bar(UiKit.C_ACCENT, 8.0)
	_action_bar.custom_minimum_size = Vector2(260, 8)
	av.add_child(_action_bar)
	_action_panel.add_child(av)
	_action_panel.visible = false
	_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_action_panel)
	# barra del modo construcción
	_build_panel = UiKit.panel("hud", 10.0)
	_build_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_label = UiKit.label("", 17, UiKit.C_TEXT, UiKit.f_medium)
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_panel.add_child(_build_label)
	_build_panel.visible = false
	v.add_child(_build_panel)

func _build_quick() -> void:
	var m := _corner(Control.PRESET_CENTER_BOTTOM, 0, 12)
	m.grow_horizontal = Control.GROW_DIRECTION_BOTH
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := UiKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	_tut_panel = UiKit.panel("accent", 12.0)
	_tut_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tut_panel.visible = false
	var th := UiKit.hbox(12)
	th.add_child(UiKit.icon_rect("help", 24, UiKit.C_ACCENT))
	_tut_label = UiKit.label("", 18, UiKit.C_TEXT, UiKit.f_medium)
	_tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_label.custom_minimum_size = Vector2(420, 0)
	th.add_child(_tut_label)
	var skip := UiKit.button(tr("TUT_SKIP"), "", func() -> void: _end_tutorial(), "ghost")
	skip.custom_minimum_size = Vector2(0, 44)
	th.add_child(skip)
	_tut_panel.add_child(th)
	v.add_child(_tut_panel)
	var h := UiKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.03, 0.06, 0.05, 0.55), 10, Color(1, 1, 1, 0.16), 1))
		b.add_theme_stylebox_override("hover", UiKit.box(Color(0.1, 0.16, 0.14, 0.7), 10, UiKit.C_ACCENT, 1))
		b.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.C_ACCENT, 0.5), 10, UiKit.C_ACCENT, 1))
		b.pressed.connect(Ui.use_quick.bind(i))
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		b.add_child(ic)
		var n := UiKit.label("", 14, UiKit.C_TEXT, UiKit.f_semi)
		n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		b.add_child(n)
		var k := UiKit.label(str(i + 1), 12, UiKit.C_DIM, UiKit.f_semi)
		k.position = Vector2(6, 3)
		k.visible = not use_touch
		b.add_child(k)
		h.add_child(b)
		_quick.append([b, ic, n])

func _build_side() -> void:
	var m := _corner(Control.PRESET_BOTTOM_RIGHT, 16, 12)
	m.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints = UiKit.label(tr("HUD_KEYS"), 14, Color(UiKit.C_TEXT, 0.6))
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hints.visible = not use_touch and Config.b("game", "hints")
	m.add_child(_hints)

# ---- refresco por señales --------------------------------------------------------------------------------
func _refresh_stats() -> void:
	var s: Dictionary = Session.stats
	for key: String in _bars.keys():
		var v := float(s.get(key, 0.0))
		(_bars[key] as ProgressBar).value = v
	var temp := float(s.get("temp", 0.0))
	var col := UiKit.C_TEXT
	var text := tr("TEMP_OK")
	if temp < -80.0:
		col = Color(0.45, 0.7, 1.0); text = tr("TEMP_FREEZING")
	elif temp < -45.0:
		col = Color(0.6, 0.82, 1.0); text = tr("TEMP_COLD")
	elif temp < -20.0:
		col = Color(0.78, 0.9, 1.0); text = tr("TEMP_COOL")
	elif temp > 70.0:
		col = UiKit.C_BAD; text = tr("TEMP_HOT")
	elif temp > 40.0:
		col = UiKit.C_FOOD; text = tr("TEMP_WARM")
	_temp_icon.modulate = col
	_temp_label.text = text
	_temp_label.add_theme_color_override("font_color", col if col != UiKit.C_TEXT else UiKit.C_DIM)
	var w := float(s.get("w", 0.0))
	var wmax := float(s.get("wmax", 22.0))
	_weight_label.text = "%.1f / %d kg" % [w, int(wmax)]
	_weight_label.add_theme_color_override("font_color", UiKit.C_BAD if w > wmax else UiKit.C_DIM)
	UiKit.clear(_effects)
	for e: Array in s.get("eff", []):
		var def: Dictionary = GameData.effects.get(String(e[0]), {})
		if def.is_empty():
			continue
		var bad := bool(def.get("bad", false))
		var p := UiKit.panel("hud", 6.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := UiKit.hbox(4)
		h.add_child(UiKit.icon_rect(String(def.get("icon", "info")), 20, UiKit.C_BAD if bad else UiKit.C_GOOD))
		var secs := float(e[1]) if e.size() > 1 else 0.0
		if secs > 0.0 and secs < 3600.0:
			h.add_child(UiKit.label("%d:%02d" % [int(secs) / 60, int(secs) % 60], 13, UiKit.C_DIM, UiKit.f_medium))
		p.add_child(h)
		p.tooltip_text = GameData.text(def.get("name", ""))
		_effects.add_child(p)

func _refresh_quick() -> void:
	for i in _quick.size():
		var id := String(Session.quick[i]) if i < Session.quick.size() else ""
		var q: Array = _quick[i]
		(q[1] as TextureRect).texture = UiKit.item_icon(id) if id != "" else null
		var n := Session.inv.count(id) if id != "" else 0
		var equipped := id != "" and Session.equipped("mano") == id
		(q[2] as Label).text = str(n) if n > 1 else ("E" if equipped else "")
		(q[1] as TextureRect).modulate = Color(1, 1, 1, 1.0 if (n > 0 or equipped) else 0.35)
	if touch != null:
		touch.call("set_mode", Ui.build_mode != null and bool(Ui.build_mode.get("active")), Session.equipped("mano") == "linterna")
	_compass.visible = Session.has_item("brujula")      # el rumbo solo se ve si llevas la brújula

func _refresh_env() -> void:
	var w := String(Session.env.get("w", "despejado"))
	var icon := {"despejado": "sun", "nublado": "cloud", "niebla": "fog", "lluvia": "rain", "tormenta": "storm"}
	var name_ := String(icon.get(w, "sun"))
	if name_ == "sun" and Session.is_night():
		name_ = "moon"
	_weather_icon.texture = UiKit.icon(name_)

func _refresh_group() -> void:
	UiKit.clear(_group_box)
	if int(Session.group.get("id", 0)) == 0 or not Config.b("game", "show_team"):
		return
	for mem: Dictionary in Session.group.get("members", []):
		if int(mem.get("id", 0)) == Session.my_id:
			continue
		var p := UiKit.panel("hud", 6.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := UiKit.hbox(6)
		h.add_child(UiKit.icon_rect("star" if bool(mem.get("leader", false)) else "profile", 16, UiKit.C_GOOD if int(mem.get("id", 0)) != 0 else UiKit.C_DIM))
		var l := UiKit.label(String(mem.get("name", "")), 15, UiKit.C_TEXT if int(mem.get("id", 0)) != 0 else UiKit.C_DIM, UiKit.f_medium)
		l.name = "name_%d" % int(mem.get("id", 0))
		h.add_child(l)
		var d := UiKit.label("", 14, UiKit.C_DIM)
		d.name = "dist"
		d.set_meta("peer", int(mem.get("id", 0)))
		h.add_child(d)
		p.add_child(h)
		_group_box.add_child(p)

func _refresh_action() -> void:
	var a: Dictionary = Session.action
	var active := int(a.get("code", 0)) != Protocol.T.NONE and Time.get_ticks_msec() < int(a.get("end_ms", 0))
	_action_panel.visible = active
	if active:
		_action_label.text = tr("ACTION_%d" % int(a.code)) + ("   " + tr("ACTION_CANCEL_KEY") if not use_touch else "")

# ---- API que usa Ui -------------------------------------------------------------------------------------
func set_menu_open(open: bool) -> void:
	_menu_open = open
	for c: Control in [_crosshair, _prompt_panel, _hints]:
		if c != null:
			c.modulate.a = 0.0 if open else 1.0
	if touch != null:
		touch.visible = not open
	if open and chat.call("is_active"):
		chat.call("unfocus")

func focus_chat() -> void:
	chat.call("focus")

func banner(title_text: String, text: String, icon_name := "mark") -> void:
	_banner_title.text = title_text.to_upper()
	_banner_text.text = text.to_upper()
	_banner_icon.texture = UiKit.icon(icon_name)
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.2)

func set_build_text(text: String, ok: bool) -> void:
	_build_panel.visible = text != ""
	_build_label.text = text
	_build_label.add_theme_color_override("font_color", UiKit.C_TEXT if ok else UiKit.C_BAD)
	if touch != null:
		touch.call("set_mode", text != "", Session.equipped("mano") == "linterna")

# ---- tutorial ----------------------------------------------------------------------------------------------
func start_tutorial() -> void:
	_tut_step = 0
	_show_tut()

func _show_tut() -> void:
	if _tut_step < 0 or _tut_step >= TUTORIAL.size():
		_end_tutorial()
		return
	var key: String = TUTORIAL[_tut_step]
	_tut_label.text = tr(key + ("_TOUCH" if use_touch else "_KEYS"))
	_tut_panel.visible = true
	var pl := _player()
	if pl != null:
		_tut_start = pl.global_position
		_tut_yaw = pl.yaw

func _end_tutorial() -> void:
	_tut_step = -1
	_tut_panel.visible = false
	Profile.tutorial_done = true
	Profile.save()

func _tut_done() -> bool:
	var pl := _player()
	if pl == null:
		return false
	match _tut_step:
		0: return pl.global_position.distance_to(_tut_start) > 4.0
		1: return absf(angle_difference(pl.yaw, _tut_yaw)) > 0.8
		2: return Session.inv.used() > 0 or not Session.open_doors.is_empty() or Session.container_key >= 0
		3: return Ui.is_open("inventory")
		4: return float(Session.stats.get("food", 0.0)) > 82.0 or float(Session.stats.get("water", 0.0)) > 82.0 or Session.has_effect("bien_alimentado")
		5: return Ui.is_open("craft")
		6: return Ui.is_open("build") or not Session.structs.is_empty()
		7: return Ui.is_open("map")
	return false

func _player() -> PlayerController:
	return WorldRoot.current.player if WorldRoot.current != null else null

# ---- actualización continua --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var pl := _player()
	if pl == null:
		return
	_compass.queue_redraw()
	_marks.queue_redraw()
	if _action_panel.visible:
		var a: Dictionary = Session.action
		var left := float(int(a.end_ms) - Time.get_ticks_msec()) / 1000.0
		if left <= 0.0:
			_action_panel.visible = false
		else:
			_action_bar.value = (1.0 - left / maxf(0.1, float(a.seconds))) * 100.0
	_acc += delta
	if _acc < 0.2:
		return
	_acc = 0.0
	# objetivo de interacción
	var text := ""
	var text2 := ""
	if pl.target != null and is_instance_valid(pl.target):
		text = pl.target.prompt()
		text2 = pl.target.prompt2()
	elif pl.water_target:
		text = tr("ACT_DRINK")
		text2 = tr("ACT_FILL") if Session.inv.count("botella_vacia") > 0 else ""
	var building := Ui.build_mode != null and bool(Ui.build_mode.get("active"))
	_prompt_panel.visible = text != "" and not building and not _action_panel.visible
	if text != "":
		_prompt.text = text if use_touch else "[E]  " + text
		_prompt2.text = "" if text2 == "" else (text2 if use_touch else "[F]  " + text2)
		_prompt2.visible = text2 != ""
	if touch != null:
		touch.call("set_target", text != "", text2 != "")
	# reloj, región y red
	_clock.text = tr("HUD_DAY") % [int(Session.env.get("day", 1)), UiKit.clock(Session.hour_now())]
	var place := GameData.world.place_at(pl.global_position.x, pl.global_position.z)
	_region.text = "·  " + (String(place.name) if not place.is_empty() and (Session.progress.get("places", []) as Array).has(String(place.id))
		else tr("REGION_" + GameData.world.region_name(pl.global_position.x, pl.global_position.z).to_upper()))
	_refresh_env()
	if Net.is_server:
		_net_icon.modulate = UiKit.C_GOOD
		_net_label.text = tr("NET_HOST") % maxi(0, Session.roster.size())
	else:
		var ms := int(Net.latency_ms)
		_net_icon.modulate = UiKit.C_GOOD if ms < 120 else (UiKit.C_ACCENT if ms < 260 else UiKit.C_BAD)
		_net_label.text = "%d ms" % ms
	# avisos de estado bajo: parpadeo del icono
	var blink := 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) * 0.006))
	for key: String in _bars.keys():
		var low := float(Session.stats.get(key, 100.0)) < 20.0
		(_bar_icons[key] as TextureRect).modulate.a = blink if low else 1.0
	# viñeta: salud baja, frío o bruma
	var hp := float(Session.stats.get("hp", 100.0))
	var target := Color(0, 0, 0, 0)
	if hp < 35.0:
		target = Color(0.55, 0.05, 0.03, clampf((35.0 - hp) / 35.0, 0.0, 1.0) * 0.6)
	elif Session.has_effect("hipotermia") or Session.has_effect("frio"):
		target = Color(0.35, 0.6, 0.9, 0.3)
	elif Session.has_effect("esporas"):
		target = Color(0.2, 0.6, 0.45, 0.35)
	_vignette.modulate = _vignette.modulate.lerp(target, 0.25)
	# distancia a compañeros
	for p: Node in _group_box.get_children():
		var d: Label = p.find_child("dist", true, false)
		if d == null:
			continue
		d.text = ""
		for gp: Array in Session.group_pos:
			if int(gp[0]) == int(d.get_meta("peer", 0)):
				d.text = "%d m" % int(pl.global_position.distance_to(Vector3(gp[1], gp[2], gp[3])))
	if _tut_step >= 0 and _tut_done():
		_tut_step += 1
		AudioDirector.play_ui("discover", -8.0)
		_show_tut()

# ---- dibujo: brújula y señales -----------------------------------------------------------------------
func _heading() -> float:
	var pl := _player()
	# 0 = norte (−Z), crece hacia el este
	return fposmod(-rad_to_deg(pl.yaw), 360.0) if pl != null else 0.0

func _draw_compass() -> void:
	var w := _compass.size.x
	var h := _compass.size.y
	var head := _heading()
	_compass.draw_style_box(UiKit.box(Color(0.03, 0.06, 0.05, 0.5), 8, Color(1, 1, 1, 0.08), 1), Rect2(Vector2.ZERO, _compass.size))
	var span := 150.0        # grados visibles
	var font := UiKit.f_semi
	for deg in range(0, 360, 15):
		var d := angle_difference(deg_to_rad(head), deg_to_rad(float(deg)))
		var off := rad_to_deg(d)
		if absf(off) > span * 0.5:
			continue
		var x := w * 0.5 + off / span * w
		var fade := 1.0 - absf(off) / (span * 0.5)
		if deg % 90 == 0:
			var t := tr(["COMPASS_N", "COMPASS_E", "COMPASS_S", "COMPASS_W"][deg / 90])
			var col := UiKit.C_ACCENT if deg == 0 else UiKit.C_TEXT
			_compass.draw_string(font, Vector2(x - 6, h * 0.5 + 7), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(col, fade))
		else:
			var tall := 10.0 if deg % 45 == 0 else 6.0
			_compass.draw_line(Vector2(x, h * 0.5 - tall * 0.5), Vector2(x, h * 0.5 + tall * 0.5), Color(1, 1, 1, 0.5 * fade), 1.5)
	_compass.draw_line(Vector2(w * 0.5, h - 6), Vector2(w * 0.5, h - 1), UiKit.C_ACCENT, 2.0)
	# señales de compañeros en la brújula
	var pl := _player()
	if pl == null:
		return
	for m: Dictionary in Session.marks:
		if Time.get_ticks_msec() - int(m.ms) > 90000:
			continue
		var to: Vector3 = (m.pos as Vector3) - pl.global_position
		var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
		var off := rad_to_deg(angle_difference(deg_to_rad(head), deg_to_rad(bearing)))
		if absf(off) < span * 0.5:
			var x := w * 0.5 + off / span * w
			_compass.draw_circle(Vector2(x, 6), 4.0, UiKit.C_GOOD)

func _draw_marks() -> void:
	var pl := _player()
	if pl == null or _menu_open:
		return
	var cam := pl.cam
	var icon := UiKit.icon("mark")
	for m: Dictionary in Session.marks:
		if Time.get_ticks_msec() - int(m.ms) > 90000:
			continue
		var pos: Vector3 = (m.pos as Vector3) + Vector3(0, 1.2, 0)
		if cam.is_position_behind(pos):
			continue
		var sp := cam.unproject_position(pos)
		var dist := pl.global_position.distance_to(m.pos)
		_marks.draw_texture_rect(icon, Rect2(sp - Vector2(14, 28), Vector2(28, 28)), false, UiKit.C_GOOD)
		_marks.draw_string(UiKit.f_semi, sp + Vector2(-40, 16), "%s · %d m" % [String(m.name), int(dist)], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, UiKit.C_TEXT)
