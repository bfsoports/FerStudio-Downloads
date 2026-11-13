extends CanvasLayer
## Ui — gestor de la interfaz (autoload).
##
## Responsabilidad: tema visual, pila de pantallas, HUD, avisos emergentes, diálogos, pantalla
## de carga y el flujo completo de la partida: menú → crear/unirse → carga del mundo → juego →
## pérdida de conexión y reconexión → vuelta al menú. Traduce los avisos del servidor a texto.
## Datos: stack (pantallas abiertas), in_world. Señales: screen_changed(nombre).
## Autoridad online: ninguna; solo llama a Net/Session y muestra lo que el servidor confirma.

signal screen_changed(top: String)

const SCREENS := {
	"main": "res://scripts/ui/main_menu.gd", "play": "res://scripts/ui/play_screen.gd", "profile": "res://scripts/ui/profile_screen.gd",
	"settings": "res://scripts/ui/settings_screen.gd", "legal": "res://scripts/ui/legal_screen.gd", "inventory": "res://scripts/ui/inventory_screen.gd",
	"craft": "res://scripts/ui/craft_screen.gd", "build": "res://scripts/ui/build_screen.gd", "map": "res://scripts/ui/map_screen.gd",
	"social": "res://scripts/ui/social_screen.gd", "journal": "res://scripts/ui/journal_screen.gd", "pause": "res://scripts/ui/pause_screen.gd",
	"doc": "res://scripts/ui/doc_screen.gd",
}
const MENU_SCENE := "res://scenes/menus/menu.tscn"
const WORLD_SCENE := "res://scenes/world/world.tscn"
const RECONNECT_TRIES := 5

var root: Control
var hud: Control = null
var stack: Array[UiScreen] = []
var in_world := false
var build_mode: Node = null
var _hud_layer: Control
var _screen_layer: Control
var _overlay_layer: Control
var _toasts: VBoxContainer
var _loading: Control = null
var _loading_label: Label
var _loading_bar: ProgressBar
var _loading_tip: Label
var _dialog: Control = null
var _down: Control = null
var _target: Dictionary = {}       # servidor al que nos unimos (para reconectar)
var _reconnect_left := 0
var _entering := false
var _quitting := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "Root"
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme(Config.b("access", "high_contrast"))
	add_child(root)
	_hud_layer = _layer("Hud")
	_screen_layer = _layer("Screens")
	_overlay_layer = _layer("Overlay")
	_toasts = UiKit.vbox(8)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.position.y = 84
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_overlay_layer.add_child(_toasts)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	Controls.pressed.connect(_on_pressed)
	Config.changed.connect(_on_config)
	Session.welcomed.connect(_on_welcomed)
	Session.rejected.connect(_on_rejected)
	Session.notified.connect(_on_notified)
	Session.group_invite.connect(_on_group_invite)
	Session.trade_offer.connect(_on_trade_offer)
	Session.went_down.connect(_on_down)
	Session.respawned.connect(func(_p: Vector3) -> void: _close_down())
	Session.document_opened.connect(func(id: String, _first: bool) -> void: open("doc", {"id": id}))
	Net.failed.connect(_on_net_failed)
	Net.dropped.connect(_on_net_dropped)

