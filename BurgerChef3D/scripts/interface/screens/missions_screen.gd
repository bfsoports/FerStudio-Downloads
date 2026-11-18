class_name MissionsScreen
extends MenuScreen
## Misiones, desafíos y logros. El progreso viene de estadísticas reales; la recompensa se reclama una sola vez.

const KINDS: Array = ["mission", "challenge", "achievement"]
const CARD_W := 930.0

var _kind_index := 0

func _init() -> void:
	title_key = "menu.missions"
	icon_name = "target"

func _build(body: VBoxContainer) -> void:
	body.add_child(tab_row([["target", Loc.t("mis.tab_mission")], ["fire", Loc.t("mis.tab_challenge")], ["trophy", Loc.t("mis.tab_achievement")]], _kind_index, _on_tab, 240.0))
	var colw := minf(CARD_W, _inner_w)
	var list := UIKit.column(colw, 10)
	for m in Catalog.missions:
		if str(m["kind"]) == str(KINDS[_kind_index]):
			list.add_child(_card(m, colw))
	body.add_child(UIKit.scroll(UIKit.centered(list)))

func _on_tab(i: int) -> void:
	_kind_index = i
	refresh()

func _card(m: Dictionary, colw: float) -> Control:
	var id := str(m["id"])
	var target := int(m["target"])
	var done := MissionManager.is_complete(m)
	var claimed := MissionManager.is_claimed(id)
	var card := UIKit.card("PanelHi" if (done and not claimed) else "PanelFlat")
	var row := UIKit.hbox(14)
	card.add_child(row)
	var icon_n := "target"
	if claimed:
		icon_n = "trophy"
	elif done:
		icon_n = "gift"
	var ic := UIKit.icon_rect(icon_n, 56)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := UIKit.label(Catalog.name_of(m), "LabelHeader", 22)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_l)
	var desc := UIKit.label(Loc.t("stat." + str(m["stat"]), [target]), "LabelMuted", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var prog := UIKit.hbox(10)
	prog.add_child(UIKit.bar(float(MissionManager.progress(m)), float(target), clampf(colw - 56.0 - 14.0 - 250.0 - 14.0 - 24.0 - 90.0, 110.0, 300.0), 14.0))
	prog.add_child(UIKit.label("%d / %d" % [MissionManager.progress(m), target], "LabelMuted", 16))
	info.add_child(prog)
	row.add_child(info)
	var side := UIKit.vbox(6)
	side.custom_minimum_size = Vector2(250, 0)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rewards := UIKit.hbox(6)
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_child(UIKit.chip("coin", str(int(m["reward_coins"])), "LabelHeader", 26, 22))
	rewards.add_child(UIKit.chip("medal", "%d XP" % int(m["reward_xp"]), "LabelHeader", 26, 20))
	side.add_child(rewards)
	var btn := UIKit.icon_text_button("check", Loc.t("mis.claimed") if claimed else Loc.t("mis.claim"), "ButtonSuccess", 54, 0, 30)
	btn.disabled = claimed or not done
	btn.pressed.connect(_claim.bind(id))
	side.add_child(btn)
	row.add_child(side)
	return card

func _claim(id: String) -> void:
	if MissionManager.claim(id):
		AudioManager.play_sfx("coin")
		Events.toast.emit(Loc.t("mis.reward_given"), "success")
	refresh()
