extends UiScreen
## MainMenu — menú principal sobre la escena 3D de fondo.
## Botones grandes en columna (jugar, perfil, ajustes, créditos y legal, salir) y pie con la
## versión y el nombre del jugador. Sin estado propio.

var _name: Label

func setup() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := Ui.safe_margins()
	# degradado lateral para que el texto se lea sobre la escena
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.04, 0.035, 0.92))
	g.set_color(1, Color(0.02, 0.04, 0.035, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(760, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var m := UiKit.margin(null, int(safe.position.x) + 56, int(safe.position.y) + 40, 40, int(safe.size.y) + 30)
	m.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	m.custom_minimum_size = Vector2(560, 0)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := UiKit.vbox(12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(500, 150)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo)
	v.add_child(UiKit.spacer(true))
	for def: Array in [["MENU_PLAY", "play", "play", "primary"], ["MENU_PROFILE", "profile", "profile", "normal"], ["MENU_SETTINGS", "settings", "settings", "normal"],
			["MENU_LEGAL", "info", "legal", "normal"]]:
		var screen := String(def[2])
		var b := UiKit.button(tr(String(def[0])), String(def[1]), func() -> void: Ui.open(screen), String(def[3]))
		b.custom_minimum_size = Vector2(360, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
	var quit := UiKit.button(tr("MENU_QUIT"), "exit", func() -> void: Ui.confirm_quit(), "ghost")
	quit.custom_minimum_size = Vector2(360, 56)
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(quit)
	v.add_child(UiKit.spacer(true))
	var foot := UiKit.hbox(10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(UiKit.icon_rect("profile", 18, UiKit.C_DIM))
	_name = UiKit.label("", 16, UiKit.C_DIM, UiKit.f_medium)
	foot.add_child(_name)
	foot.add_child(UiKit.label("·  v%s  ·  %s" % [ProjectSettings.get_setting("application/config/version", "0.1.0"), tr("MENU_PROTOCOL") % Protocol.VERSION], 16, Color(UiKit.C_DIM, 0.7)))
	v.add_child(foot)

func refresh() -> void:
	_name.text = Profile.player_name
