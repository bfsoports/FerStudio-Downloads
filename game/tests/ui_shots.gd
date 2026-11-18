extends Node
## Captures menu screens at several aspect ratios for UI review.

var dir := "user://ui"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]
	var tag := a[1] if a.size() > 1 else "16x9"
	DirAccess.make_dir_recursive_absolute(dir)
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	layer.add_child(menu)
	await get_tree().create_timer(1.5).timeout
	await _shot("menu_" + tag)
	menu._open_settings()
	await get_tree().create_timer(0.5).timeout
	await _shot("settings_" + tag)
	menu._back()
	menu._open_arsenal()
	await get_tree().create_timer(0.8).timeout
	await _shot("arsenal_" + tag)
	menu._arsenal._fill("zombies")
	await get_tree().create_timer(0.8).timeout
	await _shot("bestiary_" + tag)
	menu.queue_free()
	var game = load("res://scenes/gameplay/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(4.0).timeout
	await _shot("hud_" + tag)
	game.toggle_pause()
	await get_tree().create_timer(0.4).timeout
	await _shot("pause_" + tag)
	get_tree().quit()


func _shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
