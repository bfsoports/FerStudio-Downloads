extends UiScreen
## JournalScreen — diario del superviviente.
##
## Pestañas: progreso (nivel, experiencia, ventajas, días), desafíos y logros con su avance,
## encargos del tablón (aceptar, abandonar, entregar: solo junto a un tablón; el servidor lo
## comprueba), documentos leídos y lugares descubiertos. Todo procede de Session.progress.

const TABS := ["progress", "challenges", "board", "docs", "places"]

var _tab := "progress"
var _tabs: Dictionary = {}
var _content: VBoxContainer

func setup() -> void:
	frame(tr("JOURNAL_TITLE"), 0.5, 1100.0, "journal")
	_tab = String(args.get("tab", "progress"))
	var h := UiKit.hbox(6)
	body.add_child(h)
	for id: String in TABS:
		var tid := id
		var b := UiKit.button(tr("JOURNAL_TAB_" + id.to_upper()), "", func() -> void:
			_tab = tid
			refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		h.add_child(b)
		_tabs[id] = b
	_content = UiKit.vbox(8)
	body.add_child(UiKit.scroll(UiKit.margin(_content, 2, 4, 12, 4)))
	Session.progress_changed.connect(refresh)

func refresh() -> void:
	for id: String in _tabs.keys():
		(_tabs[id] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if id == _tab else Color(UiKit.C_PANEL2, 0.96), 10,
			UiKit.C_ACCENT if id == _tab else UiKit.C_LINE, 1, 12))
	UiKit.clear(_content)
	match _tab:
		"progress": _progress()
		"challenges": _challenges()
		"board": _board()
		"docs": _docs()
		"places": _places()

