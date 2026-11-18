class_name SinkStation
extends Station
## Fregadero: lava las bandejas sucias (DirtyTray). Caben dos, una encima de otra; cada una se lava sola en WASH_TIME
## segundos (la mejora «Fregadero rápido» lo acelera) con barra 3D y salpicaduras, y al terminar vuelve limpia a su
## puesto del mostrador. Si se saca antes de tiempo, el lavado se reinicia.

const WASH_TIME := 3.0

var _progress: Array = []
var _bars: Array = []
var _splash: CPUParticles3D = null

## top_y: altura de la encimera del fregadero.
func configure(top_y: float) -> void:
	kind = "sink"
	for k in 2:
		var idx := add_slot(Vector3(0, top_y + 0.01 + 0.08 * float(k), 0))
		# la bandeja se coloca a lo largo del fregadero (el modelo está girado contra la pared este)
		(slot_nodes[idx] as Marker3D).rotation.y = PI * 0.5
		_progress.append(0.0)
		var bar := Bar3D.new(0.5, true)
		bar.position = Vector3(0, top_y + 0.55 + 0.22 * float(k), 0)
		bar.show_bar(false)
		add_child(bar)
		_bars.append(bar)
	_splash = _make_splash()
	_splash.position = Vector3(0, top_y + 0.12, 0)
	add_child(_splash)

func _make_splash() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.color = Color(0.7, 0.88, 1.0, 0.75)
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	sm.material = m
	p.mesh = sm
	return p

## Siempre la ranura libre más baja, para que la segunda bandeja quede encima de la primera y no flotando.
func free_slot_index(_item: Carryable, _near_world: Vector3 = Vector3.INF) -> int:
	for i in slot_items.size():
		if slot_items[i] == null:
			return i
	return -1

func reject_reason(item: Carryable) -> String:
	if not (item is DirtyTray):
		return "reject.sink_trays_only"
	return ""

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p != null and p.held == null:
		if not items_present().is_empty():
			return {"icon": "use", "text": "prompt.washing", "ok": false}
		return {"icon": "use", "text": "prompt.sink_idle", "ok": false}
	if p != null and p.held is DirtyTray and free_slot_index(p.held) >= 0:
		return {"icon": "drop", "text": "prompt.wash"}
	return super.get_prompt(player)

func on_item_placed(idx: int, _item: Carryable) -> void:
	_progress[idx] = 0.0
	AudioManager.play_sfx("place", -4.0, 0.7)

func on_item_removed(idx: int, _item: Carryable) -> void:
	_progress[idx] = 0.0
	(_bars[idx] as Bar3D).show_bar(false)

## Fracción lavada de la bandeja de una ranura (0-1); -1 si la ranura está vacía.
func wash_ratio(idx: int) -> float:
	if slot_items[idx] == null:
		return -1.0
	return clampf(float(_progress[idx]) / WASH_TIME, 0.0, 1.0)

func _process(delta: float) -> void:
	var any := false
	for i in slot_items.size():
		var tray := slot_items[i] as DirtyTray
		if tray == null:
			continue
		any = true
		_progress[i] = float(_progress[i]) + delta * EconomyManager.wash_speed()
		var bar := _bars[i] as Bar3D
		bar.show_bar(true)
		bar.set_ratio(wash_ratio(i), Color.html("#5fb8f0"))
		bar.set_text(Loc.t("state.washing"))
		if float(_progress[i]) >= WASH_TIME:
			_finish(i, tray)
	_splash.emitting = any

func _finish(idx: int, tray: DirtyTray) -> void:
	clear_slot_of(tray)
	var home := tray.home
	tray.queue_free()
	if home != null and is_instance_valid(home):
		home.restore_tray()
	AudioManager.play_sfx("ding", -4.0, 1.25)
	GameState.add_stat("trays_washed", 1)
	Events.tray_washed.emit()
	Events.toast.emit(Loc.t("toast.tray_clean"), "success")
