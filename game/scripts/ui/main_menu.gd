extends Control
## Main menu: Canva key art + logo, JUGAR / ARSENAL / CONFIGURACIÓN / CRÉDITOS / SALIR.

var _menu: VBoxContainer
var _settings: SettingsPanel
var _credits: PanelContainer
var _arsenal: ArsenalScreen
var _logo: TextureRect


func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/backgrounds/menu_keyart.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment(){ float a = smoothstep(0.35, 1.0, UV.x) * 0.82; COLOR = vec4(0.03,0.035,0.03, a); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	shade.material = m
	add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/ui/logo/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.anchor_left = 0.56
	_logo.anchor_right = 0.97
	_logo.anchor_top = 0.04
	_logo.anchor_bottom = 0.34
	add_child(_logo)
	_menu = VBoxContainer.new()
	_menu.anchor_left = 0.62
	_menu.anchor_right = 0.93
	_menu.anchor_top = 0.37
	_menu.anchor_bottom = 0.95
	_menu.add_theme_constant_override("separation", 12)
	add_child(_menu)
	var items := [["JUGAR", "play", _play], ["ARSENAL", "target", _open_arsenal], ["CONFIGURACIÓN", "settings", _open_settings], ["CRÉDITOS", "credits", _open_credits]]
	if OS.get_name() != "Web":
		items.append(["SALIR", "exit", _quit])
	for it in items:
		var b := UIStyle.make_button("   " + it[0], 380, 68)
		b.icon = UIStyle.icon(it[1])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[2])
		if it[0] == "JUGAR":
			b.add_theme_font_size_override("font_size", 34)
			b.custom_minimum_size.y = 84
			b.add_theme_stylebox_override("normal", UIStyle.plate(Color(0.42, 0.2, 0.04, 0.95), UIStyle.ACCENT, 3))
		_menu.add_child(b)
	var rec := UIStyle.make_label("RÉCORD: RONDA %d  ·  %d BAJAS  ·  %d PUNTOS" % [GameState.best_round, GameState.best_kills, GameState.best_score], 24, UIStyle.GOLD)
	rec.anchor_left = 0.03
	rec.anchor_top = 1.0
	rec.anchor_bottom = 1.0
	rec.offset_top = -46
	add_child(rec)
	var ver := UIStyle.make_label("v%s · Calidad %s" % [ProjectSettings.get_setting("application/config/version"), Settings.quality_name()], 20, UIStyle.TEXT_DIM)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -300
	ver.offset_top = -34
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.visible = false
	_settings.closed.connect(_back)
	add_child(_settings)
	_credits = _build_credits()
	add_child(_credits)
	_arsenal = ArsenalScreen.new()
	_arsenal.visible = false
	_arsenal.closed.connect(_back)
	add_child(_arsenal)
	Audio.play_music("menu", 1.5, -6.0)
	Audio.stop_ambience()
	# intro animation
	_logo.modulate.a = 0.0
	_menu.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_logo, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_menu, "modulate:a", 1.0, 0.8).set_delay(0.3)


func _play() -> void:
	Audio.play("ui_confirm", -2.0)
	SceneLoader.change_scene("res://scenes/gameplay/game.tscn")


func _hide_all() -> void:
	_menu.visible = false
	_logo.visible = false


func _back() -> void:
	_settings.visible = false
	_credits.visible = false
	_arsenal.visible = false
	_menu.visible = true
	_logo.visible = true


func _open_settings() -> void:
	_hide_all()
	_settings.visible = true
	_settings.position = (get_viewport_rect().size - _settings.size) * 0.5


func _open_arsenal() -> void:
	_hide_all()
	_arsenal.visible = true


func _open_credits() -> void:
	_hide_all()
	_credits.visible = true


func _quit() -> void:
	get_tree().quit()


func _build_credits() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.12
	p.anchor_right = 0.88
	p.anchor_top = 0.08
	p.anchor_bottom = 0.92
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIStyle.make_label("CRÉDITOS", 44, UIStyle.ACCENT, true))
	v.add_child(UIStyle.hazard_strip(8))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_override("normal_font", UIStyle.body_font())
	t.add_theme_font_size_override("normal_font_size", 26)
	t.add_theme_font_override("bold_font", UIStyle.title_font())
	t.add_theme_font_size_override("bold_font_size", 24)
	t.text = """[b]SECTOR ABANDONADO[/b] — FerStudio
Diseño, programación (Godot 4.7.2 / GDScript), sistemas, VFX y audio procedural: desarrollo del proyecto.

[b]PERSONAJES 3D[/b]
Superviviente, Errante, Corredor, Blindado y Tanque generados con Hyper3D Rodin (Gen-2.5).
Rig humanoide: auto-rig de three.ws (y auto-rig propio para el Tanque).
Animaciones: clips CC0 de la biblioteca three.ws, retargeteados con herramienta propia.

[b]ARMAS[/b]
Ultimate Gun Pack de Quaternius — CC0 1.0 (quaternius.com).

[b]CAJA MISTERIOSA[/b]
Modelo generado con three.ws 3D Studio.

[b]ARTE 2D[/b]
Logotipo e ilustración del menú creados con Canva (IA generativa de Canva).
Iconografía HUD: set SVG propio del proyecto.

[b]TIPOGRAFÍAS[/b]
Russo One y Teko — SIL Open Font License 1.1.

[b]AUDIO[/b]
Efectos y música sintetizados proceduralmente para este proyecto (originales).

Inspirado en el género de supervivencia por rondas. Todos los personajes, mapas y nombres son originales."""
	scroll.add_child(t)
	var back := UIStyle.make_button("VOLVER", 260, 58)
	back.pressed.connect(_back)
	v.add_child(back)
	return p
