class_name SettingsPanel
extends PanelContainer
## Settings UI shared by the main menu and the pause menu.

signal closed


func _ready() -> void:
	theme = UIStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := UIStyle.plate(Color(0.07, 0.08, 0.065, 0.96), UIStyle.BORDER, 2, 0.0)
	sb.set_content_margin_all(26)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var title := UIStyle.make_label("CONFIGURACIÓN", 40, UIStyle.ACCENT, true)
	v.add_child(title)
	v.add_child(UIStyle.hazard_strip(8))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	# graphics
	_row(grid, "Calidad gráfica", _quality_selector())
	_row(grid, "Límite de FPS", _option(["30", "60"], 1 if Settings.fps_limit >= 60 else 0, func(i): Settings.set_and_save("fps_limit", 60 if i == 1 else 30)))
	_row(grid, "Sensibilidad de cámara", _slider(0.3, 2.5, Settings.look_sensitivity, func(v_): Settings.set_and_save("look_sensitivity", v_)))
	_row(grid, "Sensibilidad al apuntar", _slider(0.2, 1.5, Settings.aim_sensitivity, func(v_): Settings.set_and_save("aim_sensitivity", v_)))
	_row(grid, "Invertir eje Y", _check(Settings.invert_y, func(b): Settings.set_and_save("invert_y", b)))
	_row(grid, "Opacidad de controles", _slider(0.15, 1.0, Settings.controls_opacity, func(v_): Settings.set_and_save("controls_opacity", v_)))
	_row(grid, "Tamaño de controles", _slider(0.75, 1.3, Settings.controls_scale, func(v_): Settings.set_and_save("controls_scale", v_)))
	_row(grid, "Mantener para comprar", _check(Settings.hold_to_buy, func(b): Settings.set_and_save("hold_to_buy", b)))
	_row(grid, "Vibración", _check(Settings.vibration, func(b): Settings.set_and_save("vibration", b)))
	_row(grid, "Volumen música", _slider(0.0, 1.0, Settings.music_volume, func(v_): Settings.set_and_save("music_volume", v_)))
	_row(grid, "Volumen efectos", _slider(0.0, 1.0, Settings.sfx_volume, func(v_): Settings.set_and_save("sfx_volume", v_)))
	_row(grid, "Mostrar FPS", _check(Settings.show_fps, func(b): Settings.set_and_save("show_fps", b)))
	var back := UIStyle.make_button("VOLVER", 260, 58)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)


func _row(grid: GridContainer, text: String, ctrl: Control) -> void:
	var l := UIStyle.make_label(text, 28, UIStyle.TEXT)
	l.custom_minimum_size = Vector2(330, 0)
	grid.add_child(l)
	ctrl.custom_minimum_size.x = maxf(ctrl.custom_minimum_size.x, 360)
	grid.add_child(ctrl)


func _quality_selector() -> Control:
	var note := "Reinicia la partida para aplicar sombras y luces."
	var ob := _option(["BAJO", "MEDIO", "ALTO"], Settings.quality, func(i): Settings.set_and_save("quality", i))
	ob.tooltip_text = note
	return ob


func _option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it)
	ob.selected = selected
	ob.custom_minimum_size = Vector2(360, 54)
	ob.item_selected.connect(cb)
	ob.focus_mode = Control.FOCUS_NONE
	return ob


func _slider(mn: float, mx: float, value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(360, 44)
	s.value_changed.connect(cb)
	s.focus_mode = Control.FOCUS_NONE
	return s


func _check(value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = value
	c.text = ""
	c.toggled.connect(cb)
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(80, 44)
	return c
