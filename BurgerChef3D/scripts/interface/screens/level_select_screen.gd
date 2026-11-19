class_name LevelSelectScreen
extends MenuScreen
## Selección de nivel de la campaña (30 niveles con estrellas y bloqueo por progreso), modo libre y tutorial.

const TILE_W := 138.0
const TILE_H := 112.0
var _tile_w := TILE_W

var _tab := 0
var _difficulty := 1

func _init() -> void:
	title_key = "menu.play"
	icon_name = "play"

func _build(body: VBoxContainer) -> void:
	body.add_child(tab_row([["target", Loc.t("play.campaign")], ["dice", Loc.t("play.free")], ["info", Loc.t("tut.title")]], _tab, _on_tab, 230.0))
	match _tab:
		0:
			_build_campaign(body)
		1:
			_build_free(body)
		_:
			_build_tutorial(body)

func _on_tab(i: int) -> void:
	_tab = i
	refresh()

# ------------------------------------------------------------------ campaña
func _build_campaign(body: VBoxContainer) -> void:
	var fc := UIKit.fill_columns(_inner_w, TILE_W, 12.0, 8)
	_tile_w = minf(float(fc[1]), TILE_W * 1.5)
	var grid := UIKit.grid(int(fc[0]), 12, 12)
	for lv in Catalog.levels:
		grid.add_child(_tile(int(lv["id"])))
	body.add_child(UIKit.scroll(UIKit.centered(grid)))

func _tile(id: int) -> Control:
	var unlocked := GameState.is_level_unlocked(id)
	var stars_n := GameState.stars_for(id)
	var variant := "ButtonTileLocked"
	if unlocked:
		variant = "ButtonTileDone" if stars_n > 0 else "ButtonTile"
	var tile := UIKit.button("", variant, TILE_H, _tile_w)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var num := UIKit.label(str(id), "LabelHeader" if unlocked else "LabelMuted", 34)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	if unlocked:
		var stars := UIKit.star_row(stars_n, 24)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(stars)
	else:
		var lock := UIKit.icon_rect("lock", 34)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(lock)
	tile.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.pressed.connect(_on_tile.bind(id))
	return tile

func _on_tile(id: int) -> void:
	if not GameState.is_level_unlocked(id):
		AudioManager.play_sfx("error", -6.0)
		Events.toast.emit(Loc.t("play.locked"), "warn")
		return
	_show_detail(id)

func _show_detail(id: int) -> void:
	var lv := Catalog.level_def(id)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var avail := UIKit.canvas_size(self)
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(minf(660.0, avail.x - 28.0), 0)
	center.add_child(panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var title := UIKit.label(Loc.t("result.level", [id, Catalog.name_of(lv)]), "LabelHeader", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var stars := UIKit.star_row(GameState.stars_for(id), 40)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(stars)
	var info := UIKit.hbox(10)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UIKit.chip("clock", Util.fmt_time(float(lv["duration"])), "LabelLight", 28, 22))
	info.add_child(UIKit.chip("fire", Loc.t("play.difficulty", [int(lv["difficulty"])]), "LabelLight", 28, 22))
	if bool(lv.get("dirty_trays", false)):
		info.add_child(UIKit.chip("warning", Loc.t("play.dirty_trays"), "LabelLight", 28, 22))
	v.add_child(info)
	v.add_child(UIKit.divider())
	# parte central desplazable (objetivos y recetas): el diálogo nunca pasa de la altura de la pantalla
	var mid := UIKit.vbox(8)
	mid.add_child(UIKit.section_title(Loc.t("play.goals"), "target"))
	for e in ShiftRules.objective_progress(lv["win"], {}):
		var line := UIKit.hbox(8)
		line.add_child(UIKit.icon_rect("check", 24))
		var goal := UIKit.label(UIKit.objective_label(e, false), "LabelLight", 21)
		goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(goal)
		mid.add_child(line)
	mid.add_child(UIKit.label(Loc.t("play.max_failed", [int(lv["lose"]["max_failed"])]), "LabelMuted", 18))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 6)
	for rid in GameState.campaign_recipes(id):
		var item := UIKit.hbox(6)
		item.add_child(UIKit.burger_stack(Catalog.recipe_layers(str(rid)), 40))
		var rn := UIKit.label(Catalog.name_of(Catalog.recipe(str(rid))), "LabelMuted", 17)
		rn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(rn)
		flow.add_child(item)
	mid.add_child(flow)
	var mid_scroll := UIKit.scroll(mid)
	mid_scroll.custom_minimum_size = Vector2(0, clampf(avail.y - 28.0 - 380.0, 90.0, 230.0))
	v.add_child(mid_scroll)
	var reward := UIKit.hbox(10)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_child(UIKit.chip("coin", "+%d" % int(lv["reward_coins"]), "LabelValue", 30, 26))
	reward.add_child(UIKit.chip("medal", "+%d XP" % int(lv["reward_xp"]), "LabelValue", 30, 26))
	v.add_child(reward)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UIKit.icon_text_button("close", Loc.t("ui.back"), "ButtonSecondary", UIKit.H_BTN, 220, 34)
	back.pressed.connect(layer.queue_free)
	var play := UIKit.icon_text_button("play", Loc.t("play.start"), "ButtonSuccess", UIKit.H_BTN, 280, 40)
	play.pressed.connect(func() -> void: play_requested.emit({"mode": Const.MODE_CAMPAIGN, "level_id": id}))
	row.add_child(back)
	row.add_child(play)
	v.add_child(row)
	add_child(layer)

