extends VBoxContainer
## ChatBox — chat de texto del HUD.
##
## Muestra los últimos mensajes (se atenúan solos) y, al enfocarlo, una línea para escribir con
## selector de canal: cerca (45 m), grupo o global (si el servidor lo permite). El servidor
## limita frecuencia y longitud; los jugadores silenciados se filtran en Session.
## Señales: focus_changed(activo) para que el HUD bloquee el movimiento mientras se escribe.

signal focus_changed(active: bool)

const CHANNELS := ["CHAT_NEAR", "CHAT_GROUP", "CHAT_GLOBAL"]
const COLORS := [Color("ece7d8"), Color("86c47f"), Color("6fb7dc")]
const KEEP_S := 9.0

var channel := 0
var _feed: VBoxContainer
var _row: HBoxContainer
var _edit: LineEdit
var _chan: Button
var _lines: Array = []     # [nodo, ms]

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed = UiKit.vbox(3)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	_row = UiKit.hbox(6)
	_row.visible = false
	add_child(_row)
	_chan = UiKit.button(tr(CHANNELS[0]), "", func() -> void: _cycle())
	_chan.custom_minimum_size = Vector2(110, 46)
	_row.add_child(_chan)
	_edit = UiKit.field(tr("CHAT_HINT"), "", 140)
	_edit.custom_minimum_size = Vector2(300, 46)
	_edit.select_all_on_focus = false
	_edit.text_submitted.connect(_send)
	_row.add_child(_edit)
	_row.add_child(UiKit.icon_button("check", func() -> void: _send(_edit.text), 46, "primary"))
	_row.add_child(UiKit.icon_button("close", func() -> void: unfocus(), 46, "ghost"))
	Session.chat_received.connect(_on_chat)

func _cycle() -> void:
	channel = (channel + 1) % 3
	if channel == 2 and not Session.global_chat:
		channel = 0
	_chan.text = tr(CHANNELS[channel])
	_chan.add_theme_color_override("font_color", COLORS[channel])

func focus() -> void:
	if not Config.b("game", "chat"):
		Ui.toast(tr("CHAT_DISABLED"), "info", "chat")
		return
	_row.visible = true
	_edit.grab_focus()
	focus_changed.emit(true)
	for l: Array in _lines:
		(l[0] as Control).modulate.a = 1.0

func unfocus() -> void:
	_edit.text = ""
	_edit.release_focus()
	_row.visible = false
	focus_changed.emit(false)

func is_active() -> bool:
	return _row.visible

func _send(text: String) -> void:
	var t := text.strip_edges()
	if t != "":
		Net.send(Protocol.C.CHAT, [channel, t.left(140)])
	unfocus()

func _on_chat(ch: int, _peer: int, pname: String, text: String) -> void:
	if not Config.b("game", "chat"):
		return
	add_line("[%s] %s: %s" % [tr(CHANNELS[clampi(ch, 0, 2)]), pname, text], COLORS[clampi(ch, 0, 2)])

func add_line(text: String, color: Color) -> void:
	var p := UiKit.panel("hud", 6.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_feed.add_child(p)
	_lines.append([p, Time.get_ticks_msec()])
	while _lines.size() > 6:
		var old: Array = _lines.pop_front()
		(old[0] as Node).queue_free()

func _process(_delta: float) -> void:
	if _lines.is_empty() or _row.visible:
		return
	var now := Time.get_ticks_msec()
	for l: Array in _lines:
		var age := float(now - int(l[1])) / 1000.0
		(l[0] as Control).modulate.a = clampf((KEEP_S + 2.0 - age) / 2.0, 0.0, 1.0)
	if float(now - int(_lines[0][1])) / 1000.0 > KEEP_S + 2.5:
		var old: Array = _lines.pop_front()
		(old[0] as Node).queue_free()
