extends Node
## Estado persistente del jugador (monedas, experiencia, progreso, mejoras, personalización, estadísticas).
## Solo guarda datos; las reglas de compra viven en EconomyManager y el guardado en SaveManager.

var coins: int = 0
var xp: int = 0
var level: int = 1
var level_stars: Dictionary = {}       # "id de nivel" -> estrellas (0-3)
var highest_unlocked: int = 1
var upgrades: Dictionary = {}          # id de mejora -> nivel
var owned_items: Array = []
var equipped: Dictionary = {}          # categoría -> id de artículo
var stats: Dictionary = {}
var records: Dictionary = {}
var missions: Dictionary = {}          # id -> {"claimed": bool, "notified": bool}
var tutorial_done: bool = false
var tutorial_step: int = 0
var tutorial_prompted: bool = false    # ya se ofreció el tutorial al pulsar JUGAR por primera vez
var ad_coins_at: int = 0               # hora (unix) del último regalo de monedas por anuncio
var seen_recipes: Array = []           # recetas desbloqueadas que el jugador ya ha visto (aviso «nuevo» en el menú)
var seen_items: Array = []             # artículos de la tienda disponibles que el jugador ya ha visto
var initialized: bool = false          # true cuando existe una partida válida (evita guardar datos vacíos por error)
## false durante el tutorial: lo que se hace allí no cuenta para estadísticas, misiones ni logros (no se guarda).
var tracking_enabled: bool = true

func _ready() -> void:
	reset_to_defaults()
	initialized = false

func reset_to_defaults() -> void:
	coins = 0
	xp = 0
	level = 1
	level_stars = {}
	highest_unlocked = 1
	upgrades = {}
	equipped = Catalog.default_equipment()
	owned_items = []
	for item_id in equipped.values():
		owned_items.append(str(item_id))
	stats = {}
	records = {}
	missions = {}
	tutorial_done = false
	tutorial_step = 0
	tutorial_prompted = false
	ad_coins_at = 0
	seen_recipes = unlocked_recipe_ids()
	seen_items = []
	initialized = true

# ------------------------------------------------------------------ experiencia
func xp_needed(lv: int) -> int:
	return 80 + 40 * (lv - 1)

func add_xp(amount: int) -> void:
	if amount <= 0 or level >= Const.MAX_PLAYER_LEVEL:
		return
	xp += amount
	while xp >= xp_needed(level) and level < Const.MAX_PLAYER_LEVEL:
		xp -= xp_needed(level)
		level += 1
		Events.level_up.emit(level)
	if level >= Const.MAX_PLAYER_LEVEL:
		xp = 0
	set_stat_max("player_level", level)
	Events.xp_changed.emit(level, xp, xp_needed(level))

# ------------------------------------------------------------------ estadísticas
func stat(key: String) -> int:
	return Util.to_int(stats.get(key, 0))

func add_stat(key: String, amount: int = 1) -> void:
	if amount == 0 or not tracking_enabled:
		return
	stats[key] = stat(key) + amount
	Events.stat_changed.emit(key, stat(key))

func set_stat_max(key: String, value: int) -> void:
	if not tracking_enabled:
		return
	if value > stat(key):
		stats[key] = value
		Events.stat_changed.emit(key, value)

# ------------------------------------------------------------------ niveles y recetas
func stars_for(level_id: int) -> int:
	return Util.to_int(level_stars.get(str(level_id), 0))

func total_stars() -> int:
	var total := 0
	for k in level_stars:
		total += Util.to_int(level_stars[k])
	return total

func is_level_unlocked(level_id: int) -> bool:
	return level_id >= 1 and level_id <= highest_unlocked

func unlocked_recipe_ids() -> Array:
	var out: Array = []
	for rid in Catalog.recipe_order:
		if Util.to_int(Catalog.recipes[rid].get("unlock_level", 999)) <= highest_unlocked and recipe_upgrade_ok(str(rid)):
			out.append(rid)
	return out

## true si la receta no depende de ninguna mejora o si ya se compró el nivel de mejora que pide («Recetas nuevas»).
func recipe_upgrade_ok(recipe_id: String) -> bool:
	var ru: Variant = Catalog.recipe(recipe_id).get("requires_upgrade", null)
	if not (ru is Dictionary):
		return true
	var rd: Dictionary = ru
	return Util.to_int(upgrades.get(str(rd.get("id", "")), 0)) >= Util.to_int(rd.get("level", 1), 1)

## Recetas de un nivel de campaña: las recetas de mejora compradas que ya están disponibles en él y después su lista
## fija. Las de mejora van delante porque el generador de pedidos favorece las dos últimas de la lista (las más nuevas
## del nivel, de las que suelen depender sus objetivos).
func campaign_recipes(level_id: int) -> Array:
	var base: Array = Catalog.level_def(level_id).get("recipes", [])
	var out: Array = []
	for rid in Catalog.recipe_order:
		var r: Dictionary = Catalog.recipes[rid]
		if r.has("requires_upgrade") and recipe_upgrade_ok(str(rid)) and Util.to_int(r.get("unlock_level", 999)) <= level_id and not base.has(rid):
			out.append(rid)
	out.append_array(base)
	return out

## Recetas desbloqueadas que el jugador aún no ha visto en el libro de recetas.
func unseen_recipes() -> Array:
	var out: Array = []
	for rid in unlocked_recipe_ids():
		if not seen_recipes.has(rid):
			out.append(rid)
	return out

func mark_recipes_seen() -> void:
	for rid in unlocked_recipe_ids():
		if not seen_recipes.has(rid):
			seen_recipes.append(rid)
	SaveManager.request_save()

func is_recipe_unlocked(recipe_id: String) -> bool:
	return unlocked_recipe_ids().has(recipe_id)

