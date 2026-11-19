class_name UpgradesScreen
extends MenuScreen
## Mejoras del restaurante: cada una modifica de verdad un sistema (capacidad de plancha, velocidad, paciencia...).
## Tarjetas de ancho fijo en dos columnas: nada se estira de lado a lado.

const CARD_W := 470.0   # ancho máximo de una tarjeta
const CARD_MIN := 360.0
## Icono propio de cada mejora (lo que mejora: plancha, freidora, tabla, caja registradora...).
const ICONS: Dictionary = {"grill_capacity": "grill", "fryer_capacity": "fryer", "cook_speed": "fire", "prep_space": "board",
	"storage": "crate", "patience": "hourglass", "service_points": "cloche", "coin_bonus": "register",
	"restaurant_look": "roller", "recipe_book": "book", "decor_options": "plant", "dishwasher": "sink"}   # por debajo de este ancho se pasa a una sola columna

func _init() -> void:
	title_key = "menu.upgrades"
	icon_name = "upgrade"

func _build(body: VBoxContainer) -> void:
	# las tarjetas llenan todo el ancho de la pantalla (2 o 3 columnas según quepan)
	var fc := UIKit.fill_columns(_inner_w, CARD_MIN + 90.0, 14.0, 3)
	var cols: int = fc[0]
	var card_w: float = fc[1]
	var grid := UIKit.grid(cols, 14, 14)
	for id in Catalog.upgrade_order:
		grid.add_child(_card(str(id), card_w))
	body.add_child(UIKit.scroll(UIKit.centered(grid)))

static func _fmt(stat_key: String, v: float) -> String:
	if stat_key == "cook_speed" or stat_key == "patience_mult" or stat_key == "coin_mult" or stat_key == "wash_speed":
		return "x%.2f" % v
	return "%d" % int(round(v))

func _card(id: String, card_w: float) -> Control:
	var def: Dictionary = Catalog.upgrades[id]
	var lv := EconomyManager.upgrade_level(id)
	var max_l := int(def["max_level"])
	var eff: Dictionary = def["effect"]
	var stat_key := str(eff["stat"])
	var card := UIKit.card("PanelFlat")
	card.custom_minimum_size = Vector2(card_w, 0)
	var v := UIKit.vbox(8)
	card.add_child(v)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect(str(ICONS.get(id, "upgrade")), 64))
	var title_col := UIKit.vbox(4)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := UIKit.label(Catalog.name_of(def), "LabelHeader", 24)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(name_l)
	title_col.add_child(UIKit.pips(lv, max_l))
	head.add_child(title_col)
	v.add_child(head)
	var desc := UIKit.label(Loc.pick(def["desc"]), "LabelMuted", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var cur := EconomyManager.stat_value(stat_key, 0.0)
	var line := "%s: %s" % [Loc.t("upgstat." + stat_key), _fmt(stat_key, cur)]
	if lv < max_l:
		line += "  ->  " + _fmt(stat_key, cur + float(eff["per_level"]))
	v.add_child(UIKit.label("%s  (%s)" % [line, Loc.t("upg.level", [lv, max_l])], "LabelLight", 16))
	var foot := UIKit.hbox(10)
	v.add_child(foot)
	if lv >= max_l:
		var m := UIKit.label(Loc.t("upg.maxed"), "LabelGold", 26)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		foot.add_child(m)
		return card
	var chk := EconomyManager.can_buy_upgrade(id)
	var reason_l := UIKit.label("", "LabelMuted", 16)
	reason_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reason_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not bool(chk["ok"]):
		var reason := str(chk["reason"])
		reason_l.text = Loc.t(reason, [Util.to_int(def.get("requires_player_level", 1))]) if reason == "upg.need_level" else Loc.t(reason)
	foot.add_child(reason_l)
	var btn := UIKit.icon_text_button("coin", Loc.t("upg.buy", [EconomyManager.upgrade_next_cost(id)]), "ButtonSuccess", UIKit.H_SMALL, 0, 30)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.disabled = not bool(chk["ok"])
	btn.pressed.connect(_buy.bind(id))
	foot.add_child(btn)
	return card

func _buy(id: String) -> void:
	var r := EconomyManager.buy_upgrade(id)
	if bool(r["ok"]):
		AudioManager.play_sfx("buy")
		Events.toast.emit(Loc.t("upg.bought", [Catalog.name_of(Catalog.upgrades[id])]), "success")
	else:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t(str(r["reason"])), "warn")
	refresh()
