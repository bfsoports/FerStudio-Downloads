extends Node3D
## Raíz de una partida: construye el restaurante y conecta jugador, pedidos, clientes, turno, HUD, pausa y resultados.
## Los parámetros (modo, nivel) llegan por SceneManager.params.

@onready var restaurant: Restaurant = $Restaurant
@onready var player: PlayerController = $Player
@onready var shift: ShiftManager = $Systems/ShiftManager
@onready var orders: OrderManager = $Systems/OrderManager
@onready var spawner: CustomerSpawner = $Systems/CustomerSpawner
@onready var hud: HUD = $HUD

var _cfg: Dictionary = {}
var _started := false
var _ended := false
var _paused := false
var _pause_menu: PauseMenu = null
var _recipes_panel: RecipesPanel = null
var _result: ResultScreen = null
var _tutorial: Tutorial = null
var _reviving := false           # está abierta la oferta de segunda oportunidad (anuncio recompensado)
var _revive_layer: Control = null
var _revive_reason := ""

func _ready() -> void:
	_cfg = _make_config(SceneManager.params)
	var is_tutorial := str(_cfg.get("mode", "")) == Const.MODE_TUTORIAL
	GameState.tracking_enabled = not is_tutorial
	restaurant.build()
	_warm_up()
	restaurant.set_menu(_cfg.get("recipes", []))
	player.global_position = restaurant.player_spawn
	player.setup(hud.touch)
	orders.shift = shift
	for sp in restaurant.service_points:
		(sp as ServicePoint).orders = orders
	_update_service_points()
	spawner.setup(restaurant, orders, shift)
	hud.bind(shift, orders)
	hud.show_config(_cfg)
	Events.shift_ended.connect(_on_shift_ended)
	Events.pause_requested.connect(_toggle_pause)
	Events.back_requested.connect(_on_back)
	Events.app_backgrounded.connect(_on_app_backgrounded)
	Events.recipes_opened.connect(_open_recipes)
	if str(_cfg.get("mode", "")) == Const.MODE_CAMPAIGN:
		shift.revive_handler = _offer_revive
	AudioManager.play_music("game")
	if is_tutorial:
		restaurant.grill.burn_protect = true
		restaurant.fryer.burn_protect = true
		_tutorial = Tutorial.new()
		_tutorial.name = "Tutorial"
		add_child(_tutorial)
		_tutorial.setup(self, restaurant, player, hud, spawner, shift)
	var gov := PerfGovernor.new()
	gov.name = "PerfGovernor"
	add_child(gov)
	_countdown()

func _exit_tree() -> void:
	GameState.tracking_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

# ------------------------------------------------------------------ configuración del turno
func _make_config(p: Dictionary) -> Dictionary:
	var mode := str(p.get("mode", Const.MODE_CAMPAIGN))
	if mode == Const.MODE_TUTORIAL:
		# turno guiado: sin tiempo, sin fallos, un solo puesto, un cliente cada vez (lo llama el tutorial) y una receta
		return {"mode": mode, "level_id": 0, "duration": 0.0, "recipes": [Tutorial.RECIPE], "spawn_interval": 9999.0,
			"patience": 900.0, "max_active": 1, "win": {}, "lose": {}, "auto_spawn": false, "dirty_trays": true}
	if mode == Const.MODE_FREE:
		var d := clampi(Util.to_int(p.get("difficulty", 1), 1), 1, 5)
		var spawn: Array = [26.0, 21.0, 17.0, 14.0, 11.0]
		var patience: Array = [100.0, 85.0, 72.0, 62.0, 52.0]
		var lanes: Array = [1, 2, 2, 3, 3]
		return {"mode": mode, "level_id": 0, "duration": 0.0, "recipes": GameState.unlocked_recipe_ids(),
			"spawn_interval": spawn[d - 1], "patience": patience[d - 1], "max_active": lanes[d - 1],
			"win": {}, "lose": {}, "difficulty": d, "dirty_trays": d >= 3}
	var lid := clampi(Util.to_int(p.get("level_id", 1), 1), 1, mini(GameState.highest_unlocked, Catalog.levels.size()))
	var cfg: Dictionary = Catalog.level_def(lid).duplicate(true)
	cfg["mode"] = Const.MODE_CAMPAIGN
	cfg["level_id"] = lid
	cfg["recipes"] = GameState.campaign_recipes(lid)
	return cfg

func _update_service_points() -> void:
	var lanes := clampi(mini(Util.to_int(_cfg.get("max_active", 1), 1), EconomyManager.service_points()), 1, restaurant.service_points.size())
	for i in restaurant.service_points.size():
		(restaurant.service_points[i] as ServicePoint).set_open(i < lanes)

