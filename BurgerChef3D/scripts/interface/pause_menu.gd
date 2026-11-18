class_name PauseMenu
extends Control
## Menú de pausa: continuar, reiniciar, ajustes y salir (o terminar la sesión en el modo libre).
## Se muestra con el árbol de escenas pausado, así que todo el juego queda detenido mientras está abierto.

signal resume_requested
signal restart_requested
signal exit_requested
signal finish_requested

const BUTTON_W := 380.0

var free_mode: bool = false
var tutorial_mode: bool = false
var _content: CenterContainer
var _in_settings := false

func _init(is_free: bool = false, is_tutorial: bool = false) -> void:
	free_mode = is_free
	tutorial_mode = is_tutorial
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := UIKit.frame(1500.0)
	add_child(frame)
	var margin := UIKit.margin_container(self, 12)
	frame.add_child(margin)
	_content = CenterContainer.new()
	margin.add_child(_content)
	Events.ui_scale_changed.connect(_on_resized)
	_show_main()

func _on_resized() -> void:
	call_deferred("_redraw")

func _redraw() -> void:
	if _in_settings:
		_show_settings()
	else:
		_show_main()

func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

func _show_main() -> void:
	_in_settings = false
	_clear()
	var panel := UIKit.card()
	_content.add_child(panel)
	var v := UIKit.column(minf(BUTTON_W, UIKit.canvas_size(self).x - 80.0), 12)
	panel.add_child(v)
	var head := UIKit.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIKit.icon_rect("settings", 56))
	var title := UIKit.label(Loc.t("pause.title"), "LabelHeader", 42)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	v.add_child(head)
	v.add_child(UIKit.divider())
	var b_resume := UIKit.icon_text_button("skip", Loc.t("pause.resume"), "ButtonSuccess", UIKit.H_BTN, 0, 40)
	b_resume.pressed.connect(func() -> void: resume_requested.emit())
	v.add_child(b_resume)
	var b_restart := UIKit.icon_text_button("rebirth", Loc.t("pause.restart"), "ButtonPrimary", UIKit.H_BTN, 0, 40)
	b_restart.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(b_restart)
	var b_settings := UIKit.icon_text_button("settings", Loc.t("pause.settings"), "ButtonSecondary", UIKit.H_BTN, 0, 40)
	b_settings.pressed.connect(_show_settings)
	v.add_child(b_settings)
	if tutorial_mode:
		# saltar el tutorial (cuenta como visto, sin recompensa) o salir sin terminarlo
		var b_skip := UIKit.icon_text_button("skip", Loc.t("tut.skip"), "ButtonSecondary", UIKit.H_BTN, 0, 40)
		b_skip.pressed.connect(_confirm_skip)
		v.add_child(b_skip)
	if free_mode:
		var b_finish := UIKit.icon_text_button("trophy", Loc.t("pause.finish"), "ButtonDanger", UIKit.H_BTN, 0, 40)
		b_finish.pressed.connect(func() -> void: finish_requested.emit())
		v.add_child(b_finish)
	else:
		var b_exit := UIKit.icon_text_button("home", Loc.t("pause.exit"), "ButtonDanger", UIKit.H_BTN, 0, 40)
		b_exit.pressed.connect(_confirm_exit)
		v.add_child(b_exit)

func _confirm_skip() -> void:
	UIKit.confirm(self, Loc.t("tut.skip_confirm"), Loc.t("tut.skip"), func() -> void: finish_requested.emit())

func _confirm_exit() -> void:
	UIKit.confirm(self, Loc.t("pause.confirm_exit"), Loc.t("pause.exit"), func() -> void: exit_requested.emit())

func _show_settings() -> void:
	_in_settings = true
	_clear()
	var avail := UIKit.canvas_size(self)
	var win_w := minf(900.0, avail.x - 28.0)
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(win_w, minf(610.0, avail.y - 28.0))
	_content.add_child(panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect("settings", 52))
	var title := UIKit.label(Loc.t("pause.settings"), "LabelHeader", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var close := UIKit.icon_button("close", "ButtonIcon", 62)
	close.pressed.connect(_show_main)
	head.add_child(close)
	v.add_child(head)
	v.add_child(UIKit.divider())
	v.add_child(UIKit.scroll(UIKit.centered(SettingsPanel.new(win_w - 42.0))))

## Atrás (tecla Esc o botón Atrás de Android): vuelve al menú de pausa o reanuda la partida.
func go_back() -> void:
	if _in_settings:
		_show_main()
	else:
		resume_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()
