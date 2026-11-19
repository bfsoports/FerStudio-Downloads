class_name RestaurantScreen
extends MenuScreen
## Resumen del restaurante: nivel del chef, experiencia, estrellas, estadísticas acumuladas y récords del modo libre.

const TILE_W := 300.0

func _init() -> void:
	title_key = "menu.restaurant"
	icon_name = "home"

func _build(body: VBoxContainer) -> void:
	var colw := _inner_w
	var v := UIKit.column(colw, 14)
	# nivel del chef y estrellas: en dos tarjetas si caben, una debajo de otra si no
	var wide := colw >= 880.0
	var top: BoxContainer = null
	if wide:
		top = UIKit.hbox(14)
	else:
		top = UIKit.vbox(10)
	var chef := UIKit.card("PanelHi")
	chef.custom_minimum_size = Vector2(500.0 if wide else colw, 0)
	var chef_row := UIKit.hbox(14)
	chef.add_child(chef_row)
	chef_row.add_child(UIKit.icon_rect("medal", 84))
	var col := UIKit.vbox(4)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(Loc.t("rest.chef_level", [GameState.level]), "LabelHeader", 30))
	col.add_child(UIKit.bar(float(GameState.xp), float(GameState.xp_needed(GameState.level)), minf(330.0, colw - 200.0), 16.0))
	col.add_child(UIKit.label("%d / %d XP" % [GameState.xp, GameState.xp_needed(GameState.level)], "LabelMuted", 17))
	chef_row.add_child(col)
	top.add_child(chef)
	var stars := UIKit.card("PanelFlat")
	stars.custom_minimum_size = Vector2(colw - 500.0 - 14.0 if wide else colw, 0)
	var stars_row := UIKit.hbox(12)
	stars.add_child(stars_row)
	stars_row.add_child(UIKit.icon_rect("star", 72))
	var scol := UIKit.vbox(4)
	scol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scol.add_child(UIKit.label(Loc.t("rest.stars", [GameState.total_stars(), Catalog.levels.size() * 3]), "LabelHeader", 26))
	scol.add_child(UIKit.bar(float(GameState.total_stars()), float(Catalog.levels.size() * 3), 250.0, 14.0))
	stars_row.add_child(scol)
	top.add_child(stars)
	v.add_child(top)
	# estadísticas acumuladas: casillas de ancho fijo en columnas
	v.add_child(UIKit.section_title(Loc.t("menu.restaurant"), "stats"))
	var fc := UIKit.fill_columns(colw, 290.0, 12.0, 4)
	var cols: int = fc[0]
	var tile_w: float = fc[1]
	var grid := UIKit.grid(cols, 12, 12)
	var rows: Array = [["stat_burgers_made", "burgers_made", "burger"], ["stat_customers_served", "customers_served", "friend"],
		["stat_coins_earned", "coins_earned", "coin"], ["stat_perfect_burgers", "perfect_burgers", "crown"],
		["stat_best_streak", "best_streak", "fire"], ["stat_levels_completed", "levels_completed", "trophy"],
		["stat_upgrades_bought", "upgrades_bought", "upgrade"], ["stat_shifts_played", "shifts_played", "calendar"]]
	for r in rows:
		grid.add_child(UIKit.stat_tile(str(r[2]), Loc.t("rest." + str(r[0])), str(GameState.stat(str(r[1]))), tile_w))
	v.add_child(grid)
	# récords del modo libre
	v.add_child(UIKit.section_title(Loc.t("rest.records"), "trophy"))
	var rec_card := UIKit.card("PanelFlat")
	var rec := UIKit.label(Loc.t("rest.records_line", [Util.to_int(GameState.records.get("best_orders", 0)),
		Util.to_int(GameState.records.get("best_income", 0)), Util.fmt_time(Util.to_float(GameState.records.get("longest_session", 0)))]), "LabelLight", 21)
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rec_card.add_child(rec)
	v.add_child(rec_card)
	body.add_child(UIKit.scroll(UIKit.centered(v)))
