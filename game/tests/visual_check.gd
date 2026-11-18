extends Node
## Visual regression check: viewmodels of every weapon and each zombie
## archetype spawned in front of the player. Saves PNGs to the given folder.

var dir := "user://visual"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		dir = a[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var game = load("res://scenes/gameplay/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rounds.set_process(false)          # no natural spawns during the check
	var p = game.player
	p.global_position = Vector3(3, 0.1, 9)
	p.rotation.y = 0
	for d in game.map.doors:
		d.open_door()
	game.hud.visible = false
	for id in ["pistol", "shotgun", "smg", "rifle", "sniper", "lmg"]:
		p.weapons.give_weapon(load("res://resources/weapons/%s.tres" % id))
		await get_tree().create_timer(0.8).timeout
		await _shot("vm_" + id)
	p.weapons.toggle_aim()
	await get_tree().create_timer(0.6).timeout
	await _shot("vm_lmg_ads")
	p.weapons.toggle_aim()
	var x := -3.0
	for id in ["walker", "runner", "armored", "tank", "boss"]:
		var z = game.pool.acquire(id)
		z.activate(Transform3D(Basis(Vector3.UP, PI), Vector3(3 + x, 0.05, 3.5)), 3, p, null, false)
		z.set_physics_process(false)
		z.animator.play(z.data.anim_walk, 0.0)
		x += 1.6
	p.global_position = Vector3(3, 0.1, 10.5)
	await get_tree().create_timer(1.2).timeout
	await _shot("zombies_lineup")
	p.global_position = Vector3(-26, 0.1, 9)
	p.rotation.y = deg_to_rad(-90)
	await get_tree().create_timer(0.5).timeout
	await _shot("mystery_box_area")
	p.global_position = Vector3(-22, 0.1, -17.5)
	p.rotation.y = 0
	await get_tree().create_timer(0.5).timeout
	await _shot("forge_close")
	p.global_position = Vector3(26, 0.1, -2)
	p.rotation.y = deg_to_rad(-90)
	await get_tree().create_timer(0.5).timeout
	await _shot("perk_vitality")
	game.hud.visible = true
	p.global_position = Vector3(4, 0.1, 15.5)
	p.rotation.y = PI
	await get_tree().create_timer(0.8).timeout
	await _shot("wallbuy_prompt")
	get_tree().quit()


func _shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
	print("VISUAL ", n)