func _countdown() -> void:
	player.controls_enabled = false
	for n in [3, 2, 1]:
		hud.show_center_text(str(n))
		AudioManager.play_sfx("tick")
		await get_tree().create_timer(0.8, false).timeout
	hud.show_center_text(Loc.t("hud.go"))
	AudioManager.play_sfx("go")
	restaurant.refill_all()
	_started = true
	player.controls_enabled = true
	_capture_mouse(true)
	shift.start(_cfg)
	if _tutorial != null:
		_tutorial.begin()
	elif bool(_cfg.get("dirty_trays", false)) and GameState.stat("trays_washed") == 0:
		Events.toast.emit(Loc.t("toast.dirty_trays"), "info")
	await get_tree().create_timer(0.7, false).timeout
	hud.show_center_text("")

func _capture_mouse(on: bool) -> void:
	if OS.has_feature("mobile") or SettingsManager.force_touch_ui:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if _ended or not _started:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_toggle_pause()
	elif event.is_action_pressed("recipes") and not _paused:
		get_viewport().set_input_as_handled()
		if _recipes_panel != null:
			_close_recipes()
		else:
			_open_recipes()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _paused and not SettingsManager.force_touch_ui:
		_capture_mouse(true)

# ------------------------------------------------------------------ pausa
func _toggle_pause() -> void:
	if _ended or not _started or _reviving:
		return
	if _recipes_panel != null:
		_close_recipes()
		return
	if _paused:
		_resume()
	else:
		_pause()

func _freeze(on: bool) -> void:
	get_tree().paused = on
	player.controls_enabled = not on
	hud.touch.set_enabled(not on)
	_capture_mouse(not on)
	Events.pause_changed.emit(on)

func _pause() -> void:
	_paused = true
	_freeze(true)
	var mode := str(_cfg.get("mode", ""))
	_pause_menu = PauseMenu.new(mode == Const.MODE_FREE, mode == Const.MODE_TUTORIAL)
	hud.add_overlay(_pause_menu)
	_pause_menu.resume_requested.connect(_resume)
	_pause_menu.restart_requested.connect(_restart)
	_pause_menu.exit_requested.connect(_go_menu)
	_pause_menu.finish_requested.connect(_finish_free)

func _resume() -> void:
	_paused = false
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	_freeze(false)

func _open_recipes() -> void:
	if _ended or not _started or _paused or _recipes_panel != null:
		return
	_freeze(true)
	_recipes_panel = RecipesPanel.new(_cfg.get("recipes", []))
	hud.add_overlay(_recipes_panel)
	_recipes_panel.closed.connect(_close_recipes)

func _close_recipes() -> void:
	if _recipes_panel != null:
		_recipes_panel.queue_free()
		_recipes_panel = null
	_freeze(false)

func _on_back() -> void:
	if _reviving:
		_decline_revive()
		return
	if _result != null:
		_go_menu()
	elif _recipes_panel != null:
		_close_recipes()
	elif _paused and _pause_menu != null:
		_pause_menu.go_back()
	else:
		_toggle_pause()

func _on_app_backgrounded() -> void:
	# un anuncio a pantalla completa también manda la app a segundo plano: no es una pausa del jugador
	if Ads.showing or _reviving:
		return
	if _started and not _ended and not _paused and _recipes_panel == null:
		_pause()

func _restart() -> void:
	SceneManager.change_scene(Const.SCENE_GAME, SceneManager.params)

func _go_menu() -> void:
	SaveManager.save_now()
	SceneManager.change_scene(Const.SCENE_MENU)

func _finish_free() -> void:
	_resume()
	if _tutorial != null:
		_tutorial.skip()
		return
	shift.finish("quit")

## Lo llama el tutorial al terminar o al saltarlo: vuelve al menú o empieza el nivel 1.
func leave_tutorial(play_level_1: bool) -> void:
	_ended = true
	shift.running = false
	SaveManager.save_now()
	if play_level_1:
		SceneManager.change_scene(Const.SCENE_GAME, {"mode": Const.MODE_CAMPAIGN, "level_id": 1})
	else:
		SceneManager.change_scene(Const.SCENE_MENU)

## Detiene el juego bajo un diálogo propio (final del tutorial).
func freeze_for_dialog(on: bool) -> void:
	_ended = on
	_freeze(on)

## true mientras hay un menú o panel abierto encima del juego (el tutorial espera a que se cierre).
func is_overlay_open() -> bool:
	return _paused or _recipes_panel != null

