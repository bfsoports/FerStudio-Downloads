class_name CreditsScreen
extends MenuScreen
## Créditos y licencias: motor, modelos 3D, iconos, audio y tipografía, con los textos de licencia de Godot (y de sus
## componentes de terceros) y de las tipografías Poppins y Fredoka (SIL OFL 1.1) en un apartado desplegable.

const OFL_PATH := "res://assets/fonts/OFL.txt"
const OFL_FREDOKA_PATH := "res://assets/fonts/OFL-Fredoka.txt"

var _show_licenses := false

var _col_w := 700.0

func _init() -> void:
	title_key = "menu.credits"
	icon_name = "heart"

func _build(body: VBoxContainer) -> void:
	# en pantallas anchas: a la izquierda el juego y el estudio, a la derecha los créditos y licencias
	var two := _inner_w >= 980.0
	_col_w = floorf((_inner_w - 24.0) * 0.5) if two else _inner_w
	var cols := UIKit.hbox(24)
	var left := UIKit.column(_col_w, 12)
	cols.add_child(left)
	var v := UIKit.column(_col_w, 12) if two else left
	if two:
		cols.add_child(v)
	var logo := UIKit.icon_rect("burger", 96)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(logo)
	var t := UIKit.label(Const.GAME_NAME, "LabelHeader", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(t)
	var ver := UIKit.label(Loc.t("credits.version", [Const.GAME_VERSION]), "LabelMuted", 20)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(ver)
	left.add_child(_studio_card())
	var card := UIKit.card("PanelFlat")
	var rows := UIKit.vbox(12)
	card.add_child(rows)
	var entries: Array = [["crown", "credits.studio"], ["settings", "credits.engine"], ["home", "credits.models"],
		["star", "credits.icons"], ["palette", "credits.art"], ["sound_on", "credits.audio"], ["music_on", "credits.music"],
		["chat", "credits.font"]]
	for e in entries:
		var row := UIKit.hbox(14)
		var ic := UIKit.icon_rect(str(e[0]), 38)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var l := UIKit.label(Loc.t(str(e[1])), "LabelLight", 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		rows.add_child(row)
	v.add_child(card)
	var thanks := UIKit.label(Loc.t("credits.thanks"), "LabelGold", 30)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(thanks)
	var lic_btn := UIKit.icon_text_button("info", Loc.t("credits.hide_licenses") if _show_licenses else Loc.t("credits.licenses"), "ButtonSecondary", UIKit.H_SMALL, 0, 30)
	lic_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lic_btn.pressed.connect(_toggle_licenses)
	v.add_child(lic_btn)
	if _show_licenses:
		v.add_child(_license_card("Godot Engine", Engine.get_license_text()))
		var parts: Array = []
		for info in Engine.get_copyright_info():
			var d: Dictionary = info
			var lic := ""
			for part in d.get("parts", []):
				var pd: Dictionary = part
				lic = str(pd.get("license", ""))
			parts.append("%s (%s)" % [str(d.get("name", "")), lic])
		v.add_child(_license_card(Loc.t("credits.third_party"), ", ".join(parts)))
		var ofl := FileAccess.get_file_as_string(OFL_PATH)
		if ofl != "":
			v.add_child(_license_card("Poppins - SIL Open Font License 1.1", ofl))
		var ofl2 := FileAccess.get_file_as_string(OFL_FREDOKA_PATH)
		if ofl2 != "":
			v.add_child(_license_card("Fredoka - SIL Open Font License 1.1", ofl2))
	body.add_child(UIKit.scroll(UIKit.centered(cols)))

## Tarjeta del estudio: quién hace el juego, contacto y enlaces legales (los pide la Amazon Appstore).
func _studio_card() -> Control:
	var card := UIKit.card("PanelHi")
	var v := UIKit.vbox(8)
	card.add_child(v)
	v.add_child(UIKit.section_title(Const.STUDIO_NAME, "crown"))
	var who := UIKit.label(Loc.t("studio.by", [Const.STUDIO_OWNER]), "LabelLight", 19)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(who)
	var desc := UIKit.label(Loc.t("studio.desc"), "LabelMuted", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	v.add_child(UIKit.label(Loc.t("studio.contact", [Const.SUPPORT_EMAIL]), "LabelLight", 18))
	v.add_child(StudioLinks.build(_col_w - 40.0))
	return card

func _toggle_licenses() -> void:
	_show_licenses = not _show_licenses
	AudioManager.play_sfx("click")
	refresh()

func _license_card(title: String, text: String) -> Control:
	var card := UIKit.card("PanelFlat")
	var v := UIKit.vbox(6)
	card.add_child(v)
	v.add_child(UIKit.label(title, "LabelHeader", 20))
	var l := UIKit.label(text, "LabelMuted", 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return card
