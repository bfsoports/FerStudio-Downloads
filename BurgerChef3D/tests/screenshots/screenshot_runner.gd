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
	if args.has("recipes"):
		Events.recipes_opened.emit()
		for i in 20:
			await get_tree().process_frame
	if args.has("quality"):
		SettingsManager.quality = int(args["quality"])
		SettingsManager.apply_graphics()
	if args.has("noshadow"):
		SettingsManager.shadows = false
		SettingsManager.apply_graphics()
	if args.has("fxaa"):
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if args.has("scale3d"):
		get_viewport().scaling_3d_scale = float(args["scale3d"])
	if args.has("bench"):
		await _bench(int(args.get("bench", "120")))
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
			return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("captura ", img.get_size(), " -> ", out, " (", err, ")")
	get_tree().quit(0 if err == OK else 1)

## Mide el coste de render de la escena: llamadas de dibujo, objetos, triángulos y tiempo por fotograma.
func _bench(frames: int) -> void:
	var t0 := Time.get_ticks_usec()
	var dc := 0.0
	var obj := 0.0
	var prim := 0.0
	var proc := 0.0
	var phys := 0.0
	for i in frames:
		await get_tree().process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	print("BENCH draw_calls=%d objects=%d primitives=%d frame_ms=%.1f process_ms=%.2f physics_ms=%.2f nodes=%d lights=%d" % [int(dc / frames), int(obj / frames),
		int(prim / frames), ms, proc / frames * 1000.0, phys / frames * 1000.0, get_tree().get_node_count(), _count_lights(get_tree().root)])

func _count_lights(n: Node) -> int:
	var c := 1 if (n is Light3D and (n as Light3D).is_visible_in_tree()) else 0
	for ch in n.get_children():
		c += _count_lights(ch)
	return c