# ------------------------------------------------------------------ modo libre
func _build_free(body: VBoxContainer) -> void:
	var colw := minf(900.0, _inner_w)
	var v := UIKit.column(colw, 14)
	var desc_card := UIKit.card("PanelFlat")
	var desc := UIKit.label(Loc.t("free.desc"), "LabelLight", 21)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_card.add_child(desc)
	v.add_child(desc_card)
	v.add_child(UIKit.section_title(Loc.t("free.difficulty"), "fire"))
	v.add_child(tab_row(["1", "2", "3", "4", "5"], _difficulty - 1, _on_difficulty, 110.0))
	var info := UIKit.hbox(10)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UIKit.chip("book", str(GameState.unlocked_recipe_ids().size()), "LabelLight", 28, 22))
	info.add_child(UIKit.chip("trophy", str(Util.to_int(GameState.records.get("best_orders", 0))), "LabelLight", 28, 22))
	info.add_child(UIKit.chip("coin", str(Util.to_int(GameState.records.get("best_income", 0))), "LabelLight", 28, 22))
	info.add_child(UIKit.chip("clock", Util.fmt_time(Util.to_float(GameState.records.get("longest_session", 0))), "LabelLight", 28, 22))
	v.add_child(info)
	var hint := UIKit.label(Loc.t("free.recipes", [GameState.unlocked_recipe_ids().size()]), "LabelMuted", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	if _difficulty >= 3:
		var dirty := UIKit.label(Loc.t("free.dirty_trays"), "LabelMuted", 18)
		dirty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dirty)
	var play := UIKit.icon_text_button("play", Loc.t("free.play"), "ButtonSuccess", UIKit.H_CTA, minf(420.0, colw), 48)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: play_requested.emit({"mode": Const.MODE_FREE, "difficulty": _difficulty}))
	v.add_child(play)
	body.add_child(UIKit.scroll(UIKit.centered(v)))

# ------------------------------------------------------------------ tutorial
func _build_tutorial(body: VBoxContainer) -> void:
	var colw := minf(900.0, _inner_w)
	var v := UIKit.column(colw, 14)
	var desc_card := UIKit.card("PanelFlat")
	var dv := UIKit.vbox(8)
	desc_card.add_child(dv)
	var desc := UIKit.label(Loc.t("tut.desc"), "LabelLight", 21)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(desc)
	for key in ["tut.learn_1", "tut.learn_2", "tut.learn_3", "tut.learn_4"]:
		var line := UIKit.hbox(8)
		line.add_child(UIKit.icon_rect("check", 24))
		var l := UIKit.label(Loc.t(key), "LabelMuted", 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(l)
		dv.add_child(line)
	v.add_child(desc_card)
	var info := UIKit.hbox(10)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	if GameState.tutorial_done:
		info.add_child(UIKit.chip("check", Loc.t("tut.completed"), "LabelLight", 28, 20))
	else:
		info.add_child(UIKit.chip("coin", Loc.t("tut.reward", [Tutorial.REWARD_COINS]), "LabelValue", 28, 20))
	info.add_child(UIKit.chip("clock", Loc.t("tut.duration"), "LabelLight", 28, 20))
	v.add_child(info)
	var play := UIKit.icon_text_button("play", Loc.t("tut.start"), "ButtonSuccess", UIKit.H_CTA, minf(420.0, colw), 48)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: play_requested.emit({"mode": Const.MODE_TUTORIAL}))
	v.add_child(play)
	body.add_child(UIKit.scroll(UIKit.centered(v)))

func _on_difficulty(i: int) -> void:
	_difficulty = i + 1
	refresh()
