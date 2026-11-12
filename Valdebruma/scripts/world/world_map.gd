class_name WorldMap
extends RefCounted
## WorldMap — datos geométricos del valle compartidos por cliente y servidor.
##
## Responsabilidad: alturas, regiones, agua, edificios (transformaciones y cajas de
## colisión), objetos sueltos, índice espacial y pruebas geométricas deterministas
## (segmento contra muros, interior de edificio, celdas transitables).
## Datos: data/world/*.bin|json y data/buildings/*.json. Solo lectura.
## Lo llaman: streaming del cliente, validación del servidor, IA de criaturas, interfaz (mapa).
## Autoridad online: el servidor valida movimiento, línea de visión e interacción con ESTAS
## mismas funciones; el cliente las usa solo para presentación y predicción.

const SIZE := 1280.0
const SECTOR := 64.0
const SECTORS := 20
const CELL := 4.0            # rejilla de navegación / ocupación
const CELLS := 320
const F_ROAD := 1
const F_BUILDING := 2
const F_WATER := 4
const F_STEEP := 8
const F_DECK := 16

var info: Dictionary = {}
var water_level := 10.0
var samples := 641
var step := 2.0
var heights: PackedFloat32Array
var regions: PackedByteArray
var veg: PackedFloat32Array
var veg_index: Array = []
var buildings: Array = []          # [{id, type, pos: Vector3, yaw, xf: Transform3D, inv: Transform3D, meta, radius}]
var props: Array = []
var harvest_nodes: Array = []
var places: Array = []
var roads: Array = []
var decks: Array = []              # superficies transitables sobre el agua (puentes, pasarelas)
var cells: PackedByteArray
var cell_deck_y: Dictionary = {}
var _sector_buildings: Dictionary = {}
var _sector_props: Dictionary = {}
var _sector_harvest: Dictionary = {}
var _sector_roads: Dictionary = {}

func load_all() -> void:
	info = DataFiles.dict("res://data/world/world.json")
	water_level = float(info.get("water_level", 10.0))
	samples = int(info.get("samples", 641))
	step = float(info.get("step", 2.0))
	heights = FileAccess.get_file_as_bytes("res://data/world/height.bin").to_float32_array()
	regions = FileAccess.get_file_as_bytes("res://data/world/regions.bin")
	veg = FileAccess.get_file_as_bytes("res://data/world/veg.bin").to_float32_array()
	veg_index = info.get("veg_index", [])
	places = info.get("places", [])
	roads = info.get("roads", [])
	if heights.size() != samples * samples:
		push_error("WorldMap: height.bin no coincide con el tamaño declarado")
	for b: Dictionary in info.get("buildings", []):
		var pos := Vector3(b.pos[0], b.pos[1], b.pos[2])
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.yaw))), pos)
		var meta := DataFiles.building(String(b.type))
		var e := {"id": int(b.id), "type": String(b.type), "pos": pos, "yaw": float(b.yaw), "xf": xf, "inv": xf.affine_inverse(),
			"meta": meta, "radius": 0.5 * Vector2(float(b.w), float(b.d)).length() + 2.0, "w": float(b.w), "d": float(b.d)}
		buildings.append(e)
		_bucket(_sector_buildings, pos.x, pos.z, buildings.size() - 1)
	var prop_defs := DataFiles.props()
	for i in (info.get("props", []) as Array).size():
		var p: Dictionary = info.props[i]
		var e := {"id": i, "model": String(p.model), "pos": Vector3(p.pos[0], p.pos[1], p.pos[2]), "yaw": float(p.yaw)}
		props.append(e)
		_bucket(_sector_props, e.pos.x, e.pos.z, i)
		var def: Dictionary = prop_defs.get(e.model, {})
		if def.has("walk"):
			decks.append({"pos": e.pos, "yaw": e.yaw, "w": float(def.walk[0]), "l": float(def.walk[1])})
	for h: Dictionary in info.get("harvest", []):
		var e := {"id": int(h.id), "type": String(h.type), "pos": Vector3(h.pos[0], h.pos[1], h.pos[2]), "yaw": float(h.yaw)}
		harvest_nodes.append(e)
		_bucket(_sector_harvest, e.pos.x, e.pos.z, harvest_nodes.size() - 1)
	for ri in roads.size():
		var pts: Array = roads[ri].points
		for k in pts.size() - 1:
			var mx: float = (float(pts[k][0]) + float(pts[k + 1][0])) * 0.5
			var mz: float = (float(pts[k][2]) + float(pts[k + 1][2])) * 0.5
			var key := sector_key(mx, mz)
			if not _sector_roads.has(key):
				_sector_roads[key] = []
			(_sector_roads[key] as Array).append([ri, k])
	_build_cells()

