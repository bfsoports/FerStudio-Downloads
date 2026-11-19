class_name MenuScreen
extends Control
## Base de las pantallas del menú (mejoras, recetas, misiones, personalización...): ocupan la pantalla completa, con
## una barra de cabecera (icono, título, monedas y botón de cierre) y el cuerpo debajo. Las medidas se recalculan al
## cambiar de tamaño de pantalla o de interfaz; el contenido usa _inner_w para repartir columnas y llenar el ancho.

signal back_requested
@warning_ignore("unused_signal")   # la emiten las pantallas hijas (selección de nivel), no esta clase base
signal play_requested(params: Dictionary)

const WINDOW_W := 1220.0
const WINDOW_H := 720.0
const WINDOW_MARGIN := 14.0   # hueco mínimo entre la ventana y el borde de la pantalla
const PAD := 18.0             # margen interior de la ventana (ver UITheme)
const HEADER_H := 84.0        # cabecera de la ventana y su separador

var title_key: String = ""
var icon_name: String = "home"
var _body: VBoxContainer
var _coin_label: Label
var _panel: PanelContainer
var _inner_w := 940.0         # ancho útil dentro de la ventana
var _inner_h := 440.0         # alto útil del cuerpo (bajo la cabecera)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shell := UIKit.screen_shell(self, Loc.t(title_key), icon_name, true, func() -> void: back_requested.emit())
	_panel = shell["root"]
	_coin_label = shell["coin_label"]
	_body = shell["body"]
	_apply_window_size()
	Events.coins_changed.connect(_on_coins)
	Events.ui_scale_changed.connect(_on_resized)
	get_viewport().size_changed.connect(_on_resized)
	_build(_body)

## Medidas útiles del cuerpo de la pantalla (ocupa toda la pantalla menos la cabecera y la zona segura).
func _apply_window_size() -> void:
	var inner := UIKit.screen_inner_size(self)
	_inner_w = inner.x
	_inner_h = inner.y

func _on_resized() -> void:
	call_deferred("_relayout")

func _relayout() -> void:
	if _panel == null or _body == null:
		return
	_apply_window_size()
	refresh()

func _on_coins(total: int, _delta: int) -> void:
	_coin_label.text = str(total)

## Las pantallas hijas construyen su contenido aquí.
func _build(_body_node: VBoxContainer) -> void:
	pass

## Reconstruye el contenido (tras comprar, reclamar, cambiar de pestaña o de tamaño de pantalla...).
func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_build(_body)

## Fila de pestañas centrada, de botones de ancho fijo. Cada opción es un texto o una pareja [icono, texto].
func tab_row(options: Array, selected: int, on_pick: Callable, w: float = 200.0) -> HBoxContainer:
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	var tab_w := minf(w, floorf((_inner_w - 8.0 * float(options.size() - 1)) / float(options.size())))
	for i in options.size():
		var opt: Variant = options[i]
		var b: Button = null
		if opt is Array:
			b = UIKit.icon_text_button(str((opt as Array)[0]), str((opt as Array)[1]), "ButtonToggle", UIKit.H_SMALL, tab_w, 30)
		else:
			b = UIKit.button(str(opt), "ButtonToggle", UIKit.H_SMALL, tab_w)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.pressed.connect(func() -> void: on_pick.call(i))
		h.add_child(b)
	return h
