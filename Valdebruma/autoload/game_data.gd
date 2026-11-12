extends Node
## GameData — catálogo de datos estáticos del juego (autoload).
##
## Responsabilidad: cargar y exponer los datos de data/*.json (objetos, recetas, botín,
## recolección, estructuras, criaturas, estados, documentos, progresión) y el mapa del mundo.
## Datos: solo lectura; IDs estables. Lo llaman: servidor (reglas) y cliente (presentación).
## Señales: ninguna. Persistencia: ninguna. Autoridad online: los mismos datos en ambos lados;
## el servidor comprueba la versión de protocolo, no confía en datos enviados por el cliente.
## Prueba: tests/test_data.gd valida referencias cruzadas.

var items: Dictionary = {}
var recipes: Dictionary = {}
var loot_tables: Dictionary = {}
var harvest: Dictionary = {}
var structures: Dictionary = {}
var creatures: Dictionary = {}
var effects: Dictionary = {}
var documents: Dictionary = {}
var progression: Dictionary = {}
var world: WorldMap = null
var lang := "es"

func _ready() -> void:
	items = DataFiles.dict("res://data/items.json")
	recipes = DataFiles.dict("res://data/recipes.json")
	loot_tables = DataFiles.dict("res://data/loot_tables.json")
	harvest = DataFiles.dict("res://data/harvest.json")
	structures = DataFiles.dict("res://data/structures.json")
	creatures = DataFiles.dict("res://data/creatures.json")
	effects = DataFiles.dict("res://data/effects.json")
	documents = DataFiles.dict("res://data/documents.json")
	progression = DataFiles.dict("res://data/progression.json")
	world = WorldMap.new()
	world.load_all()

func item(id: String) -> Dictionary:
	return items.get(id, {})

func has_item(id: String) -> bool:
	return items.has(id)

## Texto localizado de un diccionario {"es": ..., "en": ...}.
func text(d: Variant) -> String:
	if d is Dictionary:
		return String((d as Dictionary).get(lang, (d as Dictionary).get("es", "")))
	return String(d)

func item_name(id: String) -> String:
	return text(item(id).get("name", id))

func stack_max(id: String) -> int:
	return int(item(id).get("stack", 1))

func item_weight(id: String) -> float:
	return float(item(id).get("weight", 0.1))

func level_for_xp(xp: int) -> int:
	var levels: Array = progression.get("levels", [0])
	var lvl := 1
	for i in levels.size():
		if xp >= int(levels[i]):
			lvl = i + 1
	return lvl
