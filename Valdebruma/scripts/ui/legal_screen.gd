extends UiScreen
## LegalScreen — créditos, privacidad, términos y soporte.
## Los textos viven en data/legal.json (es/en). Privacidad y términos son BORRADORES sin
## revisión jurídica: así se indica en pantalla y en docs/PRIVACY_AND_STORE_CHECKLIST.md.

var _tabs: Dictionary = {}
var _text: RichTextLabel

func setup() -> void:
	frame(tr("LEGAL_TITLE"), 0.6, 1000.0, "info")
	var h := UiKit.hbox(6)
	body.add_child(h)
	for id: String in ["credits", "privacy", "terms", "support"]:
		var tid := id
		var b := UiKit.button(tr("LEGAL_TAB_" + id.to_upper()), "", func() -> void: _show(tid))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		_tabs[id] = b
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 380)
	_text.selection_enabled = false
	_text.add_theme_constant_override("line_separation", 5)
	body.add_child(_text)
	_show(String(args.get("tab", "credits")))

func _show(tab: String) -> void:
	for id: String in _tabs.keys():
		(_tabs[id] as Button).add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_ACCENT, 0.22) if id == tab else Color(UiKit.C_PANEL2, 0.96), 10,
			UiKit.C_ACCENT if id == tab else UiKit.C_LINE, 1, 12))
	var data := DataFiles.dict("res://data/legal.json")
	_text.text = GameData.text(data.get(tab, {}))
	_text.scroll_to_line(0)
