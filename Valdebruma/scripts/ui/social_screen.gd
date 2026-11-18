extends UiScreen
## SocialScreen — jugadores conectados, grupo cooperativo, gestos e intercambio.
##
## Lista a los jugadores reales del servidor con acciones: invitar al grupo, ofrecer un
## objeto (intercambio validado por el servidor), silenciar su chat en este dispositivo y
## denunciar (queda registrado en el servidor con sus últimos mensajes). También permite
## salir del grupo, expulsar si eres quien lo lidera, hacer gestos y dejar una señal.

var _tab := "players"
var _tabs: Dictionary = {}
var _content: VBoxContainer

func setup() -> void:
	frame(tr("SOCIAL_TITLE"), 0.5, 1040.0, "group")
	var h := UiKit.hbox(6)
	body.add_child(h)
	for id: String in ["players", "group", "emotes"]:
		var tid := id
		var b := UiKit.button(tr("SOCIAL_TAB_" + id.to_upper()), "", func() -> void:
			_tab = tid
			refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		_tabs[id] = b
	_content = UiKit.vbox(8)
	body.add_child(UiKit.scroll(_content))
	Session.roster_changed.connect(refresh)
	Session.group_changed.connect(refresh)

func refresh() -> void:
	for id: String in _tabs.keys():
		(_tabs[id] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if id == _tab else Color(UiKit.C_PANEL2, 0.96), 10,
			UiKit.C_ACCENT if id == _tab else UiKit.C_LINE, 1, 12))
	UiKit.clear(_content)
	match _tab:
		"players": _players()
		"group": _group()
		"emotes": _emotes()

func _players() -> void:
	var my_group := int(Session.group.get("id", 0))
	var ids: Array = Session.roster.keys()
	ids.sort()
	if ids.size() <= 1:
		_content.add_child(UiKit.wrap_label(tr("SOCIAL_ALONE"), 17, UiKit.C_DIM))
	for id: int in ids:
		var r: Dictionary = Session.roster[id]
		var me := id == Session.my_id
		var p := UiKit.panel("flat", 10.0)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon_rect("profile", 26, UiKit.C_ACCENT if me else UiKit.C_TEXT))
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pname := String(r.get("name", "?"))
		v.add_child(UiKit.label(pname + ("  (" + tr("SOCIAL_YOU") + ")" if me else ""), 19, UiKit.C_TEXT, UiKit.f_semi))
		var same := my_group != 0 and int(r.get("group", 0)) == my_group
		v.add_child(UiKit.label(tr("SOCIAL_LEVEL") % int(r.get("level", 1)) + ("  ·  " + tr("SOCIAL_IN_GROUP") if same and not me else ""), 15, UiKit.C_GOOD if same else UiKit.C_DIM))
		row.add_child(v)
		if not me:
			if not same and int(r.get("group", 0)) == 0:
				row.add_child(UiKit.button(tr("SOCIAL_INVITE"), "plus", func() -> void: Net.send(Protocol.C.GROUP, ["invite", id])))
			row.add_child(UiKit.icon_button("trade", func() -> void: _pick_offer(id, pname), UiKit.TOUCH, "normal", tr("SOCIAL_OFFER")))
			var muted := Profile.muted.has(pname)
			row.add_child(UiKit.icon_button("mute", func() -> void:
				if Profile.muted.has(pname):
					Profile.muted.erase(pname)
				else:
					Profile.muted[pname] = true
				Profile.save()
				refresh(), UiKit.TOUCH, "danger" if muted else "normal", tr("SOCIAL_MUTE")))
			row.add_child(UiKit.icon_button("report", func() -> void: _report(id, pname), UiKit.TOUCH, "normal", tr("SOCIAL_REPORT")))
		p.add_child(row)
		_content.add_child(p)

