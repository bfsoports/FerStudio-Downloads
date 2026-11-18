extends Node
## Catálogo de contenido: carga los JSON de resources/data/ y ofrece consultas tipadas.

const DATA_DIR := "res://resources/data/"

var ingredients: Dictionary = {}
var ingredient_order: Array = []
var recipes: Dictionary = {}
var recipe_order: Array = []
var levels: Array = []
var missions: Array = []
var upgrades: Dictionary = {}
var upgrade_order: Array = []
var shop_items: Array = []
var shop_categories: Array = []
var customer_look: Dictionary = {}
var layout: Dictionary = {}
var load_errors: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	load_errors.clear()
	ingredients.clear()
	ingredient_order.clear()
	recipes.clear()
	recipe_order.clear()
	upgrades.clear()
	upgrade_order.clear()
	for d in _list("ingredients.json"):
		ingredients[str(d["id"])] = d
		ingredient_order.append(str(d["id"]))
	for d in _list("recipes.json"):
		recipes[str(d["id"])] = d
		recipe_order.append(str(d["id"]))
	levels = _list("levels.json")
	missions = _list("missions.json")
	for d in _list("upgrades.json"):
		upgrades[str(d["id"])] = d
		upgrade_order.append(str(d["id"]))
	var shop: Variant = Util.load_json(DATA_DIR + "shop.json")
	if shop is Dictionary:
		shop_items = shop.get("items", [])
		shop_categories = shop.get("categories", [])
	else:
		load_errors.append("shop.json ilegible")
	var cust: Variant = Util.load_json(DATA_DIR + "customers.json")
	customer_look = cust if cust is Dictionary else {}
	var lay: Variant = Util.load_json(DATA_DIR + "layout.json")
	layout = lay if lay is Dictionary else {}
	load_errors.append_array(DataValidator.validate_all({
		"ingredients": ingredients, "recipes": recipes, "levels": levels, "missions": missions,
		"upgrades": upgrades, "shop_items": shop_items, "shop_categories": shop_categories,
	}))
	for e in load_errors:
		push_error("Catalog: %s" % e)

func _list(file_name: String) -> Array:
	var data: Variant = Util.load_json(DATA_DIR + file_name)
	if data is Array:
		return data
	load_errors.append("%s ilegible o no es una lista" % file_name)
	return []

func ingredient(id: String) -> Dictionary:
	return ingredients.get(id, {})

func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})

func level_def(level_id: int) -> Dictionary:
	if level_id >= 1 and level_id <= levels.size():
		return levels[level_id - 1]
	return {}

func shop_item(id: String) -> Dictionary:
	for it in shop_items:
		if str(it["id"]) == id:
			return it
	return {}

func items_in_category(category: String) -> Array:
	var out: Array = []
	for it in shop_items:
		if str(it["category"]) == category:
			out.append(it)
	return out

func default_equipment() -> Dictionary:
	var out: Dictionary = {}
	for cat in shop_categories:
		for it in shop_items:
			if str(it["category"]) == str(cat) and Util.to_int(it["price"]) == 0:
				out[str(cat)] = str(it["id"])
				break
	return out

func name_of(def: Dictionary) -> String:
	return Loc.pick(def.get("name", ""))

func ingredient_name(id: String) -> String:
	return name_of(ingredient(id))

func ingredient_color(id: String) -> Color:
	return Util.html_color(str(ingredient(id).get("color", "#ffffff")))

func cook_config(id: String) -> Dictionary:
	var c: Variant = ingredient(id).get("cook", null)
	return c if c is Dictionary else {}

## Capas (ids de ingredientes de abajo a arriba) para dibujar el icono de una receta.
func recipe_layers(id: String) -> Array:
	var r := recipe(id)
	if str(r.get("kind", "")) == "combo":
		for c in r.get("components", []):
			if str(c.get("type", "")) == "recipe":
				return recipe_layers(str(c.get("id", "")))
		return []
	return r.get("ingredients", [])
