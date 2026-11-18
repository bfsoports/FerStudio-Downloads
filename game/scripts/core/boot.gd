extends Node
## Boot: forces landscape + immersive fullscreen, then shows the main menu.

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	Settings.apply_all()
	await get_tree().process_frame
	SceneLoader.change_scene("res://scenes/main_menu/main_menu.tscn", false)
