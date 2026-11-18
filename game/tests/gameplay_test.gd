extends Node
## Automated integration tests for SECTOR ABANDONADO gameplay systems.
## Run: godot --headless --path . res://tests/gameplay_test.tscn
## Prints "TEST PASS/FAIL <name>" lines and a summary; exit code = failures.

var game: Game
var results := []


func _ready() -> void:
	Engine.time_scale = 2.0
	game = load("res://scenes/gameplay/game.tscn").instantiate()
	add_child(game)
	await _wait(0.5)
	await _test_initial_state()
	await _test_round_spawn_and_chase()
	await _test_barricade_break_and_repair()
	await _test_shooting_and_points()
	await _test_purchases()
	await _test_mystery_box()
	await _test_forge()
	await _test_perks()
	await _test_round_progression()
	await _test_boss()
	await _test_player_death()
	var fails := results.filter(func(r): return not r.ok).size()
	print("TEST SUMMARY: %d passed, %d failed" % [results.size() - fails, fails])
	get_tree().quit(fails)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(name: String, ok: bool, info: String = "") -> void:
	results.append({"name": name, "ok": ok})
	print("TEST %s %s %s" % ["PASS" if ok else "FAIL", name, info])


func _test_initial_state() -> void:
	var p := game.player
	_check("player_has_pistol", p.weapons.has_weapon("pistol"))
	_check("start_points_500", GameState.points == 500, str(GameState.points))
	_check("map_spawn_points", game.map.spawn_points.size() >= 30, str(game.map.spawn_points.size()))
	_check("map_doors", game.map.doors.size() == 5)
	_check("navmesh_loaded", game.map.nav_region.navigation_mesh.get_polygon_count() > 100)
	_check("only_start_zone_open", game.map.is_zone_open("start") and not game.map.is_zone_open("street"))


func _test_round_spawn_and_chase() -> void:
	await _wait(5.0)
	_check("round_1_started", GameState.current_round == 1, "round=%d" % GameState.current_round)
	var zs := game.pool.active_zombies()
	_check("zombies_spawned", zs.size() > 0, "active=%d" % zs.size())
	_check("spawns_respect_cap", game.pool.alive_count() <= Settings.max_active_zombies())
	# all spawns in round 1 must come from the open start zone
	var wrong := 0
	for z in zs:
		if z.spawn_point and z.spawn_point.zone_id != "start":
			wrong += 1
	_check("spawn_zone_gating", wrong == 0)


func _test_barricade_break_and_repair() -> void:
	# wait until some zombie is in the play area (broke through)
	var p := game.player
	var reached := false
	var min_d := INF
	for i in 60:
		await _wait(1.0)
		for z in game.pool.active_zombies():
			if z.is_alive() and z.state_name in ["chase", "attack"]:
				min_d = minf(min_d, z.global_position.distance_to(p.global_position))
				if z.state_name == "attack" or min_d < 3.0:
					reached = true
		if reached:
			break
	var broken := 0
	for b in game.map.barricades:
		if b.planks < Barricade.PLANKS:
			broken += 1
	_check("zombies_break_barricades", broken > 0, "damaged windows=%d" % broken)
	_check("zombies_reach_player", reached, "closest=%.1f m" % min_d)
	# repair: pick a damaged barricade
	for b in game.map.barricades:
		if b.planks < Barricade.PLANKS:
			var before := b.planks
			var pts := GameState.points
			b._repair_one(p)
			_check("barricade_repair", b.planks == before + 1 and GameState.points >= pts, "planks %d->%d" % [before, b.planks])
			break


func _test_shooting_and_points() -> void:
	var p := game.player
	p.health = 1e6
	p.max_health = 1e6
	var target: Zombie = null
	for z in game.pool.active_zombies():
		if z.is_alive():
			target = z
			break
	if target == null:
		_check("shooting_target_available", false)
		return
	# put the zombie right in front of the camera and fire real hitscan bullets
	target.global_position = p.global_position - p.global_basis.z * 4.0
	target.set_physics_process(false)
	await _wait(0.1)
	var pts := GameState.points
	var kills := GameState.kills
	var slot := p.weapons.current_slot()
	slot.mag = 50
	for i in 40:
		p.head.rotation.x = 0.0
		p.look_at(Vector3(target.global_position.x, p.global_position.y, target.global_position.z), Vector3.UP)
		p.weapons._cooldown = 0.0
		p.weapons._semi_ready = true
		p.weapons.try_fire()
		await _wait(0.05)
		if not target.is_alive():
			break
	target.set_physics_process(true)
	_check("hitscan_kills_zombie", GameState.kills > kills, "kills %d->%d" % [kills, GameState.kills])
	_check("points_awarded", GameState.points > pts, "points %d->%d" % [pts, GameState.points])
	_check("ammo_consumed", slot.mag < 50)


