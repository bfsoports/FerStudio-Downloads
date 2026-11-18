class_name GameOverScreen
extends CanvasLayer
## Defeat + match results with local records and the survivor's last stand.

var _root: Control
var _list: VBoxContainer
var _title: Label
var _viewport_tex: TextureRect


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)
	_root.visible = false


func show_stats(stats: Dictionary) -> void:
	_root.visible = true
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/backgrounds/screen_bg.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.75, 0.45, 0.42)
	_root.add_child(bg)
	# survivor model (Hyper3D) playing its death animation in a small viewport
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.anchor_left = 0.58
	svc.anchor_right = 0.98
	svc.anchor_top = 0.08
	svc.anchor_bottom = 0.95
	_root.add_child(svc)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	svc.add_child(sv)
	var stage := Node3D.new()
	sv.add_child(stage)
	if ResourceLoader.exists("res://assets/characters/survivor.glb"):
		var surv: Node3D = load("res://assets/characters/survivor.glb").instantiate()
		surv.rotation.y = deg_to_rad(-25)
		stage.add_child(surv)
		var ap: AnimationPlayer = surv.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("death"):
			ap.get_animation("death").loop_mode = Animation.LOOP_NONE
			ap.play("death", 0.0, 0.8)
	var cam := Camera3D.new()
	cam.fov = 50
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(1.6, 1.4, 3.6), Vector3(0.2, 0.6, -0.6))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_color = Color(1.0, 0.7, 0.5)
	stage.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.45, 0.45)
	env.environment = e
	stage.add_child(env)
	# results panel
	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.55
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	_root.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	panel.add_child(_list)
	_title = UIStyle.make_label("HAS CAÍDO", 76, UIStyle.DANGER, true)
	_list.add_child(_title)
	_list.add_child(UIStyle.hazard_strip(8))
	_stat("skull", "RONDA ALCANZADA", str(stats.round), stats.new_round_record)
	_stat("target", "ZOMBIS ELIMINADOS", "%d  (%d a la cabeza)" % [stats.kills, stats.headshots], stats.new_kill_record)
	_stat("points", "PUNTUACIÓN", str(stats.score), stats.new_score_record)
	_stat("clock", "TIEMPO SOBREVIVIDO", GameState.format_time(stats.time), false)
	var rec := UIStyle.make_label("RÉCORDS — Ronda %d · Bajas %d · Puntos %d" % [GameState.best_round, GameState.best_kills, GameState.best_score], 24, UIStyle.TEXT_DIM)
	_list.add_child(rec)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_list.add_child(row)
	var again := UIStyle.make_button("NUEVA PARTIDA", 300, 66)
	again.pressed.connect(func(): SceneLoader.change_scene("res://scenes/gameplay/game.tscn"))
	row.add_child(again)
	var menu := UIStyle.make_button("MENÚ", 200, 66)
	menu.pressed.connect(func(): SceneLoader.change_scene("res://scenes/main_menu/main_menu.tscn", false))
	row.add_child(menu)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.8)
	Audio.play("game_over", 0.0, 0.0)


func _stat(icon: String, label: String, value: String, record: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_list.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UIStyle.icon(icon)
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.modulate = UIStyle.ACCENT
	row.add_child(ic)
	var l := UIStyle.make_label(label, 28, UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(270, 0)
	row.add_child(l)
	var v := UIStyle.make_label(value, 36, UIStyle.TEXT, true)
	row.add_child(v)
	if record:
		var r := UIStyle.make_label("¡NUEVO RÉCORD!", 24, UIStyle.GOLD, true)
		row.add_child(r)
