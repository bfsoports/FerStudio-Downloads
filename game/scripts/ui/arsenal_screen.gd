class_name ArsenalScreen
extends Control
## Arsenal / bestiary viewer: real 3D models rotating in a SubViewport plus
## stats read straight from the balance resources.

signal closed

var _stage: Node3D
var _pivot: Node3D
var _info_title: Label
var _info_desc: Label
var _bars: VBoxContainer
var _list: VBoxContainer
var _tab := "weapons"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.anchor_left = 0.03
	root.anchor_right = 0.97
	root.anchor_top = 0.05
	root.anchor_bottom = 0.95
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(UIStyle.make_label("ARSENAL", 46, UIStyle.ACCENT, true))
	var tabs := HBoxContainer.new()
	left.add_child(tabs)
	var tw := UIStyle.make_button("ARMAS", 160, 50)
	tw.pressed.connect(func(): _fill("weapons"))
	tabs.add_child(tw)
	var tz := UIStyle.make_button("AMENAZAS", 170, 50)
	tz.pressed.connect(func(): _fill("zombies"))
	tabs.add_child(tz)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var back := UIStyle.make_button("VOLVER", 300, 58)
	back.pressed.connect(func(): closed.emit())
	left.add_child(back)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	_stage = Node3D.new()
	sv.add_child(_stage)
	var cam := Camera3D.new()
	cam.fov = 35
	_stage.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.1, 4.4), Vector3(0, 0.9, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 35, 0)
	l.light_color = Color(1, 0.85, 0.7)
	_stage.add_child(l)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.5)
	env.environment = e
	_stage.add_child(env)
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	var info := PanelContainer.new()
	right.add_child(info)
	var iv := VBoxContainer.new()
	info.add_child(iv)
	_info_title = UIStyle.make_label("", 34, UIStyle.TEXT, true)
	iv.add_child(_info_title)
	_info_desc = UIStyle.make_label("", 24, UIStyle.TEXT_DIM)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_info_desc)
	_bars = VBoxContainer.new()
	iv.add_child(_bars)
	_fill("weapons")


func _process(delta: float) -> void:
	if visible:
		_pivot.rotation.y += delta * 0.6


func _fill(tab: String) -> void:
	_tab = tab
	for c in _list.get_children():
		c.queue_free()
	var ids := ["pistol", "shotgun", "smg", "rifle", "sniper", "lmg"] if tab == "weapons" else ["walker", "runner", "armored", "tank", "boss"]
	for id in ids:
		var res: Resource = load("res://resources/%s/%s.tres" % [tab, id])
		var b := UIStyle.make_button(res.display_name, 320, 54)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_select.bind(res))
		_list.add_child(b)
	_select(load("res://resources/%s/%s.tres" % [tab, ids[0]]))


func _select(res: Resource) -> void:
	for c in _pivot.get_children():
		c.queue_free()
	for c in _bars.get_children():
		c.queue_free()
	var m: Node3D = load(res.model_path).instantiate()
	_pivot.add_child(m)
	if res is WeaponData:
		var w := res as WeaponData
		m.scale = Vector3.ONE * (2.2 if w.category != WeaponData.Category.PISTOL else 4.0)
		m.position = Vector3(0, 0.9, 0)
		m.rotation_degrees = Vector3(0, 90, 0)
		_info_title.text = w.display_name
		_info_desc.text = "%s\nMejorada en La Forja: %s" % [w.description, w.upgraded_name]
		_bar("Daño", w.damage * w.pellets / 260.0)
		_bar("Cadencia", w.fire_rate / 900.0)
		_bar("Cargador", w.mag_size / 100.0)
		_bar("Precisión", 1.0 - w.spread_hip / 8.0)
		_bar("Alcance", w.max_range / 150.0)
		_bar("Movilidad", w.move_speed_mult)
	else:
		var z := res as ZombieData
		m.scale = Vector3.ONE * minf(z.scale, 1.3)
		m.rotation.y = 0.0
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation(z.anim_idle):
			ap.get_animation(z.anim_idle).loop_mode = Animation.LOOP_LINEAR
			ap.play(z.anim_idle)
		_info_title.text = z.display_name
		var notes := {"walker": "Lento pero incansable. La base de toda horda.", "runner": "Rápido y agresivo. Aparece desde la ronda 3.",
			"armored": "Antidisturbios blindado: reduce el daño al cuerpo un 45%. Apunta a la cabeza.",
			"tank": "Mole mutada. Golpe sísmico devastador.", "boss": "Jefe cada 5 rondas: carga, onda sísmica y llamada a la horda."}
		_info_desc.text = notes.get(z.id, "")
		_bar("Resistencia", z.base_health / 9000.0 + 0.05)
		_bar("Velocidad", z.walk_speed / 4.0)
		_bar("Daño", z.damage / 60.0)
		_bar("Blindaje", z.armor)


func _bar(label: String, v: float) -> void:
	var row := HBoxContainer.new()
	_bars.add_child(row)
	var l := UIStyle.make_label(label, 22, UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(300, 14)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.max_value = 1.0
	pb.value = clampf(v, 0.04, 1.0)
	var bg := UIStyle.plate(Color(0.12, 0.12, 0.1), Color(0, 0, 0, 0), 0, 0.2)
	var fill := UIStyle.plate(UIStyle.ACCENT, Color(0, 0, 0, 0), 0, 0.2)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	row.add_child(pb)
