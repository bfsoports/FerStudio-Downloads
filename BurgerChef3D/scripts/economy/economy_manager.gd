extends Node
## Economía central: TODAS las transacciones de monedas pasan por aquí (se validan y se registran).
## También calcula los efectos reales de las mejoras y gestiona la tienda de personalización.

const MAX_LOG := 60

var tx_log: Array = []

# ------------------------------------------------------------------ monedas
func earn(amount: int, reason: String) -> int:
	if amount <= 0:
		return 0
	GameState.coins += amount
	_record("earn", amount, reason)
	Events.coins_changed.emit(GameState.coins, amount)
	GameState.add_stat("coins_earned", amount)
	return amount

func spend(amount: int, reason: String) -> bool:
	if amount < 0 or amount > GameState.coins:
		return false
	if amount == 0:
		return true
	GameState.coins -= amount
	_record("spend", amount, reason)
	Events.coins_changed.emit(GameState.coins, -amount)
	return true

## Descuenta una penalización sin dejar el saldo en negativo. Devuelve lo descontado realmente.
func penalize(amount: int, reason: String) -> int:
	var taken := mini(maxi(amount, 0), GameState.coins)
	if taken > 0:
		spend(taken, reason)
	return taken

func can_afford(amount: int) -> bool:
	return amount <= GameState.coins

func _record(kind: String, amount: int, reason: String) -> void:
	tx_log.append({"t": Time.get_unix_time_from_system(), "kind": kind, "amount": amount, "reason": reason, "balance": GameState.coins})
	if tx_log.size() > MAX_LOG:
		tx_log.pop_front()

# ------------------------------------------------------------------ mejoras
func upgrade_level(id: String) -> int:
	return Util.to_int(GameState.upgrades.get(id, 0))

func upgrade_next_cost(id: String) -> int:
	var costs: Array = Catalog.upgrades.get(id, {}).get("costs", [])
	var lv := upgrade_level(id)
	return Util.to_int(costs[lv]) if lv < costs.size() else -1

func can_buy_upgrade(id: String) -> Dictionary:
	var def: Dictionary = Catalog.upgrades.get(id, {})
	if def.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	if upgrade_level(id) >= Util.to_int(def.get("max_level", 0)):
		return {"ok": false, "reason": "upg.maxed"}
	if GameState.level < Util.to_int(def.get("requires_player_level", 1)):
		return {"ok": false, "reason": "upg.need_level"}
	if GameState.coins < upgrade_next_cost(id):
		return {"ok": false, "reason": "err.no_coins"}
	return {"ok": true, "reason": ""}

func buy_upgrade(id: String) -> Dictionary:
	var chk := can_buy_upgrade(id)
	if not chk["ok"]:
		return chk
	if not spend(upgrade_next_cost(id), "upgrade:" + id):
		return {"ok": false, "reason": "err.no_coins"}
	GameState.upgrades[id] = upgrade_level(id) + 1
	GameState.add_stat("upgrades_bought", 1)
	GameState.set_stat_max("recipes_unlocked", GameState.unlocked_recipe_ids().size())
	Events.upgrade_changed.emit(id, upgrade_level(id))
	SaveManager.request_save()
	return {"ok": true, "reason": ""}

## Valor efectivo de un efecto de mejora (p. ej. "grill_slots") = base + por_nivel * nivel.
func stat_value(effect_stat: String, fallback: float) -> float:
	for id in Catalog.upgrade_order:
		var eff: Dictionary = Catalog.upgrades[id].get("effect", {})
		if str(eff.get("stat", "")) == effect_stat:
			return Util.to_float(eff.get("base", fallback)) + Util.to_float(eff.get("per_level", 0.0)) * upgrade_level(str(id))
	return fallback

func grill_slots() -> int:
	return int(stat_value("grill_slots", 2.0))

func fryer_slots() -> int:
	return int(stat_value("fryer_slots", 1.0))

func cook_speed() -> float:
	return stat_value("cook_speed", 1.0)

func prep_boards() -> int:
	return int(stat_value("prep_boards", 1.0))

func crate_stock() -> int:
	return int(stat_value("crate_stock", 8.0))

func patience_mult() -> float:
	return stat_value("patience_mult", 1.0)

func service_points() -> int:
	return int(stat_value("service_points", 2.0))

func coin_mult() -> float:
	return stat_value("coin_mult", 1.0)

func look_level() -> int:
	return int(stat_value("look_level", 0.0))

## Nivel de la mejora «Recetas nuevas» (0 = sin comprar).
func recipe_pack() -> int:
	return int(stat_value("recipe_pack", 0.0))

## 1 si se compró el «Catálogo de decoración».
func decor_options() -> int:
	return int(stat_value("decor_options", 0.0))

## Multiplicador de la velocidad de lavado del fregadero.
func wash_speed() -> float:
	return stat_value("wash_speed", 1.0)

## Mejoras que se pueden comprar ahora mismo (aviso en el menú principal).
func buyable_upgrades() -> int:
	var n := 0
	for id in Catalog.upgrade_order:
		if bool(can_buy_upgrade(str(id))["ok"]):
			n += 1
	return n

# ------------------------------------------------------------------ tienda de personalización
func can_buy_item(id: String) -> Dictionary:
	var it := Catalog.shop_item(id)
	if it.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	if GameState.owned_items.has(id):
		return {"ok": false, "reason": "shop.owned"}
	if not item_upgrade_ok(it):
		return {"ok": false, "reason": "shop.need_upgrade"}
	if GameState.level < Util.to_int(it.get("unlock_level", 1)):
		return {"ok": false, "reason": "upg.need_level"}
	if GameState.coins < Util.to_int(it.get("price", 0)):
		return {"ok": false, "reason": "err.no_coins"}
	return {"ok": true, "reason": ""}

## true si el artículo no necesita mejora o si ya se compró (artículos del «Catálogo de decoración»).
func item_upgrade_ok(it: Dictionary) -> bool:
	var need := str(it.get("requires_upgrade", ""))
	return need == "" or upgrade_level(need) > 0

## Artículos que ya se pueden comprar (nivel y mejora alcanzados), no comprados y que el jugador aún no ha visto.
func unseen_items() -> Array:
	var out: Array = []
	for it in Catalog.shop_items:
		var id := str(it["id"])
		if GameState.owned_items.has(id) or GameState.seen_items.has(id):
			continue
		if item_upgrade_ok(it) and GameState.level >= Util.to_int(it.get("unlock_level", 1)):
			out.append(id)
	return out

func mark_items_seen() -> void:
	for id in unseen_items():
		GameState.seen_items.append(id)
	SaveManager.request_save()

func buy_item(id: String) -> Dictionary:
	var chk := can_buy_item(id)
	if not chk["ok"]:
		return chk
	var it := Catalog.shop_item(id)
	if not spend(Util.to_int(it.get("price", 0)), "item:" + id):
		return {"ok": false, "reason": "err.no_coins"}
	GameState.owned_items.append(id)
	GameState.add_stat("items_bought", 1)
	SaveManager.request_save()
	return {"ok": true, "reason": ""}

func equip(id: String) -> bool:
	if not GameState.owned_items.has(id):
		return false
	var cat := str(Catalog.shop_item(id).get("category", ""))
	if cat == "":
		return false
	GameState.equipped[cat] = id
	Events.item_equipped.emit(cat, id)
	SaveManager.request_save()
	return true

func equipped_param(category: String, key: String, fallback: Variant) -> Variant:
	var id := str(GameState.equipped.get(category, ""))
	var params: Dictionary = Catalog.shop_item(id).get("params", {})
	return params.get(key, fallback)
