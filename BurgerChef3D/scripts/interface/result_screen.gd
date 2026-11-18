class_name ResultScreen
extends Control
## Pantalla de resultado de un turno (victoria, derrota o resumen del modo libre) con estrellas, estadísticas reales,
## objetivos, recompensas y accesos a siguiente nivel / reintentar / menú. Casillas de ancho fijo, sin estirarse.

signal next_requested
signal retry_requested
signal menu_requested
signal double_requested(amount: int)

const STAT_W := 290.0

var result: Dictionary = {}
var _double_btn: Button = null

func _init(res: Dictionary = {}) -> void:
	result = res
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := UIKit.frame(1500.0)
	add_child(frame)
	var margin := UIKit.margin_container(self, 12)
	frame.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var avail := UIKit.canvas_size(self)
	var panel_w := minf(940.0, avail.x - 28.0)
	var inner := panel_w - 42.0
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var mode := str(result.get("mode", Const.MODE_CAMPAIGN))
	var won := bool(result.get("won", false))
	var good := won or mode == Const.MODE_FREE
	var title_key := "result.free" if mode == Const.MODE_FREE else ("result.win" if won else "result.lose")
	var head := UIKit.hbox(14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	if mode == Const.MODE_FREE:
		head.add_child(UIKit.icon_rect("stats", 58))
	elif won:
		head.add_child(UIKit.icon_rect("trophy", 58))
	else:
		head.add_child(UIKit.icon_rect("skull", 58))
	var title := UIKit.label(Loc.t(title_key), "LabelHeader", 42)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_color_override("font_color", Palette.LETTUCE if good else Palette.KETCHUP)
	head.add_child(title)
	v.add_child(head)
	if mode == Const.MODE_CAMPAIGN:
		var lv := Catalog.level_def(int(result.get("level_id", 1)))
		var sub := UIKit.label(Loc.t("result.level", [int(result.get("level_id", 1)), Catalog.name_of(lv)]), "LabelMuted", 21)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
		var stars := UIKit.star_row(0, 52)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(stars)
		_reveal_stars(stars, int(result.get("stars", 0)))
		if not won:
			var why := UIKit.label(Loc.t("result.reason_%s" % str(result.get("reason", "time"))), "LabelMuted", 21)
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(why)
	var body := UIKit.column(inner, 10)
	body.add_child(_stats_grid(inner))
	if mode == Const.MODE_CAMPAIGN:
		for e in result.get("objectives", []):
			var r := UIKit.hbox(10)
			r.add_child(UIKit.icon_rect("check" if bool(e["done"]) else "close", 30))
			var ol := UIKit.label(UIKit.objective_label(e, true), "LabelLight", 21)
			ol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(ol)
			body.add_child(r)
	for rid in result.get("new_recipes", []):
		body.add_child(_note("book", Loc.t("result.new_recipe", [Catalog.name_of(Catalog.recipe(str(rid)))])))
	for key in result.get("records", []):
		body.add_child(_note("trophy", Loc.t("result.record_%s" % str(key))))
	# x2 monedas con un anuncio recompensado (al ganar un nivel o al terminar el modo libre)
	if good and Ads.rewarded_ready():
		var amount := Ads.double_amount(result)
		_double_btn = UIKit.icon_text_button("gift", Loc.t("ads.double", [amount]), "ButtonPrimary", UIKit.H_SMALL, minf(460.0, inner), 32)
		_double_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_double_btn.pressed.connect(func() -> void:
			_double_btn.disabled = true
			double_requested.emit(amount))
		v.add_child(_double_btn)
	var sc := UIKit.scroll(UIKit.centered(body))
	var extra := UIKit.H_SMALL + 8.0 if _double_btn != null else 0.0
	sc.custom_minimum_size = Vector2(0, clampf(avail.y - 28.0 - 330.0 - extra, 110.0, 290.0))
	v.add_child(sc)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var k := minf(1.0, (inner - 28.0) / 750.0)   # los tres botones se encogen si la pantalla es estrecha
	if mode == Const.MODE_CAMPAIGN and won and int(result.get("next_level", 0)) > 0:
		var nb := UIKit.icon_text_button("skip", Loc.t("result.next"), "ButtonSuccess", UIKit.H_BTN, 280.0 * k, 38)
		nb.pressed.connect(func() -> void: next_requested.emit())
		row.add_child(nb)
	if mode == Const.MODE_CAMPAIGN or mode == Const.MODE_FREE:
		var rb := UIKit.icon_text_button("rebirth", Loc.t("result.retry"), "ButtonPrimary", UIKit.H_BTN, 250.0 * k, 38)
		rb.pressed.connect(func() -> void: retry_requested.emit())
		row.add_child(rb)
	var mb := UIKit.icon_text_button("home", Loc.t("result.menu"), "ButtonSecondary", UIKit.H_BTN, 220.0 * k, 38)
	mb.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(mb)

## Tras el anuncio del «x2»: si se vio entero el botón queda como «cobrado»; si no, se puede volver a intentar.
func set_double_done(earned: bool) -> void:
	if _double_btn == null:
		return
	if earned:
		_double_btn.text = Loc.t("ads.double_done")
		_double_btn.disabled = true
	else:
		_double_btn.disabled = not Ads.rewarded_ready()

func _note(icon_name: String, text: String) -> HBoxContainer:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.icon_rect(icon_name, 34))
	var l := UIKit.label(text, "LabelHeader", 22)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

func _stats_grid(inner: float) -> GridContainer:
	var cols := UIKit.fit_columns(inner, STAT_W, 12.0, 2, 3)
	var tile_w := UIKit.fit_width(inner, cols, 12, STAT_W)
	var g := UIKit.grid(cols, 12, 10)
	var xp_total := int(result.get("xp_gained", 0)) + int(result.get("xp_bonus", 0))
	var rows: Array = [
		["check", "result.orders_ok", int(result.get("orders_ok", 0))], ["close", "result.orders_wrong", int(result.get("orders_wrong", 0))],
		["clock", "result.orders_expired", int(result.get("orders_expired", 0))], ["friend", "result.customers", int(result.get("customers", 0))],
		["cash", "result.income", int(result.get("income", 0))], ["warning", "result.penalties", int(result.get("penalties", 0))],
		["coin", "result.net_income", int(result.get("net_income", 0))], ["player", "result.satisfaction", "%d%%" % int(result.get("satisfaction", 0))],
		["fire", "result.burnt", int(result.get("burnt", 0))], ["medal", "result.xp", xp_total],
		["gift", "result.coins_bonus", int(result.get("coins_bonus", 0))], ["calendar", "result.time", Util.fmt_time(float(result.get("time_played", 0)))],
	]
	for r in rows:
		g.add_child(UIKit.stat_tile(str(r[0]), Loc.t(str(r[1])), str(r[2]), tile_w))
	return g

func _reveal_stars(row: HBoxContainer, count: int) -> void:
	var tw := create_tween()
	for i in count:
		tw.tween_interval(0.35)
		tw.tween_callback(func() -> void:
			var icon := row.get_child(i) as TextureRect
			icon.texture = UIKit.icon("star", 52.0)
			icon.modulate = Color.WHITE
			icon.pivot_offset = icon.size * 0.5
			icon.scale = Vector2(1.6, 1.6)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioManager.play_sfx("coin", -4.0, 1.0 + 0.15 * i))
