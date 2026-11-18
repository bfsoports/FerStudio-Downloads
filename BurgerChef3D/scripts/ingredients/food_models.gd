class_name FoodModels
extends RefCounted
## Modelos 3D reales de los ingredientes (KayKit Restaurant Bits y Kenney Food Kit, ambos CC0), cargados con ModelLib.
## El origen de cada modelo está en el centro de su base. Los ingredientes sin modelo en esos packs no existen en el juego.

## Modelo de cada fase de cocción ("raw", "done", "burnt") de los ingredientes que se cocinan.
## Si una fase no tiene modelo propio se reutiliza otro: el medallón vegetal quemado usa el medallón carbonizado y
## el bacon o las patatas quemadas usan el modelo cocinado con un tinte oscuro.
const COOK_MODELS: Dictionary = {
	"patty": {"raw": "patty_raw", "done": "patty_done", "burnt": "patty_burnt"},
	"veggie_patty": {"raw": "veggie_raw", "done": "veggie_done", "burnt": "patty_burnt"},
	"bacon": {"raw": "bacon_raw", "done": "bacon_done", "burnt": "bacon_done"},
	"fries": {"raw": "fries_raw", "done": "fries_done", "burnt": "fries_done"},
}
## Modelo de las capas que no se cocinan.
const LAYER_MODELS: Dictionary = {
	"bun_bottom": "bun_bottom", "bun_top": "bun_top", "cheese": "cheese", "lettuce": "lettuce", "tomato": "tomato",
	"onion": "onion",
}
const DARK_DONE := Color(0.42, 0.36, 0.33)   # tinte al que tiende el modelo cocinado justo antes de quemarse
const DARK_BURNT := Color(0.22, 0.19, 0.17)  # tinte del "quemado" cuando se reutiliza el modelo cocinado

static func has_model(id: String) -> bool:
	return COOK_MODELS.has(id) or LAYER_MODELS.has(id) or id == "drink"

## Grosor de una capa dentro de la hamburguesa (altura real del modelo).
static func layer_height(id: String) -> float:
	var key := ""
	if COOK_MODELS.has(id):
		key = str((COOK_MODELS[id] as Dictionary)["done"])
	else:
		key = str(LAYER_MODELS.get(id, ""))
	var h := ModelLib.size_of(key).y
	return h if h > 0.0 else 0.04

static func _cook_times(id: String) -> Vector2:
	var cfg := Catalog.cook_config(id)
	return Vector2(Util.to_float(cfg.get("cook_time", 8.0), 8.0), Util.to_float(cfg.get("burn_time", 8.0), 8.0))

## Fase visual de un alimento cocinable según su progreso: "raw" (crudo o cocinándose), "done" o "burnt".
static func cook_variant(id: String, progress: float) -> String:
	var t := _cook_times(id)
	if progress < t.x:
		return "raw"
	if progress < t.x + t.y:
		return "done"
	return "burnt"

## Cuánto se ha acercado un alimento cocinado a quemarse (0 recién hecho, 1 quemado).
static func _burn_ratio(id: String, progress: float) -> float:
	var t := _cook_times(id)
	return clampf((progress - t.x) / maxf(t.y, 0.01), 0.0, 1.0)

## Progreso equivalente a un estado (para dibujar capas ya cocinadas dentro de una hamburguesa).
static func progress_for_state(id: String, state: int) -> float:
	var cfg := Catalog.cook_config(id)
	if cfg.is_empty():
		return 0.0
	var t := _cook_times(id)
	match state:
		FoodItem.State.COOKED:
			return t.x + 0.5
		FoodItem.State.BURNT:
			return t.x + t.y
		FoodItem.State.COOKING:
			return t.x * 0.5
	return 0.0

static func build_item(id: String, progress: float = 0.0) -> Node3D:
	var root := Node3D.new()
	if id == "drink":
		root.add_child(ModelLib.spawn("drink"))
	else:
		add_layer(root, id, 0.0, progress, 0)
	return root

## Actualiza el aspecto de un alimento que se está cocinando: cambia de modelo al pasar de crudo a cocinado y a
## quemado, y oscurece poco a poco el cocinado a medida que se acerca a quemarse.
static func apply_cook_color(visual: Node3D, id: String, progress: float) -> void:
	if visual == null or not visual.has_meta("cook_holder"):
		return
	var stored: Variant = visual.get_meta("cook_holder")
	if not is_instance_valid(stored):
		return
	_refresh_cook(stored as Node3D, id, progress)

static func _refresh_cook(holder: Node3D, id: String, progress: float) -> void:
	var variant := cook_variant(id, progress)
	if str(holder.get_meta("cook_variant", "")) != variant:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		holder.add_child(_cook_model(id, variant, progress))
		holder.set_meta("cook_variant", variant)
	elif variant == "done" and holder.get_child_count() > 0:
		ModelLib.tint(holder.get_child(0), Color.WHITE.lerp(DARK_DONE, _burn_ratio(id, progress)))

static func _cook_model(id: String, variant: String, progress: float) -> Node3D:
	var keys: Dictionary = COOK_MODELS[id]
	var key := str(keys[variant])
	var node: Node3D = null
	if id == "bacon":
		node = _bacon(key)
	else:
		node = ModelLib.spawn(key)
	if variant == "done":
		ModelLib.tint(node, Color.WHITE.lerp(DARK_DONE, _burn_ratio(id, progress)))
	elif variant == "burnt" and key == str(keys["done"]):
		ModelLib.tint(node, DARK_BURNT)
	return node

## Dos tiras de bacon una junto a la otra (cada tira del pack mide unos 12 cm de ancho).
static func _bacon(key: String) -> Node3D:
	var node := Node3D.new()
	var a := ModelLib.spawn(key)
	a.position = Vector3(-0.085, 0.0, 0.0)
	a.rotation.y = 0.1
	node.add_child(a)
	var b := ModelLib.spawn(key)
	b.position = Vector3(0.085, 0.0, 0.0)
	b.rotation.y = -0.08
	node.add_child(b)
	return node

## Añade al nodo el modelo de una capa de hamburguesa cuya base está a la altura y.
static func add_layer(root: Node3D, id: String, y: float, progress: float, index: int) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0.0, y, 0.0)
	holder.rotation.y = float(index) * 0.9
	root.add_child(holder)
	if COOK_MODELS.has(id):
		root.set_meta("cook_holder", holder)
		_refresh_cook(holder, id, progress)
		return
	var key := str(LAYER_MODELS.get(id, ""))
	if key == "":
		push_error("FoodModels: el ingrediente '%s' no tiene modelo 3D" % id)
		return
	holder.add_child(ModelLib.spawn(key))
