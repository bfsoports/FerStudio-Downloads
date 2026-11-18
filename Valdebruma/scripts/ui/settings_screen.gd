extends UiScreen
## SettingsScreen — ajustes de control, audio, gráficos, juego y accesibilidad.
##
## Se genera a partir de Config.SPEC: cada clave es un interruptor, un deslizador o un grupo
## de opciones. Todo cambio se aplica y guarda al instante (Config.set_v); los perfiles
## gráficos bajo/medio/alto ajustan a la vez escala de render, distancia, sombras, hierba…

const TABS := [["control", "controls"], ["audio", "audio"], ["video", "video"], ["game", "game"], ["access", "access"]]
const STEPS := {"video/quality": ["SET_Q_LOW", "SET_Q_MED", "SET_Q_HIGH"], "video/shadows": ["SET_OFF", "SET_Q_MED", "SET_Q_HIGH"],
	"video/effects": ["SET_Q_LOW", "SET_Q_MED", "SET_Q_HIGH"], "video/fps_limit": [30, 45, 60, 90, 120], "game/language": ["es", "en"]}
const INT_SLIDERS := ["video/view_distance"]

var _tab := "control"
var _tabs: Dictionary = {}
var _list: VBoxContainer

func setup() -> void:
	frame(tr("SETTINGS_TITLE"), 0.6, 1000.0, "settings")
	_tab = String(args.get("tab", "control"))
	var h := UiKit.hbox(6)
	body.add_child(h)
	for t: Array in TABS:
		var id := String(t[0])
		var b := UiKit.button(tr("SET_TAB_" + id.to_upper()), String(t[1]), func() -> void: _show(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		h.add_child(b)
		_tabs[id] = b
	_list = UiKit.vbox(14)
	body.add_child(UiKit.scroll(UiKit.margin(_list, 4, 6, 14, 6)))
	var foot := UiKit.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(UiKit.button(tr("SET_RESET"), "refresh", func() -> void:
		Ui.confirm(tr("SET_RESET"), tr("SET_RESET_TEXT"), tr("SET_RESET"), func() -> void:
			Config.reset_defaults()
			AudioDirector.apply_volumes()
			_show(_tab)), "ghost"))
	body.add_child(foot)
	_show(_tab)

func _show(tab: String) -> void:
	_tab = tab
	for id: String in _tabs.keys():
		(_tabs[id] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if id == tab else Color(UiKit.C_PANEL2, 0.96), 10,
			UiKit.C_ACCENT if id == tab else UiKit.C_LINE, 1, 12))
	UiKit.clear(_list)
	var spec: Dictionary = Config.SPEC[tab]
	for key: String in spec.keys():
		if tab == "control" and key in ["touch_scale", "touch_opacity", "left_handed", "auto_sprint"] and not (Ui.hud == null or bool(Ui.hud.get("use_touch"))) and not OS.has_feature("mobile"):
			pass      # se muestran igualmente: sirven para preparar el móvil desde el PC
		_list.add_child(_row_for(tab, key, spec[key]))
	if tab == "video":
		_list.add_child(UiKit.wrap_label(tr("SET_VIDEO_NOTE"), 15, UiKit.C_DIM))
	elif tab == "game":
		_list.add_child(UiKit.wrap_label(tr("SET_GAME_NOTE"), 15, UiKit.C_DIM))

func _hint(key: String) -> String:
	var k := "SETH_" + key.to_upper()
	var t := tr(k)
	return "" if t == k else t

func _row_for(section: String, key: String, spec: Array) -> Control:
	var path := section + "/" + key
	var def: Variant = spec[0]
	var value: Variant = Config.get_v(section, key)
	var name_ := tr("SET_" + key.to_upper())
	if STEPS.has(path):
		var h := UiKit.hbox(6)
		var opts: Array = STEPS[path]
		for i in opts.size():
			var opt: Variant = opts[i]
			var v: Variant = opt if (opt is int or path == "game/language") else i
			var text := (tr("LANG_" + String(opt).to_upper()) if path == "game/language" else (str(opt) if opt is int else tr(String(opt))))
			var b := UiKit.button(text, "", func() -> void: _apply_value(section, key, v))
			b.custom_minimum_size = Vector2(96, 50)
			var on: bool = (value == v) if not (v is int and value is int) else int(value) == int(v)
			b.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.24) if on else Color(UiKit.C_PANEL2, 0.96), 10, UiKit.C_ACCENT if on else UiKit.C_LINE, 1, 10))
			h.add_child(b)
		return UiKit.row(name_, h, _hint(key))
	if def is bool:
		var c := CheckButton.new()
		c.button_pressed = bool(value)
		c.toggled.connect(func(on: bool) -> void: _apply_value(section, key, on, false))
		return UiKit.row(name_, c, _hint(key))
	var h2 := UiKit.hbox(10)
	var s := HSlider.new()
	s.min_value = float(spec[1])
	s.max_value = float(spec[2])
	s.step = 1.0 if (def is int or INT_SLIDERS.has(path)) else 0.05
	s.value = float(value)
	s.custom_minimum_size = Vector2(300, 40)
	s.focus_mode = Control.FOCUS_NONE
	var lab := UiKit.label(_fmt(def, float(value)), 17, UiKit.C_ACCENT, UiKit.f_semi)
	lab.custom_minimum_size = Vector2(64, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		lab.text = _fmt(def, v)
		Config.set_v(section, key, int(v) if def is int else v, false)
		if section == "audio":
			AudioDirector.apply_volumes())
	s.drag_ended.connect(func(_changed: bool) -> void:
		Config.save()
		if section == "video":
			Config.applied.emit())
	h2.add_child(s)
	h2.add_child(lab)
	return UiKit.row(name_, h2, _hint(key))

func _fmt(def: Variant, v: float) -> String:
	return str(int(v)) if def is int else "%d %%" % int(round(v * 100.0))

func _apply_value(section: String, key: String, v: Variant, rebuild := true) -> void:
	if section == "video" and key == "quality":
		Config.set_profile(int(v))
	else:
		Config.set_v(section, key, v)
	if section == "audio":
		AudioDirector.apply_volumes()
	if section == "video":
		Config.applied.emit()
	if section == "game" and key == "language":
		Ui.reload_texts()
		return
	if rebuild:
		_show(_tab)
