class_name FoodItem
extends Carryable
## Ingrediente individual (objeto 3D real) con estado de cocción.

enum State { RAW, COOKING, COOKED, BURNT }

var ingredient_id: String = ""
var state: int = State.RAW
var cook_progress: float = 0.0
var _visual: Node3D = null
var _vis_timer := 0.0

func setup(id: String) -> FoodItem:
	ingredient_id = id
	var stackable := bool(Catalog.ingredient(id).get("stackable", true))
	if stackable:
		add_box_collider(Vector3(0.5, 0.2, 0.5), Vector3(0, 0.1, 0))
	else:
		add_box_collider(Vector3(0.34, 0.3, 0.34), Vector3(0, 0.15, 0))
	rebuild_visual()
	return self

func rebuild_visual() -> void:
	if _visual != null:
		_visual.queue_free()
	_visual = FoodModels.build_item(ingredient_id, cook_progress)
	add_child(_visual)

func is_cookable() -> bool:
	return not Catalog.cook_config(ingredient_id).is_empty()

static func state_for(progress: float, cook_time: float, burn_time: float) -> int:
	if progress <= 0.0:
		return State.RAW
	if progress < cook_time:
		return State.COOKING
	if progress < cook_time + burn_time:
		return State.COOKED
	return State.BURNT

## Avanza la cocción. Devuelve true si cambió de estado (crudo -> cocinándose -> cocinado -> quemado).
func advance_cooking(delta: float, speed: float) -> bool:
	var cfg := Catalog.cook_config(ingredient_id)
	if cfg.is_empty() or state == State.BURNT:
		return false
	cook_progress += delta * speed
	var new_state := state_for(cook_progress, Util.to_float(cfg.get("cook_time", 8.0), 8.0), Util.to_float(cfg.get("burn_time", 8.0), 8.0))
	_vis_timer += delta
	var changed := new_state != state
	if _vis_timer >= 0.2 or changed:
		_vis_timer = 0.0
		FoodModels.apply_cook_color(_visual, ingredient_id, cook_progress)
	state = new_state
	return changed

## Calidad de la cocción: 1.0 si se retiró en su punto, 0.85 si se pasó un poco, 0.0 si no está cocinado.
func doneness_quality() -> float:
	if not is_cookable():
		return 1.0
	if state != State.COOKED:
		return 0.0
	var cfg := Catalog.cook_config(ingredient_id)
	var over := cook_progress - Util.to_float(cfg.get("cook_time", 8.0), 8.0)
	return 1.0 if over <= Util.to_float(cfg.get("burn_time", 8.0), 8.0) * 0.6 else 0.85

func state_text() -> String:
	if not is_cookable():
		return ""
	match state:
		State.RAW:
			return Loc.t("state.raw")
		State.COOKING:
			return Loc.t("state.cooking")
		State.COOKED:
			return Loc.t("state.cooked")
	return Loc.t("state.burnt")

func display_name() -> String:
	var n := Catalog.ingredient_name(ingredient_id)
	var st := state_text()
	return n if st == "" else "%s (%s)" % [n, st]

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null:
		return {}
	if p.held == null:
		return {"icon": "grab", "text": "prompt.take", "args": [display_name()]}
	if station != null:
		return station.get_prompt(player)
	return {}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null:
		return
	if p.held != null:
		if station != null:
			station.interact(player)
		return
	if station != null:
		station.release(self)
	p.hold(self)
	AudioManager.play_sfx("pickup")
	Events.item_picked.emit(ingredient_id)
