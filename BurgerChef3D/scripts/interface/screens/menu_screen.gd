class_name MenuScreen
extends Control
## Base de las pantallas del menú (mejoras, recetas, misiones, personalización...): una ventana centrada con cabecera
## (icono, título, monedas y botón de cierre). El tamaño de la ventana se calcula con el lienzo disponible y se vuelve
## a calcular al cambiar de pantalla o de tamaño de interfaz; el contenido usa _inner_w para repartir columnas.

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
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := UIKit.frame(1500.0)
	add_child(frame)
	var margin := UIKit.margin_container(self, 12)
	frame.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	_panel = UIKit.card()
	_apply_window_size()
	center.add_child(_panel)
	var v := UIKit.vbox(10)
	_panel.add_child(v)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect(icon_name, 52))
	var title := UIKit.label(Loc.t(title_key), "LabelHeader", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var chip := UIKit.coin_chip(GameState.coins, 30)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coin_label = UIKit.chip_label(chip)
	head.add_child(chip)
	var close := UIKit.icon_button("close", "ButtonIcon", 70)
	close.pressed.connect(func() -> void: back_requested.emit())
	head.add_child(close)
	v.add_child(head)
	v.add_child(UIKit.divider())
	_body = UIKit.vbox(12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	Events.coins_changed.connect(_on_coins)
	Events.ui_scale_changed.connect(_on_resized)
	get_viewport().size_changed.connect(_on_resized)
	_build(_body)

## Calcula el tamaño de la ventana con el lienzo disponible (nunca más grande que la pantalla).
func _apply_window_size() -> void:
	var avail := UIKit.canvas_size(self)
	var w := minf(WINDOW_W, avail.x - 2.0 * WINDOW_MARGIN)
	var h := minf(WINDOW_H, avail.y - 2.0 * WINDOW_MARGIN)
	_panel.custom_minimum_size = Vector2(w, h)
	_inner_w = w - 2.0 * PAD - 6.0
	_inner_h = h - 2.0 * PAD - 6.0 - HEADER_H

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
