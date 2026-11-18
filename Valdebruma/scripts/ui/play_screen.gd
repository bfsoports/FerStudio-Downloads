extends UiScreen
## PlayScreen — crear una partida en este dispositivo o unirse a un servidor por dirección.
##
## «Crear» arranca el servidor autoritativo en el mismo proceso (otros jugadores de la red se
## unen con la IP mostrada). «Unirse» conecta con un servidor dedicado o con un anfitrión y
## recuerda los últimos servidores. No existe servidor público oficial: se indica con claridad.

var _tab := "host"
var _content: VBoxContainer
var _tabs: Dictionary = {}
var _world: LineEdit
var _port: LineEdit
var _difficulty := "normal"
var _addr: LineEdit
var _jport: LineEdit

func setup() -> void:
	frame(tr("PLAY_TITLE"), 0.55, 980.0, "play")
	var h := UiKit.hbox(8)
	body.add_child(h)
	for def: Array in [["host", "PLAY_TAB_HOST", "host"], ["join", "PLAY_TAB_JOIN", "join"]]:
		var id := String(def[0])
		var b := UiKit.button(tr(String(def[1])), String(def[2]), func() -> void: _show(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		_tabs[id] = b
	_content = UiKit.vbox(12)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	_show("join" if String(args.get("tab", "")) == "join" else "host")

func _show(tab: String) -> void:
	_tab = tab
	for id: String in _tabs.keys():
		var b: Button = _tabs[id]
		b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if id == tab else Color(UiKit.C_PANEL2, 0.96), 10, UiKit.C_ACCENT if id == tab else UiKit.C_LINE, 1, 12))
	UiKit.clear(_content)
	if tab == "host":
		_build_host()
	else:
		_build_join()

func _worlds() -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(ServerPersistence.base_dir)
	if d != null:
		for n in d.get_directories():
			if FileAccess.file_exists("%s/%s/world.json" % [ServerPersistence.base_dir, n]):
				out.append(n)
	return out

func _build_host() -> void:
	_content.add_child(UiKit.wrap_label(tr("PLAY_HOST_INFO"), 17, UiKit.C_DIM))
	var worlds := _worlds()
	_world = UiKit.field(tr("PLAY_WORLD_HINT"), worlds[0] if not worlds.is_empty() else "valle", 20)
	_world.custom_minimum_size.x = 300
	_content.add_child(UiKit.row(tr("PLAY_WORLD"), _world, tr("PLAY_WORLD_SAVED") % ", ".join(worlds) if not worlds.is_empty() else tr("PLAY_WORLD_NEW")))
	var dh := UiKit.hbox(8)
	var dbtn: Dictionary = {}
	for id: String in ["tranquilo", "normal", "exigente"]:
		var did := id
		var b := UiKit.button(GameData.text((GameData.progression.difficulty as Dictionary)[id].name), "", func() -> void:
			_difficulty = did
			for k: String in dbtn.keys():
				(dbtn[k] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if k == did else Color(UiKit.C_PANEL2, 0.96), 10, UiKit.C_ACCENT if k == did else UiKit.C_LINE, 1, 12)))
		b.custom_minimum_size.x = 130
		dbtn[id] = b
		dh.add_child(b)
	(dbtn[_difficulty] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22), 10, UiKit.C_ACCENT, 1, 12))
	_content.add_child(UiKit.row(tr("PLAY_DIFFICULTY"), dh, tr("PLAY_DIFFICULTY_HINT")))
	_port = UiKit.field("", str(Protocol.DEFAULT_PORT), 5)
	_port.custom_minimum_size.x = 130
	_port.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_content.add_child(UiKit.row(tr("PLAY_PORT"), _port, tr("PLAY_PORT_HINT")))
	var ips: PackedStringArray = []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			ips.append(a)
	var p := UiKit.panel("flat", 12.0)
	var ph := UiKit.hbox(10)
	ph.add_child(UiKit.icon_rect("signal", 22, UiKit.C_ACCENT))
	ph.add_child(UiKit.wrap_label(tr("PLAY_LAN") % ", ".join(ips) if not ips.is_empty() else tr("PLAY_LAN_NONE"), 17))
	p.add_child(ph)
	_content.add_child(p)
	_content.add_child(UiKit.spacer(true))
	var go := UiKit.button(tr("PLAY_START"), "play", _host, "primary")
	go.custom_minimum_size = Vector2(300, 62)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(go)

func _host() -> void:
	var world_name := _world.text.strip_edges().validate_filename().replace(" ", "_")
	if world_name == "":
		world_name = "valle"
	var port := clampi(int(_port.text), 1024, 65535)
	Ui.start_host(world_name, port, {"difficulty": _difficulty, "name": tr("PLAY_HOST_NAME") % Profile.player_name})

func _build_join() -> void:
	_content.add_child(UiKit.wrap_label(tr("PLAY_JOIN_INFO"), 17, UiKit.C_DIM))
	var h := UiKit.hbox(10)
	_addr = UiKit.field(tr("PLAY_ADDR_HINT"), "", 64)
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	h.add_child(_addr)
	_jport = UiKit.field("", str(Protocol.DEFAULT_PORT), 5)
	_jport.custom_minimum_size.x = 120
	_jport.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	h.add_child(_jport)
	h.add_child(UiKit.button(tr("PLAY_CONNECT"), "join", func() -> void: _join(_addr.text, int(_jport.text)), "primary"))
	_content.add_child(h)
	_content.add_child(UiKit.caption(tr("PLAY_RECENT")))
	var list := UiKit.vbox(8)
	if Profile.servers.is_empty():
		list.add_child(UiKit.wrap_label(tr("PLAY_RECENT_NONE"), 17, UiKit.C_DIM))
	for i in Profile.servers.size():
		var s: Dictionary = Profile.servers[i]
		var idx := i
		var p := UiKit.panel("flat", 10.0)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon_rect("host", 24, UiKit.C_ACCENT))
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(String(s.get("name", "?")), 19, UiKit.C_TEXT, UiKit.f_semi))
		v.add_child(UiKit.label("%s : %d" % [String(s.get("host", "")), int(s.get("port", 0))], 15, UiKit.C_DIM))
		row.add_child(v)
		row.add_child(UiKit.button(tr("PLAY_CONNECT"), "", func() -> void: _join(String(s.host), int(s.port))))
		row.add_child(UiKit.icon_button("dismantle", func() -> void:
			Profile.forget_server(idx)
			_show("join"), UiKit.TOUCH, "ghost"))
		p.add_child(row)
		list.add_child(p)
	_content.add_child(UiKit.scroll(list))

func _join(host: String, port: int) -> void:
	var h := host.strip_edges()
	if h == "" or h.length() > 64 or h.contains(" "):
		Ui.toast(tr("PLAY_ADDR_BAD"), "bad", "warn")
		return
	Ui.start_join(h, clampi(port, 1, 65535))
