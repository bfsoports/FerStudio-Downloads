class_name PauseMenu
extends CanvasLayer
## Pause screen: resume, settings, restart, back to menu + live stats.

var _root: Control
var _main: VBoxContainer
var _settings: SettingsPanel
var _stats: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 14)
	center.add_child(_main)
	var t := UIStyle.make_label("PAUSA", 72, UIStyle.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(t)
	_main.add_child(UIStyle.hazard_strip(8))
	_stats = UIStyle.make_label("", 26, UIStyle.TEXT_DIM)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(_stats)
	for entry in [["REANUDAR", _resume], ["CONFIGURACIÓN", _open_settings], ["REINICIAR PARTIDA", _restart], ["MENÚ PRINCIPAL", _to_menu]]:
		var b := UIStyle.make_button(entry[0], 420, 66)
		b.pressed.connect(entry[1])
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_main.add_child(b)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func(): _settings.visible = false; _main.visible = true)
	center.add_child(_settings)
	_root.visible = false


func open() -> void:
	_root.visible = true
	_main.visible = true
	_settings.visible = false
	_stats.text = "Ronda %d  ·  %d bajas  ·  %s  ·  Récord: ronda %d" % [GameState.current_round, GameState.kills, GameState.format_time(GameState.match_time), GameState.best_round]
	Audio.play("ui_open", -6.0)


func close() -> void:
	_root.visible = false


func _resume() -> void:
	var g := get_parent() as Game
	if g:
		g.toggle_pause()


func _open_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _restart() -> void:
	get_tree().paused = false
	GameState.match_running = false
	SceneLoader.change_scene("res://scenes/gameplay/game.tscn")


func _to_menu() -> void:
	get_tree().paused = false
	GameState.match_running = false
	SceneLoader.change_scene("res://scenes/main_menu/main_menu.tscn", false)
