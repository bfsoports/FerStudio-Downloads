class_name RecipesPanel
extends Control
## Panel de recetas durante la partida: muestra las recetas disponibles en este turno con su composición y reglas.
## Ocupa la pantalla completa y se recoloca si cambia el tamaño de la pantalla o de la interfaz.

signal closed

const MIN_LARGE_W := 520.0   # ancho mínimo de una tarjeta grande para ponerlas en varias columnas

var _recipe_ids: Array = []
var _shell_root: Control = null

func _init(recipe_ids: Array = []) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_recipe_ids = recipe_ids

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Events.ui_scale_changed.connect(_on_resized)
	get_viewport().size_changed.connect(_on_resized)
	_build()

func _on_resized() -> void:
	call_deferred("_build")

## Pantalla completa: una sola receta ocupa todo el ancho; con varias, dos (o tres en pantallas muy anchas) columnas.
func _build() -> void:
	if _shell_root != null:
		_shell_root.queue_free()
	var shell := UIKit.screen_shell(self, Loc.t("recipes.title"), "book", false, func() -> void: closed.emit())
	_shell_root = shell["root"]
	var body: VBoxContainer = shell["body"]
	var inner := UIKit.screen_inner_size(self)
	var cols := 1
	if _recipe_ids.size() > 1:
		cols = int(UIKit.fill_columns(inner.x, MIN_LARGE_W, 14.0, mini(3, _recipe_ids.size()))[0])
	var card_w := floorf((inner.x - 14.0 * float(cols - 1)) / float(cols))
	var grid := UIKit.grid(cols, 14, 14)
	for rid in _recipe_ids:
		grid.add_child(RecipeCard.build_large(str(rid), card_w, inner.y - 20.0))
	var sc := UIKit.scroll(UIKit.centered(grid))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("recipes"):
		get_viewport().set_input_as_handled()
		closed.emit()