func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	UiKit.full_rect(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c

func _on_config(section: String, key: String) -> void:
	if section == "access" and key == "high_contrast":
		root.theme = UiKit.theme(Config.b("access", "high_contrast"))

## Márgenes de zona segura en coordenadas de la interfaz: Rect2(izq, arriba, der, abajo).
func safe_margins() -> Rect2:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or not OS.has_feature("mobile"):
		return Rect2(0, 0, 0, 0)
	var vp := root.get_viewport_rect().size
	var k := vp.x / float(win.x)
	var l := maxf(0.0, float(safe.position.x)) * k
	var t := maxf(0.0, float(safe.position.y)) * k
	var r := maxf(0.0, float(win.x - safe.end.x)) * k
	var b := maxf(0.0, float(win.y - safe.end.y)) * k
	return Rect2(minf(l, 80.0), minf(t, 60.0), minf(r, 80.0), minf(b, 60.0))

# ---- pila de pantallas ----------------------------------------------------------------------------
func open(screen: String, args := {}) -> UiScreen:
	if not SCREENS.has(screen):
		push_warning("Pantalla desconocida: " + screen)
		return null
	if is_open(screen) and screen != "doc":
		return null
	var script: GDScript = load(SCREENS[screen])
	var s: UiScreen = script.new()
	s.screen_name = screen
	s.name = screen
	s.args = args
	_screen_layer.add_child(s)
	stack.append(s)
	s.setup()
	s.refresh()
	_after_stack_change()
	return s

## Abre la pantalla si no lo está; si lo está, cierra todo (comportamiento de botón del HUD).
func toggle(screen: String, args := {}) -> void:
	if is_open(screen):
		close_all()
	else:
		close_all()
		open(screen, args)

func is_open(screen: String) -> bool:
	for s in stack:
		if s.screen_name == screen:
			return true
	return false

func top() -> String:
	return stack[stack.size() - 1].screen_name if not stack.is_empty() else ""

func close_top() -> void:
	if stack.is_empty():
		return
	var s: UiScreen = stack.pop_back()
	s.on_close()
	s.queue_free()
	if not stack.is_empty():
		stack[stack.size() - 1].refresh()
	_after_stack_change()

func close_all() -> void:
	while not stack.is_empty():
		var s: UiScreen = stack.pop_back()
		s.on_close()
		s.queue_free()
	_after_stack_change()

func close(screen: String) -> void:
	for i in range(stack.size() - 1, -1, -1):
		if stack[i].screen_name == screen:
			stack[i].on_close()
			stack[i].queue_free()
			stack.remove_at(i)
	_after_stack_change()

func _after_stack_change() -> void:
	var busy := not stack.is_empty() or _dialog != null or _down != null
	Controls.blocked = busy and in_world
	if in_world:
		Controls.capture_mouse(not busy and _loading == null)
		if hud != null:
			hud.call("set_menu_open", not stack.is_empty())
	screen_changed.emit(top())

func refresh_screens() -> void:
	for s in stack:
		s.refresh()

# ---- avisos emergentes --------------------------------------------------------------------------------
## kind: "info", "good", "bad", "item".
func toast(text: String, kind := "info", icon_name := "", item_id := "") -> void:
	if text == "":
		return
	while _toasts.get_child_count() >= 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var p := UiKit.panel("dark", 10.0)
	var col := UiKit.C_TEXT
	if kind == "good":
		col = UiKit.C_GOOD
	elif kind == "bad":
		col = UiKit.C_BAD
	var h := UiKit.hbox(10)
	if item_id != "" and UiKit.item_icon(item_id) != null:
		var tr_ := TextureRect.new()
		tr_.texture = UiKit.item_icon(item_id)
		tr_.custom_minimum_size = Vector2(34, 34)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr_)
	elif icon_name != "":
		h.add_child(UiKit.icon_rect(icon_name, 24, col))
	h.add_child(UiKit.label(text, 18, col, UiKit.f_medium))
	p.add_child(h)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	_toasts.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

# ---- diálogos -------------------------------------------------------------------------------------------
## Diálogo modal. buttons: [[texto, tipo, Callable], …]. Devuelve el nodo (para cerrarlo antes de tiempo).
func dialog(title_text: String, text: String, buttons: Array, icon_name := "") -> Control:
	close_dialog()
	var d := Control.new()
	UiKit.full_rect(d)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	UiKit.full_rect(dim)
	d.add_child(dim)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	d.add_child(center)
	var p := UiKit.panel("panel", 22.0)
	p.custom_minimum_size = Vector2(520, 0)
	center.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	var h := UiKit.hbox(12)
	if icon_name != "":
		h.add_child(UiKit.icon_rect(icon_name, 30, UiKit.C_ACCENT))
	h.add_child(UiKit.title(title_text, 28))
	v.add_child(h)
	if text != "":
		var l := UiKit.wrap_label(text, 19, UiKit.C_TEXT)
		l.custom_minimum_size = Vector2(480, 0)
		v.add_child(l)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	for b: Array in buttons:
		var cb: Callable = b[2] if b.size() > 2 else Callable()
		var btn := UiKit.button(String(b[0]), "", func() -> void:
			close_dialog()
			if cb.is_valid():
				cb.call(), String(b[1]) if b.size() > 1 else "normal")
		btn.custom_minimum_size.x = 150
		row.add_child(btn)
	_overlay_layer.add_child(d)
	_dialog = d
	_after_stack_change()
	return d

