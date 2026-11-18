extends Node
## Capturas reales del juego en ejecución (anfitrión local con servidor en el mismo proceso).
## Uso: xvfb-run -a godot --path . -- --demo --out=<dir> --views="nombre:x,z,giro,cabeceo,hora[,clima];…"
##      [--hud] [--touch] [--menu=main,play,…] [--ui=inventory,craft,…]
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
	# recorrido opcional por las pantallas del menú principal: --menu=main,play,profile,settings,legal
	if a.has("menu"):
		Ui.goto_menu()
		await get_tree().create_timer(float(a.get("settle", 1.2)) + 1.0).timeout
		for screen: String in String(a.menu).split(",", false):
			var parts := screen.split("@")
			if parts[0] != "main":
				Ui.open(parts[0], {"tab": parts[1]} if parts.size() > 1 else {})
			for i in 10:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [out, screen.replace("@", "_")])
			print("DEMO menú ", screen)
			if parts[0] != "main":
				Ui.close_top()
		if not a.has("views") and not a.has("ui"):
			get_tree().quit(0)
			return
	Ui.start_host("demo", int(a.get("port", 24699)), {"test_kit": true, "start_hour": 10.0})
	var waited := 0.0
	while not Ui.in_world and waited < 200.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not Ui.in_world:
		print("DEMO no se pudo entrar en el mundo")
		get_tree().quit(1)
		return
	var wr: WorldRoot = WorldRoot.current
	Ui.hud.visible = a.has("hud")
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
		var here: Sector = wr.streamer.sectors.get(WorldMap.sector_key(wr.player.global_position.x, wr.player.global_position.z))
		print("DEMO   posición=%s  sector_centro=%s  nivel_sector=%d  trabajos=%d" % [str(wr.player.global_position.snapped(Vector3.ONE * 0.1)), str(wr.streamer.center),
			-9 if here == null else here.level, wr.streamer.pending()])
		print("DEMO captura %s  sectores=%d  nodos=%d  dibujados=%d  primitivas=%d  fps=%d" % [nm, wr.streamer.sectors.size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Engine.get_frames_per_second())])
	# recorrido opcional por las pantallas de partida: --ui=inventory,craft,build,map,social,journal,pause
	if a.has("ui"):
		Ui.hud.visible = true
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/ui_hud.png" % out)
		for screen: String in String(a.ui).split(",", false):
			var parts := screen.split("@")
			Ui.close_all()
			Ui.open(parts[0], {"tab": parts[1]} if parts.size() > 1 else {})
			for i in 10:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/ui_%s.png" % [out, screen.replace("@", "_")])
			print("DEMO pantalla ", screen)
		Ui.close_all()
	Net.leave()
	get_tree().quit(0)
