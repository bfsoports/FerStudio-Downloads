class_name WorldStreamer
extends Node3D
## WorldStreamer — carga y descarga progresiva del mundo por sectores.
##
## Responsabilidad: decidir qué sectores deben existir y con qué nivel de detalle según la
## posición del jugador y el ajuste de distancia de visión; ejecutar sus pasos de construcción
## por prioridad (los más cercanos primero) con un presupuesto de tiempo por fotograma, y
## descargar los lejanos con histéresis para evitar tirones y cargas repetidas.
## Datos: sectors (clave -> Sector), cola de trabajos. Señales: progress(done, total), ready_near.
## Límites: 20×20 sectores de 64 m; nunca hay más de (2·visión+3)² sectores vivos.

signal progress(done: int, total: int)
signal ready_near()

var world: WorldMap
var sectors: Dictionary = {}
var center := Vector2i(-99, -99)
var budget_ms := 5.0
var _queue: Array = []            # [distancia, Sector, Callable]
var _total := 0
var _done := 0
var _near_pending := true
var stats := {"jobs_ms_max": 0.0, "jobs_run": 0, "sectors": 0, "last_frame_ms": 0.0}

func _ready() -> void:
	Config.changed.connect(func(section: String, key: String) -> void:
		if section == "video" and key in ["view_distance", "grass"]:
			var c := center
			center = Vector2i(-99, -99)
			update_center(Vector3(float(c.x) * WorldMap.SECTOR + 1.0, 0, float(c.y) * WorldMap.SECTOR + 1.0)))

func pending() -> int:
	return _queue.size()

## Llamar con la posición del jugador; solo recalcula al cambiar de sector.
func update_center(pos: Vector3) -> void:
	var c := WorldMap.sector_of(pos.x, pos.z)
	if c == center:
		return
	center = c
	var view := int(Config.get_v("video", "view_distance"))
	for sj in range(c.y - view, c.y + view + 1):
		for si in range(c.x - view, c.x + view + 1):
			if si < 0 or sj < 0 or si >= WorldMap.SECTORS or sj >= WorldMap.SECTORS:
				continue
			var dist: int = maxi(absi(si - c.x), absi(sj - c.y))
			var lvl := 0 if dist <= 1 else (1 if dist == 2 else 2)
			var key := sj * WorldMap.SECTORS + si
			var s: Sector = sectors.get(key)
			if s == null:
				s = Sector.new()
				s.setup(key, world)
				add_child(s)
				sectors[key] = s
			if s.level != lvl:
				_remove_jobs(s)
				for job: Callable in s.jobs_for(lvl):
					_queue.append([dist, s, job])
					_total += 1
	for key: int in sectors.keys():
		var s: Sector = sectors[key]
		if maxi(absi(s.coord.x - c.x), absi(s.coord.y - c.y)) > view + 1:
			_remove_jobs(s)
			if s.level <= 1:
				WorldRoot.current.sector_detail(key, false)
			WorldRoot.current.forget_interior(key)
			sectors.erase(key)
			s.queue_free()
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	stats.sectors = sectors.size()

func _remove_jobs(s: Sector) -> void:
	var kept: Array = []
	for j: Array in _queue:
		if j[1] != s:
			kept.append(j)
		else:
			_done += 1
	_queue = kept

func _process(_delta: float) -> void:
	if _queue.is_empty():
		if _near_pending and not sectors.is_empty():
			_near_pending = false
			ready_near.emit()
		return
	var start := Time.get_ticks_usec()
	var limit := int(budget_ms * 1000.0)
	while not _queue.is_empty():
		var j: Array = _queue.pop_front()
		var s: Sector = j[1]
		if is_instance_valid(s):
			var t0 := Time.get_ticks_usec()
			(j[2] as Callable).call()
			stats.jobs_ms_max = maxf(float(stats.jobs_ms_max), float(Time.get_ticks_usec() - t0) / 1000.0)
			stats.jobs_run = int(stats.jobs_run) + 1
		_done += 1
		if Time.get_ticks_usec() - start > limit:
			break
	stats.last_frame_ms = float(Time.get_ticks_usec() - start) / 1000.0
	progress.emit(_done, _total)
	if _near_pending:
		var near_left := false
		for j: Array in _queue:
			if int(j[0]) <= 1:
				near_left = true
				break
		if not near_left:
			_near_pending = false
			ready_near.emit()
