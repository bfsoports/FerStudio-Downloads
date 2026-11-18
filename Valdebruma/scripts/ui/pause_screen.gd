extends UiScreen
## PauseScreen — menú de partida. El mundo no se detiene (es multijugador): solo se bloquea
## la entrada del jugador mientras está abierto.

func setup() -> void:
	frame(tr("PAUSE_TITLE"), 0.5, 560.0, "menu")
	var info := UiKit.panel("flat", 12.0)
	var v := UiKit.vbox(4)
	v.add_child(UiKit.label(Session.server_name, 20, UiKit.C_TEXT, UiKit.f_semi))
	var diff: Dictionary = (GameData.progression.get("difficulty", {}) as Dictionary).get(Session.difficulty, {})
	v.add_child(UiKit.label(tr("PAUSE_INFO") % [GameData.text(diff.get("name", Session.difficulty)), Session.roster.size(), Protocol.MAX_PLAYERS], 16, UiKit.C_DIM))
	if Net.is_server:
		var ips: PackedStringArray = []
		for a in IP.get_local_addresses():
			if a.begins_with("192.168.") or a.begins_with("10."):
				ips.append(a)
		v.add_child(UiKit.wrap_label(tr("PAUSE_HOSTING") % [", ".join(ips) if not ips.is_empty() else "—", Net.port], 15, UiKit.C_ACCENT))
	info.add_child(v)
	body.add_child(info)
	for def: Array in [["PAUSE_RESUME", "play", "", "primary"], ["MENU_SETTINGS", "settings", "settings", "normal"], ["MENU_PROFILE", "profile", "profile", "normal"],
			["PAUSE_PLAYERS", "group", "social", "normal"], ["MENU_LEGAL", "info", "legal", "normal"]]:
		var screen := String(def[2])
		var b := UiKit.button(tr(String(def[0])), String(def[1]), func() -> void:
			if screen == "":
				Ui.close_top()
			else:
				Ui.open(screen), String(def[3]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(b)
	var leave := UiKit.button(tr("PAUSE_LEAVE"), "exit", func() -> void:
		Ui.confirm(tr("PAUSE_LEAVE"), tr("PAUSE_LEAVE_HOST") if Net.is_server else tr("PAUSE_LEAVE_TEXT"), tr("PAUSE_LEAVE"), func() -> void: Ui.leave_to_menu(), true), "danger")
	leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(leave)
