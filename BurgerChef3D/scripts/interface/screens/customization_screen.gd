class_name CustomizationScreen
extends MenuScreen
## Tienda de personalización: cada artículo es una variante real del restaurante (colores, suelos, carteles, plantas...).
## Los artículos comprados persisten y se aplican al empezar el siguiente turno.

const CARD_W := 304.0

var _cat_index := 0
var _new_items: Array = []   # artículos que eran nuevos al abrir la tienda (se marcan como vistos al abrirla)

func _init() -> void:
	title_key = "menu.customize"
	icon_name = "palette"

func _ready() -> void:
	_new_items = EconomyManager.unseen_items()
	EconomyManager.mark_items_seen()
	super._ready()

func _build(body: VBoxContainer) -> void:
	var note := UIKit.label(Loc.t("cust.note"), "LabelMuted", 17)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	var tab_cols := UIKit.fit_columns(_inner_w, 214.0, 8.0, 2, 4)
	var tab_w := UIKit.fit_width(_inner_w, tab_cols, 8, 214.0)
	var tabs := UIKit.grid(tab_cols, 8, 8)
	var group := ButtonGroup.new()
	for i in Catalog.shop_categories.size():
		var cat_name := Loc.t("cat." + str(Catalog.shop_categories[i]))
		if _category_has_new(str(Catalog.shop_categories[i])):
			cat_name += " •"
		var b := UIKit.button(cat_name, "ButtonToggle", 50, tab_w)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _cat_index
		b.pressed.connect(_on_cat.bind(i))
		tabs.add_child(b)
	body.add_child(UIKit.centered(tabs))
	var cols := UIKit.fit_columns(_inner_w, CARD_W, 12.0, 2, 3)
	var card_w := UIKit.fit_width(_inner_w, cols, 12, CARD_W)
	var grid := UIKit.grid(cols, 12, 12)
	for it in Catalog.items_in_category(str(Catalog.shop_categories[_cat_index])):
		grid.add_child(_card(it, card_w))
	body.add_child(UIKit.scroll(UIKit.centered(grid)))

func _category_has_new(cat: String) -> bool:
	for it in Catalog.items_in_category(cat):
		if _new_items.has(str(it["id"])):
			return true
	return false

func _on_cat(i: int) -> void:
	_cat_index = i
	refresh()

func _swatch(it: Dictionary) -> Control:
	var params: Dictionary = it.get("params", {})
	if params.has("tex"):
		var tex_rect := TextureRect.new()
		var path := "res://assets/textures/%s.png" % str(params["tex"])
		if ResourceLoader.exists(path):
			tex_rect.texture = load(path) as Texture2D
		tex_rect.custom_minimum_size = Vector2(76, 76)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		return tex_rect
	if params.has("color"):
		var p := Panel.new()
		var sb := UITheme.box(Util.html_color(str(params["color"])), UITheme.WIN_EDGE, 14, 3, false, 0)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(76, 76)
		return p
	return UIKit.icon_rect("palette", 70)

func _card(it: Dictionary, card_w: float) -> Control:
	var id := str(it["id"])
	var owned := GameState.owned_items.has(id)
	var equipped := str(GameState.equipped.get(str(it["category"]), "")) == id
	var card := UIKit.card("PanelHi" if equipped else "PanelFlat")
	card.custom_minimum_size = Vector2(card_w, 0)
	var v := UIKit.vbox(6)
	card.add_child(v)
	var sw := _swatch(it)
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sw)
	var name_l := UIKit.label(Catalog.name_of(it), "LabelHeader", 22)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	var status := Loc.t("cust.free") if int(it["price"]) == 0 else Loc.t("cust.price", [int(it["price"])])
	if not owned and not EconomyManager.item_upgrade_ok(it):
		status = Loc.t("shop.need_upgrade")
	elif not owned and GameState.level < int(it["unlock_level"]):
		status = Loc.t("upg.need_level", [int(it["unlock_level"])])
	elif _new_items.has(id):
		status = "%s  ·  %s" % [Loc.t("ui.new"), status]
	var status_l := UIKit.label(status, "LabelMuted", 16)
	status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_l.clip_text = true
	status_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(status_l)
	var btn: Button
	if equipped:
		btn = UIKit.icon_text_button("check", Loc.t("cust.equipped"), "ButtonSuccess", UIKit.H_SMALL, 0, 30)
		btn.disabled = true
	elif owned:
		btn = UIKit.icon_text_button("star", Loc.t("cust.equip"), "ButtonPrimary", UIKit.H_SMALL, 0, 30)
		btn.pressed.connect(_equip.bind(id))
	else:
		var chk := EconomyManager.can_buy_item(id)
		btn = UIKit.icon_text_button("coin", Loc.t("upg.buy", [int(it["price"])]), "ButtonSuccess", UIKit.H_SMALL, 0, 30)
		btn.disabled = not bool(chk["ok"])
		btn.pressed.connect(_buy.bind(id))
	v.add_child(btn)
	return card

func _equip(id: String) -> void:
	if EconomyManager.equip(id):
		AudioManager.play_sfx("click")
	refresh()

func _buy(id: String) -> void:
	var r := EconomyManager.buy_item(id)
	if bool(r["ok"]):
		AudioManager.play_sfx("buy")
		EconomyManager.equip(id)
		Events.toast.emit(Loc.t("cust.bought"), "success")
	else:
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t(str(r["reason"])), "warn")
	refresh()