# ------------------------------------------------------------------ segunda oportunidad (anuncio recompensado)
## Lo llama ShiftManager al ir a perder un nivel de campaña. Si hay un anuncio recompensado listo se ofrece revivir
## (+segundos si se acabó el tiempo, o perdonar los fallos); si no, el turno termina como siempre.
func _offer_revive(reason: String) -> void:
	if not Ads.rewarded_ready():
		shift.finish(reason, true)
		return
	_reviving = true
	_revive_reason = reason
	_freeze(true)
	_revive_layer = _build_revive_dialog(reason)
	hud.add_overlay(_revive_layer)
	AudioManager.play_sfx("impatient", -4.0)

func _build_revive_dialog(reason: String) -> Control:
	var layer := Control.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel_w := minf(620.0, UIKit.canvas_size(hud).x - 40.0)
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	var ic := UIKit.icon_rect("clock" if reason == "time" else "rebirth", 72)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UIKit.label(Loc.t("ads.revive_title"), "LabelHeader", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body_text := Loc.t("ads.revive_time", [Ads.revive_seconds()]) if reason == "time" else Loc.t("ads.revive_failed")
	var body := UIKit.label(body_text, "LabelLight", 21)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(panel_w - 40.0, 0)
	v.add_child(body)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_w := minf(260.0, (panel_w - 50.0) * 0.5)
	var no := UIKit.icon_text_button("close", Loc.t("ads.no_thanks"), "ButtonSecondary", UIKit.H_BTN, btn_w, 32)
	no.pressed.connect(_decline_revive)
	var yes := UIKit.icon_text_button("gift", Loc.t("ads.watch"), "ButtonSuccess", UIKit.H_BTN, btn_w, 36)
	yes.pressed.connect(_watch_revive.bind(reason, yes))
	row.add_child(no)
	row.add_child(yes)
	v.add_child(row)
	return layer

func _watch_revive(reason: String, btn: Button) -> void:
	btn.disabled = true
	Ads.show_rewarded("revive")
	var res: Array = await Ads.rewarded_finished
	var earned := bool(res[1]) if res.size() > 1 else false
	_close_revive()
	if earned:
		shift.revive(reason, float(Ads.revive_seconds()))
		_freeze(false)
		AudioManager.play_sfx("go")
		Events.toast.emit(Loc.t("ads.revived"), "success")
	else:
		shift.finish(reason, true)

func _decline_revive() -> void:
	_close_revive()
	shift.finish(_revive_reason, true)

func _close_revive() -> void:
	_reviving = false
	if _revive_layer != null:
		_revive_layer.queue_free()
		_revive_layer = null

# ------------------------------------------------------------------ resultado
func _on_shift_ended(result: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	player.controls_enabled = false
	hud.touch.set_enabled(false)
	_capture_mouse(false)
	hud.set_gameplay_visible(false)
	SaveManager.save_now()
	AudioManager.play_sfx("win" if (bool(result.get("won", false)) or str(result.get("mode", "")) == Const.MODE_FREE) else "lose")
	var lost := str(result.get("mode", "")) == Const.MODE_CAMPAIGN and not bool(result.get("won", false))
	if lost:
		Ads.register_loss()
	await get_tree().create_timer(0.5, false).timeout
	get_tree().paused = true
	_result = ResultScreen.new(result)
	hud.add_overlay(_result)
	_result.next_requested.connect(func() -> void:
		SceneManager.change_scene(Const.SCENE_GAME, {"mode": Const.MODE_CAMPAIGN, "level_id": int(result.get("next_level", 1))}))
	# al perder, a veces sale un intersticial al elegir reintentar o volver al menú (pausa natural del juego)
	_result.retry_requested.connect(_after_loss_ad.bind(lost, _restart))
	_result.menu_requested.connect(_after_loss_ad.bind(lost, _go_menu))
	_result.double_requested.connect(_on_double_requested)

## Ejecuta la acción; antes, si el turno se perdió y toca, muestra un anuncio intersticial.
func _after_loss_ad(lost: bool, action: Callable) -> void:
	if lost and Ads.interstitial_due() and Ads.show_interstitial():
		await Ads.interstitial_finished
	action.call()

## «x2 monedas» de la pantalla de resultados: anuncio recompensado y, si se ve entero, se suman las monedas.
func _on_double_requested(amount: int) -> void:
	Ads.show_rewarded("double")
	var res: Array = await Ads.rewarded_finished
	var earned := bool(res[1]) if res.size() > 1 else false
	if _result != null:
		_result.set_double_done(earned)
	if earned:
		EconomyManager.earn(amount, "ad_double")
		AudioManager.play_sfx("coin")
		Events.toast.emit(Loc.t("ads.doubled", [amount]), "success")
		SaveManager.request_save()

## Carga por adelantado los cuerpos y animaciones de los clientes para que el primer cliente no provoque un tirón.
func _warm_up() -> void:
	for i in CharacterLib.BODIES.size():
		var made := CharacterLib.spawn(i, Color.WHITE)
		if made.has("root"):
			(made["root"] as Node).free()
