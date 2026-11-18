class_name RecipesScreen
extends MenuScreen
## Catálogo de recetas: las desbloqueadas muestran su composición y reglas; las bloqueadas, cómo conseguirlas.
## Tarjetas de ancho fijo en dos columnas.

func _init() -> void:
	title_key = "menu.recipes"
	icon_name = "book"

func _build(body: VBoxContainer) -> void:
	var cols := 2 if _inner_w >= 2.0 * 360.0 + 14.0 else 1
	var card_w := UIKit.fit_width(_inner_w, cols, 14, 470.0)
	var grid := UIKit.grid(cols, 14, 14)
	var unseen := GameState.unseen_recipes()
	for rid in Catalog.recipe_order:
		grid.add_child(RecipeCard.build(str(rid), not GameState.is_recipe_unlocked(str(rid)), card_w, unseen.has(rid)))
	body.add_child(UIKit.scroll(UIKit.centered(grid)))
	# al abrir el libro, las recetas nuevas dejan de avisar en el menú principal (se marcan en esta visita)
	GameState.mark_recipes_seen()
