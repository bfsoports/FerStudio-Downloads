class_name CookStation
extends Station
## Plancha y freidora. Cada ranura cocina de verdad el alimento colocado: CRUDO -> COCINÁNDOSE -> COCINADO -> QUEMADO.
## La capacidad y la velocidad dependen de las mejoras compradas. Muestra barra 3D, texto de estado, humo y sonido.

var capacity: int = 2
var _bars: Array = []
var _smoke: Array = []
var _locks: Array = []
var slot_props: Array = []      # Node3D opcional por ranura (p. ej. cada freidora): solo se ve si la ranura está desbloqueada
var _last_state: Array = []
var _sizzle: AudioStreamPlayer3D = null
var _sizzling := false
## En el tutorial la comida cocinada no llega a quemarse (se detiene a mitad de su margen) para aprender sin prisa.
var burn_protect: bool = false

## offsets: posiciones locales (X, Z) de las ranuras como Vector2 (también vale un número suelto = solo X);
## slot_y: altura de la superficie de cocción; lock_y: altura de la marca oscura de ranura bloqueada (por defecto,
## slot_y). La freidora la baja a la encimera porque la freidora bloqueada no se ve y la marca quedaría flotando.
func configure(station_kind: String, offsets: Array, slot_y: float, lock_y: float = -1.0) -> void:
	var mark_y := slot_y if lock_y < 0.0 else lock_y
	kind = station_kind
	for off in offsets:
		var x := 0.0
		var z := 0.0
		if off is Vector2:
			x = (off as Vector2).x
			z = (off as Vector2).y
		else:
			x = float(off)
		add_slot(Vector3(x, slot_y, z))
		var bar := Bar3D.new(0.5, true)
		bar.position = Vector3(x, slot_y + 0.45, z)
		bar.show_bar(false)
		add_child(bar)
		_bars.append(bar)
		var smoke := _make_smoke()
		smoke.position = Vector3(x, slot_y + 0.1, z)
		add_child(smoke)
		_smoke.append(smoke)
		_locks.append(Prims.box(self, Vector3(0.5, 0.012, 0.5), Vector3(x, mark_y + 0.006, z), Prims.mat(Color(0.2, 0.15, 0.13)), false))
		_last_state.append(-1)
	Events.upgrade_changed.connect(_on_upgrade_changed)
	refresh_capacity()

func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 8
	p.lifetime = 1.3
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.color = Color(1, 1, 1, 0.3)
	p.local_coords = false
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	sm.material = m
	p.mesh = sm
	return p

func _on_upgrade_changed(_id: String, _level: int) -> void:
	refresh_capacity()

func refresh_capacity() -> void:
	var want := EconomyManager.grill_slots() if kind == "grill" else EconomyManager.fryer_slots()
	capacity = clampi(want, 1, maxi(1, slot_nodes.size()))
	for i in _locks.size():
		(_locks[i] as MeshInstance3D).visible = i >= capacity
	for i in slot_props.size():
		var prop := slot_props[i] as Node3D
		if prop != null:
			prop.visible = i < capacity

func slot_enabled(idx: int) -> bool:
	return idx < capacity

func reject_reason(item: Carryable) -> String:
	var fi := item as FoodItem
	if fi == null:
		return "reject.not_cookable"
	var cfg := Catalog.cook_config(fi.ingredient_id)
	if cfg.is_empty() or str(cfg.get("station", "")) != kind:
		return "reject.wrong_station"
	if fi.state == FoodItem.State.BURNT:
		return "reject.burnt"
	return ""

func on_item_removed(idx: int, _item: Carryable) -> void:
	(_bars[idx] as Bar3D).show_bar(false)
	(_smoke[idx] as CPUParticles3D).emitting = false
	_last_state[idx] = -1

func _process(delta: float) -> void:
	var speed := EconomyManager.cook_speed()
	var cooking_any := false
	for i in slot_items.size():
		var it := slot_items[i] as FoodItem
		if it == null:
			continue
		if burn_protect and it.state == FoodItem.State.COOKED and it.cook_progress >= _protect_limit(it):
			_update_visuals(i, it)
			continue
		var changed := it.advance_cooking(delta, speed)
		if it.state == FoodItem.State.COOKING:
			cooking_any = true
		if changed:
			_on_state_changed(it)
		_update_visuals(i, it)
	_set_sizzle(cooking_any)

func _protect_limit(it: FoodItem) -> float:
	var cfg := Catalog.cook_config(it.ingredient_id)
	return Util.to_float(cfg.get("cook_time", 8.0), 8.0) + Util.to_float(cfg.get("burn_time", 8.0), 8.0) * 0.5

func _on_state_changed(it: FoodItem) -> void:
	if it.state == FoodItem.State.COOKED:
		AudioManager.play_sfx("cooked")
		Events.item_cooked.emit(it.ingredient_id)
		if it.ingredient_id == "patty" or it.ingredient_id == "veggie_patty":
			GameState.add_stat("patties_cooked", 1)
	elif it.state == FoodItem.State.BURNT:
		AudioManager.play_sfx("burnt")
		Events.item_burnt.emit(it.ingredient_id)
		Events.toast.emit(Loc.t("toast.burnt", [Catalog.ingredient_name(it.ingredient_id)]), "warn")

func _update_visuals(i: int, it: FoodItem) -> void:
	var cfg := Catalog.cook_config(it.ingredient_id)
	var cook_t := Util.to_float(cfg.get("cook_time", 8.0), 8.0)
	var burn_t := Util.to_float(cfg.get("burn_time", 8.0), 8.0)
	var bar := _bars[i] as Bar3D
	var smoke := _smoke[i] as CPUParticles3D
	bar.show_bar(true)
	smoke.emitting = true
	var ratio := 0.0
	var col := Palette.MUSTARD
	match it.state:
		FoodItem.State.COOKING:
			ratio = it.cook_progress / cook_t
		FoodItem.State.COOKED:
			ratio = 1.0 - (it.cook_progress - cook_t) / burn_t
			col = Palette.LETTUCE if ratio > 0.5 else (Palette.MUSTARD if ratio > 0.25 else Palette.KETCHUP)
		_:
			ratio = 1.0
			col = Palette.KETCHUP
	bar.set_ratio(ratio, col)
	if _last_state[i] != it.state:
		_last_state[i] = it.state
		var key := "state.cooking_bar"
		var smoke_col := Color(1, 1, 1, 0.3)
		if it.state == FoodItem.State.COOKED:
			key = "state.cooked_bar"
			smoke_col = Color(0.65, 0.65, 0.65, 0.35)
		elif it.state == FoodItem.State.BURNT:
			key = "state.burnt_bar"
			smoke_col = Color(0.08, 0.08, 0.08, 0.6)
		bar.set_text(Loc.t(key))
		smoke.color = smoke_col

func _set_sizzle(on: bool) -> void:
	if on == _sizzling:
		return
	_sizzling = on
	if _sizzle == null:
		var stream := AudioManager.loop_stream("sizzle")
		if stream == null:
			return
		_sizzle = AudioStreamPlayer3D.new()
		_sizzle.stream = stream
		_sizzle.bus = "SFX"
		_sizzle.unit_size = 3.0
		_sizzle.max_distance = 9.0
		_sizzle.volume_db = -8.0
		add_child(_sizzle)
	if on:
		_sizzle.play()
	else:
		_sizzle.stop()
