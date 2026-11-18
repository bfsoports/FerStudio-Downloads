extends Node
## Boot — punto de entrada. Decide el modo de ejecución según los argumentos:
##   (sin argumentos)                 cliente normal: logotipo, carga y menú principal
##   -- --server [--port=N] [--world=nombre] [--data=dir] [--difficulty=x] [--day-length=s]
##                                    servidor dedicado sin ventana (usar con --headless)
##   -- --bot=escenario --connect=host:puerto --name=Nombre
##                                    cliente automático de pruebas (tests/bot_client.gd)
## Los argumentos de usuario van después de "--" en la línea de órdenes de Godot.

static func args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq := a.find("=")
			if eq > 0:
				out[a.substr(2, eq - 2)] = a.substr(eq + 1)
			else:
				out[a.substr(2)] = "1"
	return out

func _ready() -> void:
	var a := args()
	if a.has("data"):
		ServerPersistence.base_dir = String(a.data)
	if a.has("server") or a.has("bot"):
		Ui.enabled = false          # sin interfaz: servidor dedicado y clientes automáticos de prueba
		Ui.visible = false
	if a.has("server"):
		_run_server(a)
	elif a.has("demo"):
		var demo_script: GDScript = load("res://tests/demo_shots.gd")
		if demo_script == null or not demo_script.can_instantiate():
			printerr("DEMO guion con errores")
			get_tree().quit(2)
			return
		var demo: Node = demo_script.new()
		demo.name = "Demo"
		get_tree().root.add_child.call_deferred(demo)
		demo.call_deferred("run", a)
	elif a.has("bot"):
		var bot: Node = (load("res://tests/bot_client.gd") as GDScript).new()
		bot.name = "Bot"
		add_child(bot)
		bot.call("run", a)
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/boot/splash.tscn")

func _run_server(a: Dictionary) -> void:
	var opts: Dictionary = {}
	if a.has("difficulty"):
		opts["difficulty"] = String(a.difficulty)
	if a.has("day-length"):
		opts["day_length"] = maxf(60.0, float(a["day-length"]))
	if a.has("name"):
		opts["name"] = String(a.name)
	if a.has("test-kit"):
		opts["test_kit"] = true
	if a.has("hour"):
		opts["start_hour"] = float(a.hour)
	var port := int(a.get("port", Protocol.DEFAULT_PORT))
	var err := Net.host(port, true, String(a.get("world", "valle")), opts)
	if err != OK:
		printerr("No se pudo iniciar el servidor (error %d)" % err)
		get_tree().quit(1)
		return
	if a.has("exit-after"):
		await get_tree().create_timer(float(a["exit-after"])).timeout
		Net.leave()
		get_tree().quit(0)
