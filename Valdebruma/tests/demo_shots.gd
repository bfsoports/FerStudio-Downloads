extends Node
## Capturas reales del juego en ejecución (anfitrión local con servidor en el mismo proceso).
## Uso: xvfb-run -a godot --path . -- --demo --out=<dir> --views="nombre:x,z,giro,cabeceo,hora[,clima];…"
## Coloca al jugador con el servidor (teleport autorizado en modo anfitrión), espera a que
## carguen los sectores cercanos y guarda cada captura como <dir>/<nombre>.png.

func run(a: Dictionary) -> void:
	get_tree().create_timer(float(a.get("max-time", 240.0))).timeout.connect(func() -> void:
		print("DEMO tiempo máximo agotado")
		get_tree().quit(3))
	var out := String(a.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	Profile.use_test_identity("demo", "Demo")
	ServerPersistence.base_dir = String(a.get("data", "user://demo_server"))
	var err := Net.host(int(a.get("port", 24699)), false, "demo", {"test_kit": true, "start_hour": 10.0})
	if err != OK:
		print("DEMO no se pudo abrir el servidor")
		get_tree().quit(1)
		return
	Net.send(Protocol.C.HELLO, {"v": Protocol.VERSION, "account": Profile.account, "token": Profile.token, "name": Profile.player_name, "cos": Profile.cosmetics})
	await Session.welcomed
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var wr: WorldRoot = WorldRoot.current
	if not wr.is_loaded:
		await wr.loaded
	if a.has("hud") and has_node("/root/Ui"):
		get_node("/root/Ui").call("show_hud")
	var srv: GameServer = Net.server
	for view: String in String(a.get("views", "inicio:258,1000,0,0,10")).split(";", false):
		var nm := view.split(":")[0]
		var v := view.split(":")[1].split(",")
		var x := float(v[0])
		var z := float(v[1])
		srv.env.hour = float(v[4]) if v.size() > 4 else 10.0
		if v.size() > 5:
			srv.env.set_weather(v[5])
			var w: Dictionary = ServerEnvironment.WEATHER[v[5]]
			srv.env.cloud = w.cloud; srv.env.fog = w.fog; srv.env.rain = w.rain; srv.env.wind = w.wind
			wr.sky.cloud = w.cloud; wr.sky.fog = w.fog; wr.sky.rain_amount = w.rain
		srv.broadcast(Protocol.S.ENV, srv.env.packet())
		var y := GameData.world.ground(x, z) + (float(v[6]) if v.size() > 6 else 0.1)
		srv.teleport(srv.players[1], Vector3(x, y, z))
		await get_tree().create_timer(0.3).timeout
		wr.player.yaw = deg_to_rad(float(v[2]))
		wr.player.pitch = deg_to_rad(float(v[3]))
		wr.streamer.budget_ms = 30.0
		var guard := 0
		while (wr.streamer.pending() > 0 or guard < 20) and guard < 900:
			guard += 1
			await get_tree().process_frame
		await get_tree().create_timer(float(a.get("settle", 1.2))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, nm])
		print("DEMO captura %s  sectores=%d  nodos=%d  dibujados=%d  primitivas=%d  fps=%d" % [nm, wr.streamer.sectors.size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Engine.get_frames_per_second())])
	Net.leave()
	get_tree().quit(0)
