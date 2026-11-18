class_name RewardCalc
extends RefCounted
## Fórmulas de recompensas, penalizaciones y satisfacción (funciones puras, fáciles de probar).

## Monedas de un pedido: precio * calidad + propina por rapidez (solo si es correcto), con bonificaciones.
static func payout(base_price: int, quality: float, ok: bool, patience_ratio: float, coin_mult: float, mode_factor: float) -> Dictionary:
	var tip := 0
	if ok:
		tip = int(round(base_price * 0.4 * clampf(patience_ratio, 0.0, 1.0)))
	var coins := int(round((base_price * quality + tip) * coin_mult * mode_factor))
	return {"coins": maxi(coins, 0), "tip": tip}

static func xp_for(recipe_xp: int, quality: float, mode_factor: float) -> int:
	return maxi(1, int(round(recipe_xp * quality * mode_factor)))

static func satisfaction(quality: float, patience_ratio: float) -> float:
	return clampf(quality * (0.55 + 0.45 * clampf(patience_ratio, 0.0, 1.0)), 0.0, 1.0)

static func expire_penalty(base_price: int) -> int:
	return int(ceil(base_price * 0.3))

static func wrong_penalty(base_price: int) -> int:
	return int(ceil(base_price * 0.15))

static func burn_penalty() -> int:
	return 2
