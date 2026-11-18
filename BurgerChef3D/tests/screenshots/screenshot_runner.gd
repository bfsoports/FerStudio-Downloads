extends Node
## Captura de pantallas para revisar la interfaz en distintos tamaños (lo usa GitHub Actions y tools/screenshots.sh).
## Uso: godot --path . --resolution 2400x1080 res://tests/screenshots/screenshot_runner.tscn -- --out=menu.png [--scene=menu|game] [--screen=upgrades]
## Necesita un renderizador real (no --headless): en Linux se ejecuta con xvfb-run.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out := str(args.get("out", "user://shot.png"))
	SaveManager.set_process(false)
	# partida de ejemplo con progreso para que se vean CONTINUAR, monedas y avisos
	GameState.coins = 970
	GameState.highest_unlocked = maxi(GameState.highest_unlocked, 3)
	var scene_name := str(args.get("scene", "menu"))
	var path := Const.SCENE_MENU if scene_name == "menu" else Const.SCENE_GAME
	var inst := (load(path) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in 30:
		await get_tree().process_frame
	if args.has("screen") and inst.has_method("_open_screen"):
		inst.call("_open_screen", str(args["screen"]))
		for i in 20:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("captura ", img.get_size(), " -> ", out, " (", err, ")")
	get_tree().quit(0 if err == OK else 1)