func _test_purchases() -> void:
	var p := game.player
	GameState.add_points(20000)
	var door: Door = null
	for d in game.map.doors:
		if d.zone_b == "street":
			door = d
	var pts := GameState.points
	door.interact(p)
	_check("door_purchase", door.is_open and GameState.points == pts - door.price)
	_check("zone_opened", game.map.is_zone_open("street"))
	var link: NavigationLink3D = door.get_meta("link")
	_check("door_nav_link_enabled", link.enabled)
	# wall weapon
	var wall: WallWeapon = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is WallWeapon and n.weapon_id == "shotgun":
			wall = n
	pts = GameState.points
	wall.interact(p)
	_check("wall_weapon_purchase", p.weapons.has_weapon("shotgun") and GameState.points == pts - wall.data.wall_cost)
	# ammo refill
	var s := p.weapons.find_slot("shotgun")
	s.reserve = 0
	pts = GameState.points
	wall.interact(p)
	_check("wall_ammo_refill", s.reserve == s.max_reserve() and GameState.points == pts - wall.data.ammo_cost)
	# insufficient funds
	var saved := GameState.points
	GameState.points = 10
	var door2: Door = null
	for d in game.map.doors:
		if not d.is_open:
			door2 = d
			break
	door2.interact(p)
	_check("purchase_denied_without_points", not door2.is_open and GameState.points == 10)
	GameState.points = saved


func _test_mystery_box() -> void:
	var p := game.player
	var box := game.map.mystery_box
	var owned := p.weapons.slots.size()
	box.uses = 0
	box.interact(p)
	_check("box_rolling", box.state == MysteryBox.State.ROLLING)
	await _wait(MysteryBox.CYCLE_TIME + 0.3)
	_check("box_offers_weapon", box.state == MysteryBox.State.OFFER and box._offer != null)
	var offered := box._offer.id
	box.interact(p)
	_check("box_gives_weapon", p.weapons.has_weapon(offered), offered)


func _test_forge() -> void:
	var p := game.player
	var forge: PackAPunch = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is PackAPunch:
			forge = n
	var s := p.weapons.current_slot()
	var id := s.data.id
	var dmg_before := s.data.get_damage(false)
	var pts := GameState.points
	forge.interact(p)
	_check("forge_takes_weapon", forge.state == PackAPunch.State.PROCESSING and GameState.points == pts - PackAPunch.PRICE)
	await _wait(PackAPunch.PROCESS_TIME + 0.3)
	_check("forge_ready", forge.state == PackAPunch.State.READY)
	forge.interact(p)
	var up := p.weapons.find_slot(id)
	_check("forge_upgrades_weapon", up != null and up.upgraded and up.data.get_damage(true) > dmg_before, id + " -> " + (up.display_name() if up else "?"))
	_check("forge_bigger_mag", up != null and up.max_mag() >= up.data.mag_size)


func _test_perks() -> void:
	var p := game.player
	p.max_health = 100.0
	p.health = 100.0
	GameState.add_points(15000)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is PerkMachine:
			n.interact(p)
	await _wait(1.2)
	_check("all_perks_bought", p.perks.size() == 5, str(p.perks))
	_check("perk_vitality_effect", p.max_health == 200.0)
	_check("perk_reload_effect", p.reload_multiplier() < 1.0)
	_check("perk_damage_effect", p.damage_multiplier() > 1.0)


func _test_round_progression() -> void:
	var r0 := GameState.current_round
	game.rounds.to_spawn = 0
	game.rounds._boss_pending = false
	game.rounds._extra_queue.clear()
	game.pool.kill_all()
	await _wait(4.0)
	game.rounds.skip_intermission()
	await _wait(2.0)
	_check("next_round_starts", GameState.current_round == r0 + 1, "%d -> %d" % [r0, GameState.current_round])
	var walker: ZombieData = load("res://resources/zombies/walker.tres")
	_check("health_scales_with_round", walker.health_for_round(20) > walker.health_for_round(5) * 3.0)
	_check("horde_size_scales", game.rounds.zombies_for_round(15) > game.rounds.zombies_for_round(3) * 3)


func _test_boss() -> void:
	game.rounds._spawn_boss()
	await _wait(1.0)
	var boss: Zombie = null
	for z in game.pool.active_zombies():
		if z.data.is_boss:
			boss = z
	_check("boss_spawns", boss != null and boss.is_alive())
	if boss:
		var pts := GameState.points
		boss.take_hit(boss.max_health * 0.6, boss.global_position + Vector3.UP, Vector3.FORWARD, false, null, true)
		await _wait(0.5)
		boss.take_hit(1e9, boss.global_position + Vector3.UP, Vector3.FORWARD, false, null, true)
		await _wait(0.2)
		_check("boss_reward", GameState.points >= pts + 2500)


func _test_player_death() -> void:
	var p := game.player
	p.max_health = 100.0
	p.health = 10.0
	p._hurt_cooldown = 0.0
	p.take_damage(50.0, p.global_position + Vector3.FORWARD)
	_check("player_dies", not p.alive)
	await _wait(3.5)
	_check("game_over_shown", game.game_over._root.visible)
	_check("records_saved", GameState.best_round >= GameState.current_round)