func _bucket(d: Dictionary, x: float, z: float, idx: int) -> void:
	var key := sector_key(x, z)
	if not d.has(key):
		d[key] = []
	(d[key] as Array).append(idx)

# ---- sectores ---------------------------------------------------------------------------------
static func sector_of(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(x / SECTOR), 0, SECTORS - 1), clampi(int(z / SECTOR), 0, SECTORS - 1))

static func sector_key(x: float, z: float) -> int:
	var s := sector_of(x, z)
	return s.y * SECTORS + s.x

static func key_of(s: Vector2i) -> int:
	return s.y * SECTORS + s.x

func sector_buildings(key: int) -> Array:
	return _sector_buildings.get(key, [])

func sector_props(key: int) -> Array:
	return _sector_props.get(key, [])

func sector_harvest(key: int) -> Array:
	return _sector_harvest.get(key, [])

func sector_road_segments(key: int) -> Array:
	return _sector_roads.get(key, [])

## Instancias de vegetación del sector: [tipo, x, y, z, giro, escala] × n.
func sector_veg(key: int) -> PackedFloat32Array:
	if key < 0 or key >= veg_index.size():
		return PackedFloat32Array()
	var e: Array = veg_index[key]
	return veg.slice(int(e[0]) * 6, (int(e[0]) + int(e[1])) * 6)

# ---- terreno ----------------------------------------------------------------------------------
func height(x: float, z: float) -> float:
	var fx := clampf(x / step, 0.0, float(samples) - 1.001)
	var fz := clampf(z / step, 0.0, float(samples) - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - float(i)
	var v := fz - float(j)
	var o := j * samples + i
	return lerpf(lerpf(heights[o], heights[o + 1], u), lerpf(heights[o + samples], heights[o + samples + 1], u), v)

func normal(x: float, z: float) -> Vector3:
	var e := 1.0
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()

func slope_deg(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal(x, z).y, -1.0, 1.0)))

func water_depth(x: float, z: float) -> float:
	return maxf(0.0, water_level - height(x, z))

## Altura pisable: terreno o tablero de puente/pasarela si lo hay encima.
func ground(x: float, z: float) -> float:
	var h := height(x, z)
	var ck := _cell_index(x, z)
	if ck >= 0 and (cells[ck] & F_DECK) != 0:
		return maxf(h, float(cell_deck_y.get(ck, h)))
	return h

func region_id(x: float, z: float) -> int:
	var i := clampi(int(x / 10.0), 0, 127)
	var j := clampi(int(z / 10.0), 0, 127)
	return regions[j * 128 + i]

func region_name(x: float, z: float) -> String:
	var names: Array = info.get("regions", [])
	var id := region_id(x, z)
	return String(names[id]) if id < names.size() else "pradera"

func in_bounds(x: float, z: float, margin := 0.0) -> bool:
	var b: float = float(info.get("border", 40.0)) + margin
	return x > b and z > b and x < SIZE - b and z < SIZE - b

func in_safe_zone(x: float, z: float) -> bool:
	for s: Dictionary in info.get("safe_zones", []):
		if Vector2(x - float(s.center[0]), z - float(s.center[1])).length() < float(s.radius):
			return true
	return false