## Registra el resultado de un nivel de campaña ganado. Devuelve si fue la primera vez y las estrellas nuevas.
func complete_level(level_id: int, stars: int) -> Dictionary:
	var prev := stars_for(level_id)
	var new_stars := clampi(stars, 1, 3)
	if new_stars > prev:
		level_stars[str(level_id)] = new_stars
	if level_id >= highest_unlocked and level_id < Catalog.levels.size():
		highest_unlocked = level_id + 1
	_refresh_level_stats()
	return {"first_time": prev == 0, "stars_gained": maxi(0, new_stars - prev)}

func _refresh_level_stats() -> void:
	var done := 0
	var total := 0
	var three := 0
	for k in level_stars:
		var s := Util.to_int(level_stars[k])
		if s > 0:
			done += 1
			total += s
		if s >= 3:
			three += 1
	set_stat_max("levels_completed", done)
	set_stat_max("stars_total", total)
	set_stat_max("three_star_levels", three)
	set_stat_max("recipes_unlocked", unlocked_recipe_ids().size())

# ------------------------------------------------------------------ serialización
func to_dict() -> Dictionary:
	return {
		"version": Const.SAVE_VERSION,
		"coins": coins, "xp": xp, "level": level,
		"level_stars": level_stars.duplicate(true), "highest_unlocked": highest_unlocked,
		"upgrades": upgrades.duplicate(true), "owned_items": owned_items.duplicate(),
		"equipped": equipped.duplicate(), "stats": stats.duplicate(), "records": records.duplicate(),
		"missions": missions.duplicate(true), "tutorial_done": tutorial_done, "tutorial_step": tutorial_step,
		"tutorial_prompted": tutorial_prompted, "ad_coins_at": ad_coins_at, "seen_recipes": seen_recipes.duplicate(), "seen_items": seen_items.duplicate(),
	}

## Carga datos validando tipos y rangos; cualquier campo ausente o inválido recibe su valor por defecto.
func from_dict(d: Dictionary) -> void:
	reset_to_defaults()
	coins = maxi(0, Util.to_int(d.get("coins", 0)))
	level = clampi(Util.to_int(d.get("level", 1), 1), 1, Const.MAX_PLAYER_LEVEL)
	xp = maxi(0, Util.to_int(d.get("xp", 0)))
	var raw_stars: Variant = d.get("level_stars", {})
	if raw_stars is Dictionary:
		for k in raw_stars:
			var lid := Util.to_int(k, 0)
			if lid >= 1 and lid <= Catalog.levels.size():
				level_stars[str(lid)] = clampi(Util.to_int(raw_stars[k]), 0, 3)
	highest_unlocked = clampi(Util.to_int(d.get("highest_unlocked", 1), 1), 1, maxi(1, Catalog.levels.size()))
	for lid_key in level_stars:
		if Util.to_int(lid_key) + 1 > highest_unlocked and Util.to_int(level_stars[lid_key]) > 0:
			highest_unlocked = mini(Util.to_int(lid_key) + 1, Catalog.levels.size())
	var raw_up: Variant = d.get("upgrades", {})
	if raw_up is Dictionary:
		for uid in Catalog.upgrades:
			var max_l := Util.to_int(Catalog.upgrades[uid].get("max_level", 0))
			var lv := clampi(Util.to_int(raw_up.get(uid, 0)), 0, max_l)
			if lv > 0:
				upgrades[uid] = lv
	var raw_owned: Variant = d.get("owned_items", [])
	if raw_owned is Array:
		for it in raw_owned:
			if not Catalog.shop_item(str(it)).is_empty() and not owned_items.has(str(it)):
				owned_items.append(str(it))
	var raw_eq: Variant = d.get("equipped", {})
	if raw_eq is Dictionary:
		for cat in Catalog.shop_categories:
			var cand := str(raw_eq.get(cat, ""))
			if owned_items.has(cand) and str(Catalog.shop_item(cand).get("category", "")) == str(cat):
				equipped[str(cat)] = cand
	_load_counters(d.get("stats", {}), stats)
	_load_counters(d.get("records", {}), records)
	var raw_m: Variant = d.get("missions", {})
	if raw_m is Dictionary:
		for mid in raw_m:
			var e: Variant = raw_m[mid]
			if e is Dictionary:
				missions[str(mid)] = {"claimed": Util.to_bool(e.get("claimed", false)), "notified": Util.to_bool(e.get("notified", false))}
	tutorial_done = Util.to_bool(d.get("tutorial_done", false))
	tutorial_step = maxi(0, Util.to_int(d.get("tutorial_step", 0)))
	tutorial_prompted = Util.to_bool(d.get("tutorial_prompted", tutorial_done))
	ad_coins_at = clampi(Util.to_int(d.get("ad_coins_at", 0)), 0, int(Time.get_unix_time_from_system()) + 60)
	# en partidas anteriores a los avisos de novedades, todo lo ya desbloqueado se da por visto
	seen_recipes = _id_list(d.get("seen_recipes", null), Catalog.recipes.keys(), unlocked_recipe_ids())
	var item_ids: Array = []
	for it in Catalog.shop_items:
		item_ids.append(str(it["id"]))
	seen_items = _id_list(d.get("seen_items", null), item_ids, [])
	initialized = true

## Lista de ids válidos leída del guardado (o fallback si el campo no existe).
func _id_list(raw: Variant, valid: Array, fallback: Array) -> Array:
	if not (raw is Array):
		return fallback.duplicate()
	var out: Array = []
	for v in raw:
		if valid.has(str(v)) and not out.has(str(v)):
			out.append(str(v))
	return out

func _load_counters(raw: Variant, target: Dictionary) -> void:
	if raw is Dictionary:
		for k in raw:
			target[str(k)] = maxi(0, Util.to_int(raw[k]))
