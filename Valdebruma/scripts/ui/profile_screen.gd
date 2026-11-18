extends UiScreen
## ProfileScreen — nombre visible, aspecto (chaqueta y gorro desbloqueados) y privacidad.
##
## El nombre y los cosméticos se guardan en el dispositivo; dentro de una partida, el cambio
## de cosmético se PIDE al servidor (que comprueba que esté desbloqueado). El identificador de
## cuenta es aleatorio y local: no contiene datos personales.

var _name: LineEdit
var _cos: VBoxContainer

func setup() -> void:
	frame(tr("PROFILE_TITLE"), 0.55, 900.0, "profile")
	_name = UiKit.field(tr("PROFILE_NAME_HINT"), Profile.player_name, 16)
	_name.custom_minimum_size.x = 300
	_name.editable = not Session.active
	var save := UiKit.button(tr("BTN_SAVE"), "check", _save_name, "primary")
	save.disabled = Session.active
	var h := UiKit.hbox(8)
	h.add_child(_name)
	h.add_child(save)
	body.add_child(UiKit.row(tr("PROFILE_NAME"), h, tr("PROFILE_NAME_LOCKED") if Session.active else tr("PROFILE_NAME_RULES")))
	body.add_child(UiKit.line())
	_cos = UiKit.vbox(10)
	body.add_child(_cos)
	body.add_child(UiKit.line())
	var hide := CheckButton.new()
	hide.button_pressed = Profile.hide_nearby
	hide.toggled.connect(func(on: bool) -> void:
		Profile.hide_nearby = on
		Profile.save()
		if Session.active:
			Net.send(Protocol.C.PRIVACY, 1 if on else 0))
	body.add_child(UiKit.row(tr("PROFILE_HIDE"), hide, tr("PROFILE_HIDE_HINT")))
	body.add_child(UiKit.row(tr("PROFILE_ACCOUNT"), UiKit.label(Profile.account.left(8) + "…", 17, UiKit.C_DIM, UiKit.f_medium), tr("PROFILE_ACCOUNT_HINT")))
	Session.progress_changed.connect(refresh)
	Session.roster_changed.connect(refresh)

func _save_name() -> void:
	var n := _name.text.strip_edges()
	if not Protocol.name_ok(n):
		Ui.toast(tr("PROFILE_NAME_BAD"), "bad", "warn")
		return
	Profile.player_name = n
	Profile.save()
	Ui.toast(tr("PROFILE_SAVED"), "good", "check")

func refresh() -> void:
	UiKit.clear(_cos)
	var done: Array = Session.progress.get("done", []) if Session.active else []
	for kind: String in ["jacket", "hat"]:
		_cos.add_child(UiKit.caption(tr("PROFILE_JACKET") if kind == "jacket" else tr("PROFILE_HAT")))
		var row := UiKit.hbox(10)
		var cos: Dictionary = GameData.progression.get("cosmetics", {})
		for id: String in cos.keys():
			var c: Dictionary = cos[id]
			var key := "color" if kind == "jacket" else "hat"
			if not c.has(key):
				continue
			var unlock := String(c.get("unlock", ""))
			var locked := unlock != "" and not done.has(unlock)
			var col := Color(c[key][0], c[key][1], c[key][2])
			var chosen := String(Profile.cosmetics.get(kind, "")) == id
			var cid := id
			var ckind := kind
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 84)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_PANEL2, 0.9), 10, UiKit.C_ACCENT if chosen else UiKit.C_LINE, 3 if chosen else 1))
			b.add_theme_stylebox_override("hover", UiKit.box(UiKit.C_PANEL3, 10, UiKit.C_ACCENT, 2))
			b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.C_PANEL3, 10, UiKit.C_ACCENT, 3))
			b.add_theme_stylebox_override("disabled", UiKit.box(Color(UiKit.C_PANEL, 0.6), 10, Color(UiKit.C_LINE, 0.4), 1))
			b.disabled = locked
			var v := UiKit.vbox(6)
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sw := Panel.new()
			sw.custom_minimum_size = Vector2(0, 30)
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sw.add_theme_stylebox_override("panel", UiKit.box(col.darkened(0.5) if locked else col, 6, Color(0, 0, 0, 0.4), 1))
			v.add_child(sw)
			var nm := UiKit.label(GameData.text(c.get("name", id)), 14, UiKit.C_DIM if locked else UiKit.C_TEXT, UiKit.f_medium)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.clip_text = true
			v.add_child(nm)
			b.add_child(v)
			if locked:
				var def: Dictionary = (GameData.progression.get("challenges", {}) as Dictionary).get(unlock, (GameData.progression.get("achievements", {}) as Dictionary).get(unlock, {}))
				b.tooltip_text = tr("PROFILE_LOCKED") % GameData.text(def.get("name", unlock))
				var lk := UiKit.icon_rect("lock", 18, UiKit.C_DIM)
				lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
				b.add_child(lk)
			b.pressed.connect(func() -> void:
				Profile.cosmetics[ckind] = cid
				Profile.save()
				if Session.active:
					Net.send(Protocol.C.COSMETIC, [ckind, cid])
				refresh())
			row.add_child(b)
		_cos.add_child(UiKit.scroll(row, true))
		(_cos.get_child(_cos.get_child_count() - 1) as Control).custom_minimum_size = Vector2(0, 96)
		(_cos.get_child(_cos.get_child_count() - 1) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not Session.active:
		_cos.add_child(UiKit.wrap_label(tr("PROFILE_UNLOCK_HINT"), 15, UiKit.C_DIM))
