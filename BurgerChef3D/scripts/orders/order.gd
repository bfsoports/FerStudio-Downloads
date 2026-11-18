class_name Order
extends RefCounted
## Un pedido de un cliente: receta, componentes a entregar, paciencia, estado y recompensa.

enum State { CREATED, WAITING, PREPARING, READY, DELIVERED, CANCELLED }

var id: int = 0
var recipe_id: String = ""
var components: Array = []          # [{"type": "burger", "recipe": id} | {"type": "item", "id": id}]
var state: int = State.CREATED
var patience_total: float = 60.0
var patience_left: float = 60.0
var customer: Node = null
var service_point: ServicePoint = null
var price: int = 0
var penalty: int = 0
var satisfaction: float = 0.0
var warned: bool = false

func patience_ratio() -> float:
	return clampf(patience_left / maxf(patience_total, 0.001), 0.0, 1.0)

func is_open() -> bool:
	return state != State.DELIVERED and state != State.CANCELLED

func recipe_name() -> String:
	return Catalog.name_of(Catalog.recipe(recipe_id))

func state_key() -> String:
	match state:
		State.CREATED:
			return "order.created"
		State.WAITING:
			return "order.waiting"
		State.PREPARING:
			return "order.preparing"
		State.READY:
			return "order.ready"
		State.DELIVERED:
			return "order.delivered"
	return "order.cancelled"

static func components_for(recipe: Dictionary) -> Array:
	var out: Array = []
	if str(recipe.get("kind", "")) == "combo":
		for c in recipe.get("components", []):
			if str(c.get("type", "")) == "recipe":
				out.append({"type": "burger", "recipe": str(c.get("id", ""))})
			else:
				out.append({"type": "item", "id": str(c.get("id", ""))})
	else:
		out.append({"type": "burger", "recipe": str(recipe.get("id", ""))})
	return out