func _progress() -> void:
	var pr: Dictionary = Session.progress
	var level := int(pr.get("level", 1))
	var xp := int(pr.get("xp", 0))
	var levels: Array = GameData.progression.get("levels", [0])
	var cur := int(levels[clampi(level - 1, 0, levels.size() - 1)])
	var nxt := int(levels[clampi(level, 0, levels.size() - 1)])
	var p := UiKit.panel("flat", 14.0)
	var v := UiKit.vbox(8)
	var h := UiKit.hbox(12)
	h.add_child(UiKit.icon_rect("star", 34, UiKit.C_ACCENT))
	h.add_child(UiKit.title(tr("JOURNAL_LEVEL") % level, 34))
	v.add_child(h)
	var bar := UiKit.bar(UiKit.C_ACCENT, 12.0)
	bar.value = 100.0 if nxt <= cur else float(xp - cur) / float(nxt - cur) * 100.0
	v.add_child(bar)
	v.add_child(UiKit.label(tr("JOURNAL_XP_MAX") % xp if nxt <= cur else tr("JOURNAL_XP") % [xp, nxt], 16, UiKit.C_DIM))
	p.add_child(v)
	_content.add_child(p)
	_content.add_child(UiKit.caption(tr("JOURNAL_PERKS")))
	var perks: Dictionary = GameData.progression.get("perks", {})
	var keys: Array = perks.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k: String in keys:
		var got := level >= int(k)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon_rect("check" if got else "lock", 20, UiKit.C_GOOD if got else UiKit.C_DIM))
		row.add_child(UiKit.label(tr("JOURNAL_PERK_AT") % int(k), 16, UiKit.C_DIM))
		row.add_child(UiKit.label(GameData.text((perks[k] as Dictionary).get("text", "")), 17, UiKit.C_TEXT if got else UiKit.C_DIM))
		_content.add_child(row)
	_content.add_child(UiKit.caption(tr("JOURNAL_STATS")))
	var stats: Dictionary = pr.get("stats", {})
	var g := UiKit.grid(2, 8)
	for def: Array in [["JSTAT_DAYS", "%.1f" % float(pr.get("days", 0.0))], ["JSTAT_PLACES", str((pr.get("places", []) as Array).size())],
			["JSTAT_DOCS", str((pr.get("docs", []) as Array).size())], ["JSTAT_DISTANCE", "%d m" % int(float(stats.get("distance", 0.0)))],
			["JSTAT_HARVEST", str(int(float(stats.get("harvests", 0.0))))], ["JSTAT_CRAFT", str(int(float(stats.get("crafts", 0.0))))],
			["JSTAT_BUILT", str(int(float(stats.get("builds", 0.0))))], ["JSTAT_CONTRACTS", str(int(float(stats.get("contracts", 0.0))))]]:
		var cell := UiKit.panel("flat", 10.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ch := UiKit.hbox(8)
		var l := UiKit.label(tr(String(def[0])), 16, UiKit.C_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(l)
		ch.add_child(UiKit.label(String(def[1]), 18, UiKit.C_TEXT, UiKit.f_semi))
		cell.add_child(ch)
		g.add_child(cell)
	_content.add_child(g)

func _challenges() -> void:
	var done: Array = Session.progress.get("done", [])
	var stats: Dictionary = Session.progress.get("stats", {})
	for group: String in ["challenges", "achievements"]:
		_content.add_child(UiKit.caption(tr("JOURNAL_" + group.to_upper())))
		var defs: Dictionary = GameData.progression.get(group, {})
		for id: String in defs.keys():
			var c: Dictionary = defs[id]
			var ok := done.has(id)
			var goal := float(c.get("goal", 1))
			var val := minf(goal, float(stats.get(String(c.get("stat", "")), 0.0)))
			var p := UiKit.panel("flat", 10.0)
			var row := UiKit.hbox(10)
			row.add_child(UiKit.icon_rect("check" if ok else "star", 24, UiKit.C_GOOD if ok else UiKit.C_DIM))
			var v := UiKit.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UiKit.label(GameData.text(c.get("name", id)), 18, UiKit.C_TEXT, UiKit.f_semi))
			v.add_child(UiKit.wrap_label(GameData.text(c.get("desc", "")), 15, UiKit.C_DIM))
			if not ok and goal > 1.0:
				var b := UiKit.bar(UiKit.C_ACCENT, 6.0)
				b.value = val / goal * 100.0
				v.add_child(b)
			row.add_child(v)
			var right := UiKit.vbox(0)
			right.alignment = BoxContainer.ALIGNMENT_CENTER
			if not ok and goal > 1.0:
				right.add_child(UiKit.label("%d / %d" % [int(val), int(goal)], 16, UiKit.C_DIM, UiKit.f_semi))
			if c.has("xp"):
				right.add_child(UiKit.label("+%d XP" % int(c.xp), 14, UiKit.C_ACCENT if not ok else UiKit.C_DIM))
			row.add_child(right)
			p.add_child(row)
			_content.add_child(p)

func _board() -> void:
	var states: Dictionary = Session.progress.get("contracts", {})
	_content.add_child(UiKit.wrap_label(tr("JOURNAL_BOARD_INFO"), 16, UiKit.C_DIM))
	var defs: Dictionary = GameData.progression.get("contracts", {})
	for id: String in defs.keys():
		var c: Dictionary = defs[id]
		var state := String(states.get(id, ""))
		var cid := id
		var p := UiKit.panel("accent" if state in ["active", "ready"] else "flat", 10.0)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon_rect("check" if state == "done" else "contract", 26, UiKit.C_GOOD if state in ["done", "ready"] else UiKit.C_ACCENT))
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(GameData.text(c.get("name", id)), 18, UiKit.C_TEXT if state != "done" else UiKit.C_DIM, UiKit.f_semi))
		v.add_child(UiKit.wrap_label(GameData.text(c.get("desc", "")), 15, UiKit.C_DIM))
		var rew: PackedStringArray = []
		for item: String in (c.get("reward", {}) as Dictionary).keys():
			rew.append("%s ×%d" % [GameData.item_name(item), int(c.reward[item])])
		rew.append("%d XP" % int(c.get("xp", 30)))
		v.add_child(UiKit.label(tr("JOURNAL_REWARD") % ", ".join(rew), 14, UiKit.C_ACCENT))
		if c.has("deliver") and state in ["active", "ready"]:
			var parts: PackedStringArray = []
			for item: String in (c.deliver as Dictionary).keys():
				parts.append("%s %d/%d" % [GameData.item_name(item), Session.inv.count(item), int(c.deliver[item])])
			v.add_child(UiKit.label(", ".join(parts), 14, UiKit.C_TEXT))
		row.add_child(v)
		match state:
			"":
				row.add_child(UiKit.button(tr("JOURNAL_ACCEPT"), "", func() -> void: Net.send(Protocol.C.CONTRACT, ["accept", cid])))
			"active", "ready":
				var bv := UiKit.vbox(6)
				var can := state == "ready" or (c.has("deliver") and Session.inv.has_all(c.deliver))
				var turn := UiKit.button(tr("JOURNAL_TURNIN"), "", func() -> void: Net.send(Protocol.C.CONTRACT, ["turnin", cid]), "primary" if can else "normal")
				turn.disabled = not can
				bv.add_child(turn)
				var ab := UiKit.button(tr("JOURNAL_ABANDON"), "", func() -> void: Net.send(Protocol.C.CONTRACT, ["abandon", cid]), "ghost")
				ab.custom_minimum_size.y = 40
				bv.add_child(ab)
				row.add_child(bv)
			"done":
				row.add_child(UiKit.label(tr("JOURNAL_DONE"), 16, UiKit.C_GOOD, UiKit.f_semi))
		p.add_child(row)
		_content.add_child(p)

func _docs() -> void:
	var read: Array = Session.progress.get("docs", [])
	_content.add_child(UiKit.caption(tr("JOURNAL_DOCS_COUNT") % [read.size(), GameData.documents.size()]))
	if read.is_empty():
		_content.add_child(UiKit.wrap_label(tr("JOURNAL_DOCS_NONE"), 17, UiKit.C_DIM))
	for id: String in GameData.documents.keys():
		if not read.has(id):
			continue
		var d: Dictionary = GameData.documents[id]
		var did := id
		var b := UiKit.button(GameData.text(d.get("title", id)), "doc", func() -> void: Ui.open("doc", {"id": did}))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_content.add_child(b)

func _places() -> void:
	var found: Array = Session.progress.get("places", [])
	var total := GameData.world.places.size()
	_content.add_child(UiKit.caption(tr("JOURNAL_PLACES_COUNT") % [found.size(), total]))
	var g := UiKit.grid(2, 8)
	for p: Dictionary in GameData.world.places:
		var known := found.has(String(p.id))
		if bool(p.get("secret", false)) and not known:
			continue
		var cell := UiKit.panel("flat", 10.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UiKit.hbox(8)
		h.add_child(UiKit.icon_rect("mark", 20, UiKit.C_ACCENT if known else Color(UiKit.C_DIM, 0.5)))
		h.add_child(UiKit.label(String(p.name) if known else "? ? ?", 17, UiKit.C_TEXT if known else UiKit.C_DIM))
		cell.add_child(h)
		g.add_child(cell)
	_content.add_child(g)
