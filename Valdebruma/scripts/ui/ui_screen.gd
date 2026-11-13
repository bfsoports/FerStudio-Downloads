class_name UiScreen
extends Control
## UiScreen — base de las pantallas a pantalla completa (menús, inventario, mapa, ajustes…).
##
## Responsabilidad: fondo atenuado, marco con título y botón de cerrar/volver, respeto de las
## zonas seguras (muescas y esquinas redondeadas) y ciclo setup() → refresh(). Las pantallas
## no guardan estado de juego: leen de Session/Config/Profile y envían peticiones.

var args: Dictionary = {}
var screen_name := ""
var body: VBoxContainer
var header: HBoxContainer
var title_label: Label
var _frame: PanelContainer
var _dim: ColorRect

## dim: opacidad del fondo; wide: fracción de pantalla que ocupa el marco (0 = ajustado al contenido).
func frame(title_text: String, dim := 0.6, max_width := 1180.0, icon_name := "") -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.04, 0.035, dim)
	UiKit.full_rect(_dim)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var safe := Ui.safe_margins()
	var m := UiKit.margin(null, int(safe.position.x) + 18, int(safe.position.y) + 14, int(safe.size.x) + 18, int(safe.size.y) + 14)
	UiKit.full_rect(m)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	_frame = UiKit.panel("panel", 18.0)
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.custom_minimum_size = Vector2(minf(max_width, 600.0), 0)
	center.add_child(_frame)
	if max_width > 0.0:
		_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_frame.custom_minimum_size.x = minf(max_width, get_viewport_rect().size.x - 36.0 - safe.position.x - safe.size.x)
	var v := UiKit.vbox(12)
	_frame.add_child(v)
	header = UiKit.hbox(12)
	v.add_child(header)
	if icon_name != "":
		header.add_child(UiKit.icon_rect(icon_name, 30, UiKit.C_ACCENT))
	title_label = UiKit.title(title_text, 32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(UiKit.icon_button("close", func() -> void: Ui.close_top(), 52, "ghost"))
	v.add_child(UiKit.line())
	body = UiKit.vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

## Se llama una vez al abrir (args ya asignado).
func setup() -> void:
	pass

## Se llama cuando cambian los datos que muestra.
func refresh() -> void:
	pass

## Devuelve true si la pantalla consume el «atrás» (por ejemplo, para cerrar un subpanel).
func on_back() -> bool:
	return false

func on_close() -> void:
	pass