func confirm(title_text: String, text: String, yes_text: String, on_yes: Callable, danger := false) -> void:
	dialog(title_text, text, [[tr("BTN_CANCEL"), "normal"], [yes_text, "danger" if danger else "primary", on_yes]], "help")

func message(title_text: String, text: String, icon_name := "info") -> void:
	dialog(title_text, text, [[tr("BTN_OK"), "primary"]], icon_name)

func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
		_after_stack_change()

# ---- pantalla de carga ---------------------------------------------------------------------------------
func show_loading(text: String, progress := -1.0) -> void:
	if _loading == null:
		_loading = Control.new()
		UiKit.full_rect(_loading)
		_loading.mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = UiKit.C_BG
		UiKit.full_rect(bg)
		_loading.add_child(bg)
		var center := CenterContainer.new()
		UiKit.full_rect(center)
		_loading.add_child(center)
		var v := UiKit.vbox(18)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(v)
		var logo := TextureRect.new()
		logo.texture = load("res://assets/ui/logo.png")
		logo.custom_minimum_size = Vector2(700, 210)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(logo)
		_loading_label = UiKit.label("", 22, UiKit.C_TEXT, UiKit.f_medium)
		_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_loading_label)
		_loading_bar = UiKit.bar(UiKit.C_ACCENT, 8.0)
		_loading_bar.custom_minimum_size = Vector2(520, 8)
		_loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(_loading_bar)
		_loading_tip = UiKit.label("", 17, UiKit.C_DIM)
		_loading_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_loading_tip.custom_minimum_size = Vector2(700, 0)
		v.add_child(_loading_tip)
		var cancel := UiKit.button(tr("BTN_CANCEL"), "close", func() -> void: leave_to_menu(), "ghost")
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cancel)
		_overlay_layer.add_child(_loading)
		_overlay_layer.move_child(_loading, 0)
		_loading_tip.text = tr("TIP_%d" % (1 + randi() % 8))
	_loading_label.text = text
	_loading_bar.visible = progress >= 0.0
	_loading_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	_after_stack_change()

func hide_loading() -> void:
	if _loading != null:
		_loading.queue_free()
		_loading = null
		_after_stack_change()

# ---- flujo de partida -------------------------------------------------------------------------------------
func goto_menu(notice := "") -> void:
	in_world = false
	_entering = false
	_reconnect_left = 0
	_drop_hud()
	close_all()
	close_dialog()
	_close_down()
	hide_loading()
	Controls.blocked = false
	Controls.capture_mouse(false)
	get_tree().change_scene_to_file(MENU_SCENE)
	open("main")
	AudioDirector.play_music("music_menu")
	if notice != "":
		message(tr("TITLE_NOTICE"), notice, "warn")

## Crea una partida en este dispositivo (servidor en el mismo proceso; otros se unen por IP).
func start_host(world_name: String, port: int, options: Dictionary) -> void:
	show_loading(tr("LOAD_STARTING"))
	Net.leave()
	Session.reset()
	await get_tree().process_frame
	_target = {}
	var err := Net.host(port, false, world_name, options)
	if err != OK:
		hide_loading()
		message(tr("TITLE_ERROR"), tr("ERR_HOST_PORT") % port, "warn")
		return
	_entering = true
	Net.send(Protocol.C.HELLO, {"v": Protocol.VERSION, "account": Profile.account, "token": Profile.token, "name": Profile.player_name, "cos": Profile.cosmetics})

func start_join(host: String, port: int) -> void:
	show_loading(tr("LOAD_CONNECTING") % host)
	Session.reset()
	_target = {"host": host, "port": port}
	_entering = true
	Net.join(host, port)