## Intensidad de bruma (0..1) en un punto: zonas de riesgo definidas en el mundo.
func hazard_at(x: float, z: float) -> float:
	var best := 0.0
	for hz: Dictionary in info.get("hazards", []):
		var d := Vector2(x - float(hz.center[0]), z - float(hz.center[1])).length()
		if d < float(hz.radius):
			best = maxf(best, clampf((float(hz.radius) - d) / maxf(1.0, float(hz.radius) - float(hz.inner)), 0.0, 1.0))
	return best

# ---- rejilla de ocupación / navegación -----------------------------------------------------------
func _cell_index(x: float, z: float) -> int:
	var i := int(x / CELL)
	var j := int(z / CELL)
	if i < 0 or j < 0 or i >= CELLS or j >= CELLS:
		return -1
	return j * CELLS + i

func cell_flags(x: float, z: float) -> int:
	var k := _cell_index(x, z)
	return cells[k] if k >= 0 else (F_STEEP | F_BUILDING)

func _build_cells() -> void:
	cells = PackedByteArray()
	cells.resize(CELLS * CELLS)
	for j in CELLS:
		for i in CELLS:
			var x := (float(i) + 0.5) * CELL
			var z := (float(j) + 0.5) * CELL
			var f := 0
			var h := height(x, z)
			if h < water_level - 0.55:
				f |= F_WATER
			if absf(height(x + 2.0, z) - height(x - 2.0, z)) > 3.4 or absf(height(x, z + 2.0) - height(x, z - 2.0)) > 3.4:
				f |= F_STEEP
			cells[j * CELLS + i] = f
	for r: Dictionary in roads:
		var pts: Array = r.points
		var half: float = float(r.width) * 0.5
		for k in pts.size() - 1:
			var a := Vector2(pts[k][0], pts[k][2])
			var b := Vector2(pts[k + 1][0], pts[k + 1][2])
			var n := maxi(1, int(a.distance_to(b) / 2.0))
			for s in n + 1:
				var p := a.lerp(b, float(s) / float(n))
				for ox in [-half, 0.0, half]:
					var ck := _cell_index(p.x + ox, p.y)
					if ck >= 0:
						cells[ck] = cells[ck] | F_ROAD
	for b: Dictionary in buildings:
		var hw: float = b.w * 0.5 + 0.6
		var hd: float = b.d * 0.5 + 0.6
		var n := int(maxf(hw, hd) / 1.5) + 1
		for sx in range(-n, n + 1):
			for sz in range(-n, n + 1):
				var lp := Vector3(hw * float(sx) / float(n), 0, hd * float(sz) / float(n))
				var wp: Vector3 = (b.xf as Transform3D) * lp
				var ck := _cell_index(wp.x, wp.z)
				if ck >= 0:
					cells[ck] = cells[ck] | F_BUILDING
	for d: Dictionary in decks:
		var basis := Basis(Vector3.UP, deg_to_rad(float(d.yaw)))
		var n := int(float(d.l) / 2.0) + 1
		for s in n + 1:
			for ox in [-0.4, 0.4]:
				var wp: Vector3 = (d.pos as Vector3) + basis * Vector3(float(d.w) * ox, 0, -float(d.l) * 0.5 + float(d.l) * float(s) / float(n))
				var ck := _cell_index(wp.x, wp.z)
				if ck >= 0:
					cells[ck] = (cells[ck] | F_DECK) & ~F_WATER & ~F_STEEP
					cell_deck_y[ck] = (d.pos as Vector3).y

## ¿Puede caminar una criatura terrestre por esta celda?
func walkable(x: float, z: float) -> bool:
	return (cell_flags(x, z) & (F_BUILDING | F_WATER | F_STEEP)) == 0

