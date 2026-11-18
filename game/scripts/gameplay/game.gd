class_name Game
extends Node3D
## Gameplay scene orchestrator: builds the map, spawns the player, wires
## rounds/HUD/controls/menus and handles pause and defeat.

const START_POINTS := 500

var map: SectorMap
var player: Player
var pool: ZombiePool
var rounds: RoundManager
var hud: HUD
var touch: TouchControls
var pause_menu: PauseMenu
var game_over: GameOverScreen
var _ended := false


func _ready() -> void:
	DisplayServer.screen_set_keep_on(true)
	GameState.start_match(START_POINTS)
	map = SectorMap.new()
	map.name = "SectorMap"
	add_child(map)
	map.build()
	FX.attach_world(self)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_transform = map.player_spawn
	player.weapons.give_weapon(load("res://resources/weapons/pistol.tres"))
	pool = ZombiePool.new()
	pool.name = "Zombies"
	add_child(pool)
	rounds = RoundManager.new()
	rounds.name = "RoundManager"
	add_child(rounds)
	rounds.setup(player, pool, map.spawn_points, map.is_zone_open)
	touch = TouchControls.new()
	add_child(touch)
	touch.bind(player)
	hud = HUD.new()
	add_child(hud)
	hud.bind(player, rounds, touch)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	game_over = GameOverScreen.new()
	add_child(game_over)
	if OS.has_feature("mobile"):
		add_child(PerfGovernor.new())
	touch.pause_pressed.connect(toggle_pause)
	player.died.connect(_on_player_died)
	map.zone_opened.connect(_on_zone_opened)
	Audio.play_ambience("ambience_city", -14.0)
	Audio.play_music("ambient_game", 2.0, -10.0)
	hud.show_banner("SECTOR ABANDONADO", "Sobrevive todo lo que puedas.", UIStyle.ACCENT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not _ended and not get_tree().paused:
			toggle_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


func toggle_pause() -> void:
	if _ended:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	touch.set_enabled(not p)
	if p:
		player.fire_held = false
		pause_menu.open()
	else:
		pause_menu.close()


func _on_zone_opened(id: String) -> void:
	var names := {"street": "CALLE PRINCIPAL", "gas": "GASOLINERA", "warehouse": "ALMACÉN 7", "lab": "SUBESTACIÓN 4"}
	hud.show_banner("ZONA ABIERTA", names.get(id, id), UIStyle.ACCENT)


func _on_player_died() -> void:
	_ended = true
	touch.set_enabled(false)
	Audio.stop_music(2.0)
	await get_tree().create_timer(2.6).timeout
	var stats := GameState.end_match()
	game_over.show_stats(stats)


func _exit_tree() -> void:
	FX.detach_world()
	DisplayServer.screen_set_keep_on(false)
	get_tree().paused = false