func leave_to_menu() -> void:
	_reconnect_left = 0
	_entering = false
	Net.leave()
	Session.reset()
	goto_menu()

func _on_welcomed() -> void:
	_entering = false
	_reconnect_left = 0
	close_all()
	close_dialog()
	_close_down()
	_drop_hud()
	in_world = false
	show_loading(tr("LOAD_WORLD"), 0.0)
	if not _target.is_empty():
		Profile.remember_server(String(_target.host), int(_target.port), Session.server_name)
	get_tree().change_scene_to_file(WORLD_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	var wr: WorldRoot = WorldRoot.current
	if wr == null:
		goto_menu(tr("ERR_WORLD_LOAD"))
		return
	wr.ui_requested.connect(func(screen: String) -> void: toggle(screen))
	wr.streamer.progress.connect(func(done: int, total: int) -> void:
		if _loading != null and total > 0:
			show_loading(tr("LOAD_WORLD"), float(done) / float(total)))
	if not wr.is_loaded:
		await wr.loaded
	if WorldRoot.current != wr:
		return
	hide_loading()
	AudioDirector.play_music("")
	in_world = true
	_make_hud()
	_after_stack_change()
	if Session.first_time and not Profile.tutorial_done and Config.b("game", "hints"):
		hud.call("start_tutorial")
	if bool(Session.stats.get("down", false)):
		_on_down(0.0)

func _make_hud() -> void:
	_drop_hud()
	var script: GDScript = load("res://scripts/ui/hud.gd")
	hud = script.new()
	hud.name = "HUD"
	_hud_layer.add_child(hud)
	var bm: GDScript = load("res://scripts/gameplay/build_mode.gd")
	build_mode = bm.new()
	build_mode.name = "BuildMode"
	WorldRoot.current.add_child(build_mode)

func _drop_hud() -> void:
	if hud != null:
		hud.queue_free()
		hud = null
	build_mode = null

func _on_rejected(code: String) -> void:
	_entering = false
	_reconnect_left = 0
	Net.leave()
	hide_loading()
	if in_world or WorldRoot.current != null:
		goto_menu(tr("REJECT_" + code.to_upper()))
	else:
		message(tr("TITLE_REJECTED"), tr("REJECT_" + code.to_upper()), "warn")

func _on_net_failed(reason: String) -> void:
	if _reconnect_left > 0:
		_retry_reconnect()
		return
	if not _entering:
		return
	_entering = false
	hide_loading()
	message(tr("TITLE_NO_CONNECTION"), tr("ERR_CONNECT_" + reason.to_upper()), "wifi_off")

func _on_net_dropped(_reason: String) -> void:
	if _quitting:
		return
	if _target.is_empty() or not in_world:
		goto_menu(tr("ERR_DROPPED"))
		return
	# estábamos dentro como cliente: se intenta volver sin perder la sesión del servidor
	in_world = false
	Controls.blocked = true
	Controls.capture_mouse(false)
	close_all()
	_reconnect_left = RECONNECT_TRIES
	_retry_reconnect()

func _retry_reconnect() -> void:
	if _reconnect_left <= 0 or _target.is_empty():
		_reconnect_left = 0
		goto_menu(tr("ERR_RECONNECT"))
		return
	var n := RECONNECT_TRIES - _reconnect_left + 1
	_reconnect_left -= 1
	show_loading(tr("LOAD_RECONNECTING") % [n, RECONNECT_TRIES])
	await get_tree().create_timer(1.5).timeout
	if _loading == null:        # el jugador canceló
		return
	_entering = true
	Net.join(String(_target.host), int(_target.port))

# ---- avisos del servidor -------------------------------------------------------------------------------
func _on_notified(code: String, p: Dictionary) -> void:
	match code:
		"board":
			if in_world and not is_open("journal"):
				close_all()
				open("journal", {"tab": "board"})
			else:
				refresh_screens()
		"place":
			if hud != null:
				hud.call("banner", tr("BANNER_SECRET") if bool(p.get("secret", false)) else tr("BANNER_PLACE"), String(p.get("name", "")), "mark")
			AudioDirector.play_ui("discover")
		"level_up":
			if hud != null:
				hud.call("banner", tr("BANNER_LEVEL"), tr("BANNER_LEVEL_N") % int(p.get("level", 1)), "star")
			AudioDirector.play_ui("level_up")
		"challenge_done":
			var def: Dictionary = (GameData.progression.get(String(p.get("group", "challenges")), {}) as Dictionary).get(String(p.get("id", "")), {})
			toast(tr("N_CHALLENGE_DONE") % GameData.text(def.get("name", "")), "good", "star")
			AudioDirector.play_ui("discover")
		"contract_done", "contract_ready":
			var c: Dictionary = (GameData.progression.get("contracts", {}) as Dictionary).get(String(p.get("id", "")), {})
			toast(tr("N_" + code.to_upper()) % GameData.text(c.get("name", "")), "good", "contract")
		"got", "crafted":
			toast("+%d  %s" % [int(p.get("n", 1)), GameData.item_name(String(p.get("item", "")))], "info", "", String(p.get("item", "")))
			AudioDirector.play_ui("pickup")
		"used":
			pass
		"inv_full_dropped":
			toast(tr("N_INV_FULL_DROPPED") % GameData.item_name(String(p.get("item", ""))), "bad", "inventory")
		"need", "locked":
			toast(tr("N_" + code.to_upper()) % GameData.item_name(String(p.get("item", ""))), "bad", "lock" if code == "locked" else "warn")
		"unlocked":
			toast(tr("N_UNLOCKED"), "good", "unlock")
			AudioDirector.play_ui("unlock")
		"tool_broken":
			toast(tr("N_TOOL_BROKEN") % GameData.item_name(String(p.get("item", ""))), "bad", "tool")
		"refilled":
			toast(tr("N_REFILLED") % GameData.item_name(String(p.get("item", ""))), "info", "light")
		"craft_fail", "build_fail":
			toast(tr("WHY_" + String(p.get("why", "unknown")).to_upper()), "bad", "warn")
		"built", "dismantled":
			var sd: Dictionary = GameData.structures.get(String(p.get("type", "")), {})
			toast(tr("N_" + code.to_upper()) % GameData.text(sd.get("name", "")), "good", "build")
			AudioDirector.play_ui("build_done")
		"effect":
			var e: Dictionary = GameData.effects.get(String(p.get("id", "")), {})
			if not e.is_empty():
				toast(GameData.text(e.get("name", "")) + " — " + GameData.text(e.get("desc", "")), "bad" if bool(e.get("bad", false)) else "good", String(e.get("icon", "info")))
		"creature_hit":
			var cd: Dictionary = GameData.creatures.get(String(p.get("type", "")), {})
			toast(tr("N_CREATURE_HIT") % GameData.text(cd.get("name", "")), "bad", "warn")
		"invite_sent", "offer_sent", "offer_done":
			toast(tr("N_" + code.to_upper()) % String(p.get("name", "")), "info", "group")
		"border":
			toast(tr("N_BORDER"), "info", "compass")
		_:
			var key := "N_" + code.to_upper()
			var text := tr(key)
			if text != key:
				var bad := code in ["busy", "inv_full", "no_room", "no_permission", "too_far", "door_blocked", "gone", "depleted", "not_empty", "contract_missing",
					"contract_limit", "group_full", "already_grouped", "offer_expired", "offer_failed", "need_board", "light_spent", "filter_spent", "container_closed"]
				toast(text, "bad" if bad else "info", "warn" if bad else "info")

func _on_group_invite(_gid: int, from: String) -> void:
	dialog(tr("TITLE_GROUP_INVITE"), tr("TEXT_GROUP_INVITE") % from, [
		[tr("BTN_DECLINE"), "normal", func() -> void: Net.send(Protocol.C.GROUP, ["decline"])],
		[tr("BTN_ACCEPT"), "primary", func() -> void: Net.send(Protocol.C.GROUP, ["accept"])]], "group")

func _on_trade_offer(offer: Dictionary) -> void:
	if String(offer.get("op", "")) != "offer":
		return
	var oid := int(offer.get("id", 0))
	dialog(tr("TITLE_TRADE"), tr("TEXT_TRADE") % [String(offer.get("from", "")), int(offer.get("n", 1)), GameData.item_name(String(offer.get("item", "")))], [
		[tr("BTN_DECLINE"), "normal", func() -> void: Net.send(Protocol.C.TRADE, ["decline", oid])],
		[tr("BTN_ACCEPT"), "primary", func() -> void: Net.send(Protocol.C.TRADE, ["accept", oid])]], "trade")

# ---- colapso y reaparición ----------------------------------------------------------------------------
func _on_down(wait: float) -> void:
	close_all()
	close_dialog()
	_close_down()
	_down = Control.new()
	UiKit.full_rect(_down)
	_down.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.0)
	UiKit.full_rect(dim)
	_down.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.78, 1.6)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	_down.add_child(center)
	var v := UiKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var t := UiKit.title(tr("DOWN_TITLE"), 46, UiKit.C_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UiKit.wrap_label(tr("DOWN_TEXT"), 19, UiKit.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	var btn := UiKit.button(tr("DOWN_RESPAWN"), "refresh", func() -> void: Net.send(Protocol.C.RESPAWN), "primary")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size.x = 280
	btn.disabled = wait > 0.0
	v.add_child(btn)
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if is_instance_valid(btn):
				btn.disabled = false)
	_overlay_layer.add_child(_down)
	_overlay_layer.move_child(_down, 0)
	_after_stack_change()

func _close_down() -> void:
	if _down != null:
		_down.queue_free()
		_down = null
		_after_stack_change()

# ---- entradas globales --------------------------------------------------------------------------------
func _on_pressed(action: String) -> void:
	if _loading != null or _dialog != null:
		return
	if not in_world:
		if action == "pause" and stack.size() > 1:
			back()
		return
	if _down != null:
		return
	if build_mode != null and bool(build_mode.get("active")):
		if action in ["pause", "build"]:
			build_mode.call("cancel")
		elif action == "interact":
			build_mode.call("confirm")
		elif action == "rotate":
			build_mode.call("rotate_step")
		return
	match action:
		"inventory": toggle("inventory")
		"map": toggle("map")
		"craft": toggle("craft")
		"build": toggle("build")
		"journal": toggle("journal")
		"group": toggle("social")
		"pause":
			if stack.is_empty():
				open("pause")
			else:
				back()
		"chat":
			if hud != null and stack.is_empty():
				hud.call("focus_chat")
		"quick1", "quick2", "quick3", "quick4":
			use_quick(int(action.right(1)) - 1)

## Usa (o equipa) el objeto asignado a un acceso rápido.
func use_quick(index: int) -> void:
	if index < 0 or index >= Session.quick.size():
		return
	var id := String(Session.quick[index])
	if id == "":
		return
	for i in Session.inv.size():
		var st: Variant = Session.inv.get_slot(i)
		if st != null and String(st.id) == id:
			var def := GameData.item(id)
			if def.has("use"):
				Session.request_use(i)
			elif def.has("equip"):
				Session.request_equip(i)
			return
	if Session.equipped("mano") == id:
		Session.request_unequip("mano")
		return
	toast(tr("N_QUICK_MISSING") % GameData.item_name(id), "bad", "inventory")

## «Atrás» del sistema (Android) o Escape.
func back() -> void:
	if _dialog != null:
		close_dialog()
		return
	if _loading != null:
		return
	if not stack.is_empty():
		if stack[stack.size() - 1].on_back():
			return
		if not in_world and stack.size() == 1:
			confirm_quit()
			return
		close_top()
		return
	if in_world and _down == null:
		open("pause")

func confirm_quit() -> void:
	confirm(tr("TITLE_QUIT"), tr("TEXT_QUIT"), tr("BTN_QUIT"), func() -> void: quit_game())

func quit_game() -> void:
	_quitting = true
	Net.leave()
	Config.save()
	Profile.save()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
