class_name SettingsPanel
extends VBoxContainer
## Panel de ajustes (menú principal y menú de pausa), agrupado en secciones de ancho fijo. Todos los controles
## modifican SettingsManager, que los guarda y aplica.

const PANEL_W := 740.0   # ancho máximo del panel

var _panel_w := PANEL_W

func _init(width: float = PANEL_W) -> void:
	_panel_w = minf(width, PANEL_W)

func _ready() -> void:
	custom_minimum_size = Vector2(_panel_w, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 12)
	_build()
	Events.language_changed.connect(_on_language_changed)

func _on_language_changed(_lang: String) -> void:
	call_deferred("_build")

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var s := SettingsManager
	var audio := _section(Loc.t("set.group_audio"), "sound_on")
	_volume_row(audio, Loc.t("set.music"), s.music_volume, "music_on", "music_off", func(v: float) -> void: s.music_volume = v)
	_volume_row(audio, Loc.t("set.sfx"), s.sfx_volume, "sound_on", "sound_off", func(v: float) -> void: s.sfx_volume = v)
	var controls := _section(Loc.t("set.group_controls"), "cursor")
	_row(controls, Loc.t("set.sensitivity"), _slider(0.3, 2.5, 0.1, s.sensitivity, func(v: float) -> void: s.sensitivity = v), "target")
	_row(controls, Loc.t("set.invert_y"), _toggle(s.invert_y, func(p: bool) -> void: s.invert_y = p))
	_row(controls, Loc.t("set.control_scale"), _slider(0.7, 1.5, 0.1, s.control_scale, func(v: float) -> void: s.control_scale = v))
	if s.is_touch_device():
		_row(controls, Loc.t("set.vibration"), _toggle(s.vibration, _on_vibration), "lightning")
	if not s.is_touch_device():
		_row(controls, Loc.t("set.touch_ui"), _toggle(s.force_touch_ui, func(p: bool) -> void: s.force_touch_ui = p))
	var graphics := _section(Loc.t("set.group_graphics"), "lightning")
	_row(graphics, Loc.t("set.quality"), _segmented([Loc.t("set.q_low"), Loc.t("set.q_med"), Loc.t("set.q_high")], s.quality, func(i: int) -> void: s.quality = i))
	_row(graphics, Loc.t("set.shadows"), _toggle(s.shadows, func(p: bool) -> void: s.shadows = p))
	_row(graphics, Loc.t("set.show_fps"), _toggle(s.show_fps, func(p: bool) -> void: s.show_fps = p))
	var general := _section(Loc.t("set.group_general"), "chat")
	_row(general, Loc.t("set.ui_size"), _segmented([Loc.t("set.ui_small"), Loc.t("set.ui_normal"), Loc.t("set.ui_large")], s.ui_scale, func(i: int) -> void: s.ui_scale = i), "plus")
	_row(general, Loc.t("set.language"), _segmented(["Español", "English"], 0 if s.language == "es" else 1, func(i: int) -> void: s.language = "es" if i == 0 else "en"))
	var help := _section(Loc.t("set.group_help"), "info")
	var ads_note := UIKit.label(Loc.t("set.ads_note"), "LabelMuted", 17)
	ads_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_child(ads_note)
	help.add_child(StudioLinks.build(_panel_w - 40.0))
	var reset := UIKit.icon_text_button("trash", Loc.t("set.reset"), "ButtonDanger", UIKit.H_BTN, 380, 36)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_on_reset)
	add_child(reset)

## Tarjeta de sección con su título e icono; devuelve la caja donde se añaden las filas.
func _section(title: String, icon_name: String) -> VBoxContainer:
	var card := UIKit.card("PanelFlat")
	var v := UIKit.vbox(8)
	card.add_child(v)
	v.add_child(UIKit.section_title(title, icon_name))
	add_child(card)
	return v

func _row(parent: VBoxContainer, text: String, control: Control, icon_name: String = "") -> void:
	var h := UIKit.hbox(12)
	if icon_name != "":
		var ic := UIKit.icon_rect(icon_name, 36)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := UIKit.label(text, "LabelLight", 21)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(control)
	parent.add_child(h)

## Fila de volumen: el icono pasa a «silenciado» cuando el control está a cero.
func _volume_row(parent: VBoxContainer, text: String, value: float, icon_on: String, icon_off: String, on_change: Callable) -> void:
	var sl := _slider(0.0, 1.0, 0.05, value, on_change)
	_row(parent, text, sl, icon_on if value > 0.0 else icon_off)
	var ic := parent.get_child(parent.get_child_count() - 1).get_child(0) as TextureRect
	sl.value_changed.connect(func(v: float) -> void:
		ic.texture = UIKit.icon(icon_on if v > 0.0 else icon_off, 36.0))

func _slider(min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(290, 48)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		Events.settings_changed.emit())
	sl.drag_ended.connect(func(_changed: bool) -> void:
		SettingsManager.commit()
		AudioManager.play_sfx("click"))
	return sl

func _toggle(value: bool, on_change: Callable) -> Button:
	var b := UIKit.button("", "ButtonToggle", 52, 120)
	b.toggle_mode = true
	b.button_pressed = value
	b.text = Loc.t("ui.on") if value else Loc.t("ui.off")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.toggled.connect(func(p: bool) -> void:
		b.text = Loc.t("ui.on") if p else Loc.t("ui.off")
		on_change.call(p)
		SettingsManager.commit())
	return b

func _segmented(options: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var h := UIKit.hbox(6)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var group := ButtonGroup.new()
	for i in options.size():
		var b := UIKit.button(str(options[i]), "ButtonToggle", 52, 112)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.pressed.connect(func() -> void:
			on_pick.call(i)
			SettingsManager.commit())
		h.add_child(b)
	return h

## Al activar la vibración se da un pulso de prueba.
func _on_vibration(on: bool) -> void:
	SettingsManager.vibration = on
	if on:
		Haptics.pulse("deliver")

func _on_reset() -> void:
	UIKit.confirm(self, Loc.t("set.reset_confirm"), Loc.t("set.reset_yes"), func() -> void:
		SaveManager.reset_save()
		SaveManager.save_now()
		Events.toast.emit(Loc.t("set.reset_done"), "info"))