# ---- edificios: interior y colisiones ---------------------------------------------------------------
func buildings_near(x: float, z: float, r: float) -> Array:
	var out: Array = []
	var s0 := sector_of(x - r - 16.0, z - r - 16.0)
	var s1 := sector_of(x + r + 16.0, z + r + 16.0)
	for sj in range(s0.y, s1.y + 1):
		for si in range(s0.x, s1.x + 1):
			for bi: int in sector_buildings(sj * SECTORS + si):
				var b: Dictionary = buildings[bi]
				if Vector2(x - b.pos.x, z - b.pos.z).length() < r + float(b.radius):
					out.append(bi)
	return out

## Índice del edificio cuyo volumen interior contiene el punto, o -1.
func building_at(p: Vector3) -> int:
	for bi: int in buildings_near(p.x, p.z, 1.0):
		var b: Dictionary = buildings[bi]
		var lp: Vector3 = (b.inv as Transform3D) * p
		for box: Array in (b.meta as Dictionary).get("interior", []):
			# interior en convenio de modelado: [x0, y0, x1, y1, z0, z1] con y = fondo => z local = -y
			if lp.x > float(box[0]) and lp.x < float(box[2]) and -lp.z > float(box[1]) and -lp.z < float(box[3]) and lp.y > float(box[4]) - 0.4 and lp.y < float(box[5]):
				return bi
	return -1

func to_world(bi: int, local: Vector3) -> Vector3:
	return (buildings[bi].xf as Transform3D) * local

## Prueba de segmento contra los muros de los edificios cercanos.
## door_open: Callable(bi: int, door_id: int) -> bool; las puertas cerradas bloquean.
func segment_blocked(a: Vector3, b: Vector3, door_open := Callable()) -> bool:
	var mid := (a + b) * 0.5
	var r := a.distance_to(b) * 0.5
	for bi: int in buildings_near(mid.x, mid.z, r):
		var bd: Dictionary = buildings[bi]
		var la: Vector3 = (bd.inv as Transform3D) * a
		var lb: Vector3 = (bd.inv as Transform3D) * b
		var meta: Dictionary = bd.meta
		for c: Array in meta.get("colliders", []):
			if _seg_aabb(la, lb, Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5]) * 0.5):
				return true
		for d: Dictionary in meta.get("doors", []):
			if door_open.is_valid() and bool(door_open.call(bi, int(d.id))):
				continue
			var basis := Basis(Vector3.UP, deg_to_rad(float(d.yaw)))
			var center: Vector3 = DataFiles.v3(d.pos) + basis * Vector3(float(d.w) * 0.5, float(d.h) * 0.5, 0)
			var inv := Transform3D(basis, center).affine_inverse()
			if _seg_aabb(inv * la, inv * lb, Vector3.ZERO, Vector3(float(d.w) * 0.5, float(d.h) * 0.5, 0.07)):
				return true
	return false

static func _seg_aabb(a: Vector3, b: Vector3, c: Vector3, half: Vector3) -> bool:
	var d := b - a
	var tmin := 0.0
	var tmax := 1.0
	for i in 3:
		var lo: float = c[i] - half[i]
		var hi: float = c[i] + half[i]
		if absf(d[i]) < 1e-7:
			if a[i] < lo or a[i] > hi:
				return false
		else:
			var t1: float = (lo - a[i]) / d[i]
			var t2: float = (hi - a[i]) / d[i]
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return false
	return true

## Lugar (punto de interés) que contiene la posición, o diccionario vacío.
func place_at(x: float, z: float) -> Dictionary:
	for p: Dictionary in places:
		if Vector2(x - float(p.pos[0]), z - float(p.pos[1])).length() < float(p.radius):
			return p
	return {}

func place(id: String) -> Dictionary:
	for p: Dictionary in places:
		if String(p.id) == id:
			return p
	return {}

## ¿Hay agua accesible a menos de 'reach' metros? (orilla del río, marjal, lago)
func near_water(x: float, z: float, reach := 2.6) -> bool:
	for a in 8:
		var ang := float(a) * TAU / 8.0
		if height(x + cos(ang) * reach, z + sin(ang) * reach) < water_level - 0.05:
			return true
	return height(x, z) < water_level + 0.05
