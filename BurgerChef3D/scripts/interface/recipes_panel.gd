class_name RecipesPanel
extends Control
## Panel de recetas durante la partida: muestra las recetas disponibles en este turno con su composición y reglas.
## Se dimensiona con el lienzo disponible y se recoloca si cambia el tamaño de la interfaz.

signal closed

const MIN_LARGE_W := 430.0   # ancho mínimo de una tarjeta grande para ponerlas en dos columnas

var _recipe_ids: Array = []
var _frame: ContentFrame = null

func _init(recipe_ids: Array = []) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_recipe_ids = recipe_ids

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := PanelContainer.new()
	dim.theme_type_variation = "PanelDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	Events.ui_scale_changed.connect(_on_resized)
	_build()

func _on_resized() -> void:
	call_deferred("_build")

func _build() -> void:
	if _frame != null:
		_frame.queue_free()
	_frame = UIKit.frame(1500.0)
	add_child(_frame)
	var margin := UIKit.margin_container(self, 12)
	_frame.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var avail := UIKit.canvas_size(self)
	var win_w := minf(1220.0, avail.x - 28.0)
	var inner := win_w - 42.0
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(win_w, minf(720.0, avail.y - 28.0))
	center.add_child(panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect("book", 52))
	var title := UIKit.label(Loc.t("recipes.title"), "LabelHeader", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var close := UIKit.icon_button("close", "ButtonIcon", 62)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	v.add_child(head)
	v.add_child(UIKit.divider())
	# tarjetas grandes que ocupan el ancho del panel: una sola receta usa todo el ancho; con varias, dos columnas si
	# caben (cada una de al menos MIN_LARGE_W) y si no, una debajo de otra
	var inner_w := inner - 14.0   # hueco para la barra de desplazamiento
	var cols := 1
	if _recipe_ids.size() > 1 and inner_w >= 2.0 * MIN_LARGE_W + 14.0:
		cols = 2
	var card_w := floorf((inner_w - 14.0 * float(cols - 1)) / float(cols))
	var grid := UIKit.grid(cols, 14, 14)
	for rid in _recipe_ids:
		grid.add_child(RecipeCard.build_large(str(rid), card_w))
	var sc := UIKit.scroll(UIKit.centered(grid))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("recipes"):
		get_viewport().set_input_as_handled()
		closed.emit()