func _pick_offer(peer: int, pname: String) -> void:
	UiKit.clear(_content)
	_content.add_child(UiKit.wrap_label(tr("SOCIAL_OFFER_PICK") % pname, 17, UiKit.C_DIM))
	var g := UiKit.grid(8, 6)
	var any := false
	for i in Session.inv.size():
		var st: Variant = Session.inv.get_slot(i)
		if st == null:
			continue
		any = true
		var slot := i
		var n := int(st.n)
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = GameData.item_name(String(st.id))
		var ic := TextureRect.new()
		ic.texture = UiKit.item_icon(String(st.id))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if n > 1:
			var l := UiKit.label(str(n), 15, UiKit.C_TEXT, UiKit.f_semi)
			l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
			l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			l.grow_vertical = Control.GROW_DIRECTION_BEGIN
			b.add_child(l)
		b.pressed.connect(func() -> void:
			Net.send(Protocol.C.TRADE, ["offer", peer, slot, n])
			refresh())
		g.add_child(b)
	if not any:
		_content.add_child(UiKit.label(tr("INV_EMPTY"), 17, UiKit.C_DIM))
	_content.add_child(g)
	_content.add_child(UiKit.button(tr("BTN_CANCEL"), "back", func() -> void: refresh(), "ghost"))

func _report(peer: int, pname: String) -> void:
	Ui.dialog(tr("SOCIAL_REPORT"), tr("SOCIAL_REPORT_TEXT") % pname, [
		[tr("BTN_CANCEL"), "normal"],
		[tr("REPORT_CHAT"), "normal", func() -> void: Net.send(Protocol.C.REPORT, [peer, "chat"])],
		[tr("REPORT_CHEAT"), "normal", func() -> void: Net.send(Protocol.C.REPORT, [peer, "trampas"])],
		[tr("REPORT_GRIEF"), "danger", func() -> void: Net.send(Protocol.C.REPORT, [peer, "molestias"])]], "report")

func _group() -> void:
	var gid := int(Session.group.get("id", 0))
	if gid == 0:
		_content.add_child(UiKit.wrap_label(tr("SOCIAL_NO_GROUP"), 17, UiKit.C_DIM))
		_content.add_child(UiKit.button(tr("SOCIAL_CREATE"), "plus", func() -> void: Net.send(Protocol.C.GROUP, ["create"]), "primary"))
		return
	var leader := false
	for m: Dictionary in Session.group.get("members", []):
		if int(m.get("id", 0)) == Session.my_id and bool(m.get("leader", false)):
			leader = true
	for m: Dictionary in Session.group.get("members", []):
		var mid := int(m.get("id", 0))
		var p := UiKit.panel("flat", 10.0)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon_rect("star" if bool(m.get("leader", false)) else "profile", 24, UiKit.C_ACCENT if bool(m.get("leader", false)) else UiKit.C_TEXT))
		var l := UiKit.label(String(m.get("name", "?")) + ("" if mid != 0 else "  — " + tr("SOCIAL_OFFLINE")), 19, UiKit.C_TEXT if mid != 0 else UiKit.C_DIM, UiKit.f_semi)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if leader and mid != 0 and mid != Session.my_id:
			row.add_child(UiKit.button(tr("SOCIAL_KICK"), "", func() -> void: Net.send(Protocol.C.GROUP, ["kick", mid]), "danger"))
		p.add_child(row)
		_content.add_child(p)
	_content.add_child(UiKit.wrap_label(tr("SOCIAL_GROUP_INFO"), 15, UiKit.C_DIM))
	_content.add_child(UiKit.button(tr("SOCIAL_LEAVE"), "exit", func() -> void: Net.send(Protocol.C.GROUP, ["leave"]), "danger"))

func _emotes() -> void:
	_content.add_child(UiKit.wrap_label(tr("SOCIAL_EMOTES_INFO"), 16, UiKit.C_DIM))
	var h := UiKit.hbox(10)
	for def: Array in [[1, "wave", "EMOTE_WAVE"], [2, "point", "EMOTE_POINT"], [3, "sit", "EMOTE_SIT"]]:
		var code := int(def[0])
		var b := UiKit.button(tr(String(def[2])), String(def[1]), func() -> void:
			Net.send(Protocol.C.EMOTE, code)
			Ui.close_all())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 70
		h.add_child(b)
	_content.add_child(h)
	_content.add_child(UiKit.button(tr("SOCIAL_MARK_HERE"), "mark", func() -> void:
		if WorldRoot.current != null:
			var p := WorldRoot.current.player.global_position
			Net.send(Protocol.C.MARK, [p.x, p.y, p.z])
		Ui.close_all()))
