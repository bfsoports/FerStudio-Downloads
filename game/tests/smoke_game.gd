extends Node
## Smoke test: boots the gameplay scene, lets rounds run, captures screenshots
## and reports performance/state. Run under a real renderer (xvfb + opengl3).

var shots_dir := "user://smoke"
var _game
var gs


func _ready() -> void:
	var out := OS.get_cmdline_user_args()
	if out.size() > 0:
		shots_dir = out[0]
	DirAccess.make_dir_recursive_absolute(shots_dir)
	gs = GameState
	_game = load("res://scenes/gameplay/game.tscn").instantiate()
	add_child(_game)
	await get_tree().create_timer(1.0).timeout
	print("SMOKE scene: ", _game.name)
	var player = _game.player
	await _shot("01_start")
	# look around the start area
	player.rotate_y(deg_to_rad(180))
	await _shot("02_start_back")
	player.rotate_y(deg_to_rad(180))
	# let round 1 start and zombies arrive
	await get_tree().create_timer(14.0).timeout
	print("SMOKE round=", gs.current_round, " alive=", _game.pool.alive_count(), " fps=", Engine.get_frames_per_second())
	await _shot("03_round1")
	# open first door with points and walk into the street
	gs.add_points(5000)
	for d in _game.map.doors:
		if d.zone_b == "street":
			d.open_door()
	player.global_position = Vector3(2, 0.2, 10)
	await get_tree().create_timer(1.5).timeout
	await _shot("04_street")
	player.global_position = Vector3(-20, 0.2, 12)
	player.rotation.y = 0
	for d in _game.map.doors:
		d.open_door()
	await get_tree().create_timer(1.0).timeout
	await _shot("05_gas")
	player.global_position = Vector3(-22, 0.2, -14)
	await get_tree().create_timer(1.0).timeout
	await _shot("06_lab_forge")
	player.global_position = Vector3(10, 0.2, -10)
	player.rotation.y = 0
	await get_tree().create_timer(1.0).timeout
	await _shot("07_warehouse")
	# shooting test
	player.global_position = Vector3(0, 0.2, 26)
	var killed_before: int = gs.kills
	for i in 60:
		var zs = _game.pool.active_zombies()
		if zs.size() > 0:
			var z = zs[0]
			if z.is_alive():
				player.look_at(Vector3(z.global_position.x, player.global_position.y, z.global_position.z), Vector3.UP)
				z.take_hit(80.0, z.global_position + Vector3.UP, Vector3.FORWARD, i % 3 == 0, player.weapons)
		await get_tree().create_timer(0.25).timeout
	print("SMOKE kills: ", gs.kills - killed_before, " points=", gs.points, " round=", gs.current_round)
	await _shot("08_combat")
	print("SMOKE done fps=", Engine.get_frames_per_second(), " static_mem_MB=", OS.get_static_memory_usage() / 1048576)
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	print("SMOKE shot ", name)
