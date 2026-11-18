extends Node
## Stress test: high round, max simultaneous zombies chasing the player in the
## open street for N seconds. Reports CPU frame times, draw calls, objects and
## memory. Run with a real renderer for draw-call numbers.

var game: Game
var samples := {"process": [], "physics": [], "draw_calls": [], "primitives": [], "fps": []}


func _ready() -> void:
	var q := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else Settings.quality
	Settings.quality = q
	Settings.apply_all()
	game = load("res://scenes/gameplay/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	var p := game.player
	p.max_health = 1e9
	p.health = 1e9
	for d in game.map.doors:
		d.open_door()
	p.global_position = Vector3(10, 0.1, 6)
	# jump to round 15
	game.rounds.round_number = 14
	game.rounds.to_spawn = 0
	game.rounds._intermission_t = 0.1
	game.rounds.in_intermission = true
	await get_tree().create_timer(12.0).timeout
	var t := 0.0
	while t < 25.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		p.rotate_y(0.15)
		samples.process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		samples.physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		samples.fps.append(Performance.get_monitor(Performance.TIME_FPS))
	var alive := game.pool.alive_count()
	print("PERF quality=%s round=%d alive_zombies=%d (cap %d)" % [Settings.quality_name(), GameState.current_round, alive, Settings.max_active_zombies()])
	for k in samples:
		var arr: Array = samples[k]
		var avg := 0.0
		for v in arr:
			avg += v
		avg /= maxf(1, arr.size())
		print("PERF %s avg=%.2f max=%.2f" % [k, avg, arr.max()])
	print("PERF objects=%d nodes=%d static_mem=%.1fMB video_mem=%.1fMB" % [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_tree().quit()
