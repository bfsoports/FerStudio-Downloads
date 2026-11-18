class_name SectorMap
extends Node3D
## Builds the SECTOR ABANDONADO map at load time (procedural, deterministic):
##   start      Patio de inicio (barricaded courtyard)
##   street     Calle principal + zona de vehículos
##   gas        Gasolinera abandonada
##   warehouse  Almacén industrial
##   lab        Subestación (zona especial con LA FORJA)
## Static meshes are merged per material and per 16 m cell; navigation comes
## from a navmesh pre-baked by tools/bake_navmesh.gd (runtime bake fallback).

signal built
signal zone_opened(zone_id: String)

const NAVMESH_PATH := "res://resources/configuration/sector_navmesh.res"
const WALL_H := 4.0
const WALL_T := 0.5

var zones := {"start": true, "street": false, "gas": false, "warehouse": false, "lab": false}
var spawn_points: Array[SpawnPoint] = []
var doors: Array[Door] = []
var barricades: Array[Barricade] = []
var player_spawn := Transform3D(Basis(), Vector3(0, 0.1, 28))
var mystery_box: MysteryBox
var nav_region: NavigationRegion3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var decor_lights: Array[Light3D] = []

var _b: MapKit.Batcher
var _geo: Node3D
var _rng := RandomNumberGenerator.new()


func build(bake_if_missing: bool = true) -> void:
	_rng.seed = 1337
	seed(1337)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	_geo = Node3D.new()
	_geo.name = "Geometry"
	nav_region.add_child(_geo)
	_b = MapKit.Batcher.new()
	_environment()
	_ground()
	_start_zone()
	_street_zone()
	_gas_zone()
	_warehouse_zone()
	_lab_zone()
	_skyline()
	var n := _b.build(_geo)
	print("SectorMap: %d merged static meshes" % n)
	_navigation(bake_if_missing)
	_apply_quality()
	built.emit()


func is_zone_open(id: String) -> bool:
	return zones.get(id, false)


# ==============================================================================
# environment & lighting
# ==============================================================================

func _environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.11, 0.13, 0.2)
	sm.sky_horizon_color = Color(0.72, 0.4, 0.2)
	sm.ground_horizon_color = Color(0.2, 0.18, 0.15)
	sm.ground_bottom_color = Color(0.05, 0.05, 0.05)
	sm.sun_angle_max = 4.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.21, 0.22)
	env.fog_density = 0.0085
	env.fog_sky_affect = 0.15
	env.fog_height = 6.0
	env.fog_height_density = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.12
	env.glow_enabled = Settings.quality >= Settings.Quality.MEDIUM
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.72, 0.48)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-24, -128, 0)
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if Settings.quality == Settings.Quality.MEDIUM else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = Settings.shadow_distance()
	sun.shadow_blur = 1.5
	add_child(sun)


func _light(pos: Vector3, color: Color, energy: float, range_: float, decor: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	add_child(l)
	if decor:
		decor_lights.append(l)
	return l


func _apply_quality() -> void:
	var budget := Settings.dynamic_lights_budget()
	for i in decor_lights.size():
		decor_lights[i].visible = i < budget


# ==============================================================================
# primitives
# ==============================================================================

func _floor(x0: float, z0: float, x1: float, z1: float, mat_key: String, y: float = 0.0, scale_: float = 0.25) -> void:
	var size := Vector3(x1 - x0, 0.3, z1 - z0)
	var xf := Transform3D(Basis(), Vector3((x0 + x1) * 0.5, y - 0.15, (z0 + z1) * 0.5))
	_b.box(xf, size, mat_key, scale_, false)
	MapKit.collider(_geo, xf, size)


## Axis aligned wall from a to b (2D x,z) with openings.
## opening: {"at": distance from a, "w": width, "kind": "window"|"door"|"gap", "zone": id, "inside": Vector3}
func _wall(a: Vector2, b: Vector2, h: float, mat_key: String, openings: Array = [], inside := Vector3.ZERO) -> void:
	var dir := (b - a)
	var length := dir.length()
	dir = dir.normalized()
	var yaw := atan2(dir.x, dir.y)    # rotation so local +X goes along the wall
	var basis := Basis(Vector3.UP, yaw - PI * 0.5)
	openings.sort_custom(func(o1, o2): return o1.at < o2.at)
	var cursor := 0.0
	for o in openings:
		var s: float = o.at - o.w * 0.5
		var e: float = o.at + o.w * 0.5
		if s > cursor:
			_wall_piece(a, dir, basis, cursor, s, 0.0, h, mat_key)
		var center2 := a + dir * float(o.at)
		var center := Vector3(center2.x, 0, center2.y)
		match o.kind:
			"window":
				var sill: float = o.get("sill", 0.85)
				var wh: float = o.get("h", 1.5)
				_wall_piece(a, dir, basis, s, e, 0.0, sill, mat_key)
				_wall_piece(a, dir, basis, s, e, sill + wh, h, mat_key)
				# frame
				var fx := Transform3D(basis, center + Vector3(0, sill - 0.05, 0))
				_b.box(fx, Vector3(o.w + 0.2, 0.1, WALL_T + 0.12), "wood")
				_b.box(Transform3D(basis, center + Vector3(0, sill + wh + 0.05, 0)), Vector3(o.w + 0.2, 0.1, WALL_T + 0.12), "wood")
				_add_barricade(center, inside, o.w, wh, sill, o.zone)
			"door":
				_wall_piece(a, dir, basis, s, e, 3.4, h, mat_key)
				var d := Door.new()
				d.price = o.price
				d.title = o.title
				d.zone_a = o.zone_a
				d.zone_b = o.zone_b
				d.style = o.style
				d.size = Vector3(o.w, 3.4, 0.7)
				d.transform = Transform3D(basis, center)
				nav_region.add_child(d)
				doors.append(d)
				var link := NavigationLink3D.new()
				var n3 := Vector3(-dir.y, 0, dir.x)
				link.start_position = center - n3 * 1.4
				link.end_position = center + n3 * 1.4
				link.bidirectional = true
				link.enabled = false
				add_child(link)
				d.set_meta("link", link)
				d.opened.connect(_on_door_opened)
			"gap":
				_wall_piece(a, dir, basis, s, e, 3.6, h, mat_key)
		cursor = e
	if cursor < length:
		_wall_piece(a, dir, basis, cursor, length, 0.0, h, mat_key)


func _wall_piece(a: Vector2, dir: Vector2, basis: Basis, s: float, e: float, y0: float, y1: float, mat_key: String) -> void:
	if e - s < 0.01 or y1 - y0 < 0.01:
		return
	var mid := a + dir * ((s + e) * 0.5)
	var xf := Transform3D(basis, Vector3(mid.x, (y0 + y1) * 0.5, mid.y))
	var size := Vector3(e - s, y1 - y0, WALL_T)
	_b.box(xf, size, mat_key, 0.35)
	MapKit.collider(_geo, xf, size)
	# top trim
	if y1 >= WALL_H - 0.01:
		_b.box(Transform3D(basis, Vector3(mid.x, y1 + 0.08, mid.y)), Vector3(e - s + 0.02, 0.16, WALL_T + 0.14), "concrete")


func _add_barricade(center: Vector3, inside: Vector3, w: float, h: float, sill: float, zone: String) -> void:
	var bar := Barricade.new()
	bar.width = w
	bar.height = h
	bar.sill = sill
	bar.zone_id = zone
	# +Z of the barricade points into the play area
	var yaw := atan2(inside.x, inside.z)
	bar.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	nav_region.add_child(bar)
	barricades.append(bar)
	for k in 2:
		var sp := SpawnPoint.new()
		sp.zone_id = zone
		sp.barricade = bar
		sp.position = center - inside * (4.0 + k * 2.5) + Vector3(_rng.randf_range(-1.2, 1.2), 0.1, 0).rotated(Vector3.UP, yaw)
		add_child(sp)
		spawn_points.append(sp)
	# outside light so the window reads from inside
	if zone == "start" or _rng.randf() < 0.35:
		_light(center - inside * 1.5 + Vector3.UP * 2.6, Color(0.55, 0.75, 0.5), 0.6, 4.5, true)


func _inside_spawn(pos: Vector3, zone: String) -> void:
	var sp := SpawnPoint.new()
	sp.zone_id = zone
	sp.position = pos + Vector3.UP * 0.1
	add_child(sp)
	spawn_points.append(sp)
	# cracked-ground marker
	_b.box(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, 0.01, 0)), Vector3(1.6, 0.02, 1.6), "dirt", 0.5, false)


func _wall_buy(id: String, pos: Vector3, yaw: float) -> void:
	var w := WallWeapon.new()
	w.weapon_id = id
	w.transform = MapKit.at(pos, yaw)
	nav_region.add_child(w)


func _perk(id: String, pos: Vector3, yaw: float) -> void:
	var p := PerkMachine.new()
	p.perk_id = id
	p.transform = MapKit.at(pos, yaw)
	nav_region.add_child(p)


# ==============================================================================
# layout
# ==============================================================================

func _ground() -> void:
	# outside dirt (where zombies come from)
	_floor(-60, -60, 56, 60, "dirt", -0.02, 0.12)
	# outer fence ring hiding the world edge
	for side in [[Vector2(-50, -50), Vector2(46, -50)], [Vector2(46, -50), Vector2(46, 50)], [Vector2(46, 50), Vector2(-50, 50)], [Vector2(-50, 50), Vector2(-50, -50)]]:
		_wall(side[0], side[1], 3.0, "metal")


func _start_zone() -> void:
	_floor(-10, 18, 10, 34, "concrete", 0.0, 0.25)
	var inside_n := Vector3(0, 0, -1)
	_wall(Vector2(-10.25, 34), Vector2(10.25, 34), WALL_H, "brick", [
		{"at": 5.25, "w": 1.8, "kind": "window", "zone": "start"},
		{"at": 15.25, "w": 1.8, "kind": "window", "zone": "start"}], inside_n)
	_wall(Vector2(-10, 18), Vector2(-10, 34), WALL_H, "brick", [{"at": 9.0, "w": 1.8, "kind": "window", "zone": "start"}], Vector3(1, 0, 0))
	_wall(Vector2(10, 18), Vector2(10, 34), WALL_H, "brick", [{"at": 9.0, "w": 1.8, "kind": "window", "zone": "start"}], Vector3(-1, 0, 0))
	_wall(Vector2(-10, 18), Vector2(10, 18), WALL_H, "plaster", [
		{"at": 10.0, "w": 3.2, "kind": "door", "price": 750, "title": "DESPEJAR ESCOMBROS", "zone_a": "start", "zone_b": "street", "style": "debris"}])
	# props
	MapKit.sandbags(_b, _geo, MapKit.at(Vector3(-5, 0, 22.5), 0), 3.2)
	MapKit.sandbags(_b, _geo, MapKit.at(Vector3(5.5, 0, 22.5), 0), 2.6)
	MapKit.crate(_b, _geo, Vector3(-8.3, 0, 31.8), 1.1, 12)
	MapKit.crate(_b, _geo, Vector3(-8.2, 1.1, 31.9), 0.8, -20)
	MapKit.crate(_b, _geo, Vector3(-6.9, 0, 32.2), 0.9, 40)
	MapKit.barrel(_b, _geo, Vector3(8.4, 0, 32.3))
	MapKit.barrel(_b, _geo, Vector3(7.6, 0, 32.6), "sign_red")
	MapKit.barrel(_b, _geo, Vector3(8.6, 0, 19.3), "olive")
	# central campfire / table
	_b.box(MapKit.at(Vector3(0, 0.45, 27.5)), Vector3(2.0, 0.08, 1.0), "wood")
	for x in [-0.9, 0.9]:
		for z in [27.1, 27.9]:
			_b.box(MapKit.at(Vector3(x, 0.22, z)), Vector3(0.08, 0.44, 0.08), "dark_metal")
	MapKit.collider(_geo, MapKit.at(Vector3(0, 0.25, 27.5)), Vector3(2.0, 0.5, 1.0))
	MapKit.streetlight(_b, _geo, MapKit.at(Vector3(-9.3, 0, 24), 90), false)
	_light(Vector3(-7.9, 4.8, 24), Color(1.0, 0.72, 0.42), 2.0, 12.0)
	_light(Vector3(6, 3.4, 31), Color(1.0, 0.6, 0.35), 1.4, 9.0, true)
	_wall_buy("smg", Vector3(9.72, 0, 22.0), -90)
	MapKit.sign(self, "PUNTO SEGURO", MapKit.at(Vector3(0, 3.3, 18.3), 0), Color(0.95, 0.9, 0.8), 64)


func _street_zone() -> void:
	_floor(-10, -6, 30, 18, "concrete", 0.0, 0.25)
	_b.box(MapKit.at(Vector3(10, 0.012, 6)), Vector3(40, 0.02, 8.5), "asphalt", 0.15, false)
	for i in 9:
		_b.box(MapKit.at(Vector3(-7.5 + i * 4.6, 0.025, 6)), Vector3(2.0, 0.01, 0.18), "sign_yellow", 1.0, false)
	# south facade (x 10..30)
	_wall(Vector2(10, 18), Vector2(30.25, 18), WALL_H + 1.5, "brick", [{"at": 12.0, "w": 1.8, "kind": "window", "zone": "street"}], Vector3(0, 0, -1))
	# east boundary with two windows (vehicle zone)
	_wall(Vector2(30, -6), Vector2(30, 18), WALL_H, "metal", [
		{"at": 6.0, "w": 1.8, "kind": "window", "zone": "street"},
		{"at": 18.0, "w": 1.8, "kind": "window", "zone": "street"}], Vector3(-1, 0, 0))
	# north: warehouse front (z = -6), gate to warehouse
	_wall(Vector2(-10, -6), Vector2(30, -6), 7.0, "metal", [
		{"at": 20.0, "w": 3.6, "kind": "door", "price": 1250, "title": "ABRIR PORTÓN DEL ALMACÉN", "zone_a": "street", "zone_b": "warehouse", "style": "gate"}], Vector3(0, 0, 1))
	# west: gas station boundary
	_wall(Vector2(-10, -6), Vector2(-10, 18), WALL_H, "plaster", [
		{"at": 12.0, "w": 3.2, "kind": "door", "price": 1000, "title": "DESPEJAR PASO A LA GASOLINERA", "zone_a": "street", "zone_b": "gas", "style": "debris"}], Vector3(1, 0, 0))
	# vehicles
	MapKit.car_wreck(_b, _geo, MapKit.at(Vector3(1.5, 0, 4.0), 78), "car_teal")
	MapKit.car_wreck(_b, _geo, MapKit.at(Vector3(13.5, 0, 8.2), -12), "car_red")
	MapKit.car_wreck(_b, _geo, MapKit.at(Vector3(23.0, 0, 3.0), 104), "car_cream")
	MapKit.car_wreck(_b, _geo, MapKit.at(Vector3(26.8, 0, 11.0), 8), "car_blue")
	MapKit.container(_b, _geo, MapKit.at(Vector3(19.0, 0, 13.6), 90), "metal")
	MapKit.jersey_barrier(_b, _geo, MapKit.at(Vector3(6.0, 0, 13.0), 15))
	MapKit.jersey_barrier(_b, _geo, MapKit.at(Vector3(-4.0, 0, -1.0), -30))
	MapKit.jersey_barrier(_b, _geo, MapKit.at(Vector3(17.0, 0, -2.5), 0))
	MapKit.sandbags(_b, _geo, MapKit.at(Vector3(8.0, 0, -3.0), 0), 3.0)
	MapKit.barrel(_b, _geo, Vector3(28.5, 0, -4.5))
	MapKit.barrel(_b, _geo, Vector3(27.7, 0, -4.9), "hazard")
	MapKit.barrel(_b, _geo, Vector3(-8.6, 0, 16.5), "olive")
	for p in [Vector3(-8.0, 0, 9.5), Vector3(6.0, 0, -4.8), Vector3(18.0, 0, 16.6), Vector3(28.6, 0, 1.0)]:
		var yaw := 90.0 if p.x < 0 else (0.0 if p.z < 0 else (180.0 if p.z > 15 else -90.0))
		MapKit.streetlight(_b, _geo, MapKit.at(p, yaw), false)
		var head := MapKit.at(p, yaw) * Vector3(0, 5.0, 1.35)
		_light(head, Color(1.0, 0.72, 0.42), 2.4, 12.0, p.x > 20)
	_wall_buy("shotgun", Vector3(4.0, 0, 17.72), 180)
	_wall_buy("rifle", Vector3(1.0, 0, -5.72), 0)
	_perk("vitality", Vector3(29.0, 0, -2.0), -90)
	MapKit.sign(self, "ALMACÉN 7", MapKit.at(Vector3(20, 5.6, -5.7), 0), Color(0.95, 0.75, 0.3), 120)
	MapKit.sign(self, "ZONA DE VEHÍCULOS", MapKit.at(Vector3(26, 4.4, 17.7), 180), Color(0.85, 0.85, 0.8), 64)
	_inside_spawn(Vector3(24.0, 0, 7.0), "street")
	_inside_spawn(Vector3(-5.0, 0, 2.0), "street")
	_inside_spawn(Vector3(15.0, 0, -3.5), "street")
	# mystery box starts here
	mystery_box = MysteryBox.new()
	mystery_box.locations = [MapKit.at(Vector3(15.0, 0, 16.9), 180), MapKit.at(Vector3(-31.6, 0, 11.0), 90), MapKit.at(Vector3(12.0, 0, -32.9), 0)]
	mystery_box.transform = mystery_box.locations[0]
	nav_region.add_child(mystery_box)


func _gas_zone() -> void:
	_floor(-34, -6, -10, 18, "concrete", 0.0, 0.25)
	_b.box(MapKit.at(Vector3(-21, 0.012, 6)), Vector3(14, 0.02, 12), "asphalt", 0.15, false)
	_wall(Vector2(-34, -6), Vector2(-34, 18), WALL_H, "brick", [
		{"at": 6.0, "w": 1.8, "kind": "window", "zone": "gas"},
		{"at": 18.0, "w": 1.8, "kind": "window", "zone": "gas"}], Vector3(1, 0, 0))
	_wall(Vector2(-34.25, 18), Vector2(-10, 18), WALL_H, "brick", [{"at": 12.0, "w": 1.8, "kind": "window", "zone": "gas"}], Vector3(0, 0, -1))
	_wall(Vector2(-34.25, -6), Vector2(-10, -6), WALL_H, "plaster", [
		{"at": 12.0, "w": 3.2, "kind": "door", "price": 1000, "title": "DESPEJAR ACCESO A LA SUBESTACIÓN", "zone_a": "gas", "zone_b": "lab", "style": "debris"}], Vector3(0, 0, 1))
	# canopy
	for p in [Vector3(-26, 0, 2), Vector3(-16, 0, 2), Vector3(-26, 0, 10), Vector3(-16, 0, 10)]:
		MapKit.solid(_b, _geo, MapKit.at(p + Vector3(0, 2.3, 0)), Vector3(0.45, 4.6, 0.45), "steel")
	_b.box(MapKit.at(Vector3(-21, 4.8, 6)), Vector3(12, 0.5, 10), "sign_red", 0.3)
	_b.box(MapKit.at(Vector3(-21, 4.52, 6)), Vector3(11.5, 0.06, 9.5), "plaster", 0.3)
	for x in [-24.0, -18.0]:
		_b.box(MapKit.at(Vector3(x, 4.5, 6)), Vector3(0.4, 0.05, 7.0), "lamp_warm")
		_light(Vector3(x, 4.0, 6), Color(1.0, 0.85, 0.65), 1.8, 9.0)
	MapKit.gas_pump(_b, _geo, MapKit.at(Vector3(-23.5, 0, 6), 90))
	MapKit.gas_pump(_b, _geo, MapKit.at(Vector3(-18.5, 0, 6), 90))
	# shop building
	MapKit.solid(_b, _geo, MapKit.at(Vector3(-30.5, 2.0, -2)), Vector3(7, 4, 8), "plaster", 0.3)
	_b.box(MapKit.at(Vector3(-26.95, 1.6, -2)), Vector3(0.1, 1.8, 5.5), "glass")
	_b.box(MapKit.at(Vector3(-30.5, 4.15, -2)), Vector3(7.4, 0.3, 8.4), "roof")
	_b.box(MapKit.at(Vector3(-26.8, 3.5, -2)), Vector3(0.12, 0.7, 6.0), "sign_green")
	MapKit.sign(self, "GASOLINERA", MapKit.at(Vector3(-26.72, 3.5, -2), 90), Color(1.0, 0.9, 0.5), 80)
	_light(Vector3(-25.5, 2.4, -2), Color(0.5, 1.0, 0.6), 0.9, 5.0, true)
	MapKit.car_wreck(_b, _geo, MapKit.at(Vector3(-13.5, 0, 12.5), 20), "car_red")
	MapKit.jersey_barrier(_b, _geo, MapKit.at(Vector3(-14.0, 0, -2.0), 90))
	MapKit.barrel(_b, _geo, Vector3(-33, 0, 16.8), "sign_red")
	MapKit.barrel(_b, _geo, Vector3(-32.2, 0, 16.9))
	MapKit.crate(_b, _geo, Vector3(-12.0, 0, 16.5), 1.0, 10)
	_wall_buy("sniper", Vector3(-26.72, 0, 0.6), 90)
	_perk("quick_reload", Vector3(-14.5, 0, 17.3), 180)
	_inside_spawn(Vector3(-28.0, 0, 13.0), "gas")
	_inside_spawn(Vector3(-15.0, 0, 3.0), "gas")


func _warehouse_zone() -> void:
	_floor(-10, -34, 30, -6, "concrete", 0.0, 0.2)
	_b.box(MapKit.at(Vector3(10, 0.012, -20)), Vector3(3.0, 0.02, 26), "hazard", 0.5, false)
	_wall(Vector2(-10.25, -34), Vector2(30.25, -34), 7.0, "metal", [
		{"at": 10.25, "w": 1.8, "kind": "window", "zone": "warehouse"},
		{"at": 30.25, "w": 1.8, "kind": "window", "zone": "warehouse"}], Vector3(0, 0, 1))
	_wall(Vector2(30, -34), Vector2(30, -6), 7.0, "metal", [{"at": 14.0, "w": 1.8, "kind": "window", "zone": "warehouse"}], Vector3(-1, 0, 0))
	_wall(Vector2(-10, -34), Vector2(-10, -6), 7.0, "metal", [
		{"at": 14.0, "w": 3.6, "kind": "door", "price": 1500, "title": "ABRIR COMPUERTA A LA SUBESTACIÓN", "zone_a": "warehouse", "zone_b": "lab", "style": "gate"}], Vector3(1, 0, 0))
	# partially collapsed roof
	for z in [-31.0, -22.0]:
		_b.box(MapKit.at(Vector3(10, 7.1, z)), Vector3(40.5, 0.3, 6.0), "roof", 0.25)
	_b.box(MapKit.at(Vector3(10, 7.1, -9.0)), Vector3(40.5, 0.3, 6.0), "roof", 0.25)
	for x in range(-8, 30, 8):
		_b.box(MapKit.at(Vector3(x, 6.7, -20)), Vector3(0.3, 0.5, 28), "rust")
	# racks & containers
	for x in [-4.0, 4.0, 16.0, 24.0]:
		for z in [-28.0, -16.0]:
			MapKit.shelf(_b, _geo, MapKit.at(Vector3(x, 0, z), 90 if x > 10 else 0))
	MapKit.container(_b, _geo, MapKit.at(Vector3(25.5, 0, -10.5), 90), "car_teal")
	MapKit.crate(_b, _geo, Vector3(6.0, 0, -9.0), 1.2, 5)
	MapKit.crate(_b, _geo, Vector3(7.3, 0, -8.8), 1.0, -15)
	MapKit.crate(_b, _geo, Vector3(6.4, 1.2, -9.1), 0.8, 30)
	MapKit.barrel(_b, _geo, Vector3(-8.5, 0, -8.0), "hazard")
	MapKit.barrel(_b, _geo, Vector3(-8.0, 0, -32.5))
	for p in [Vector3(0, 6.2, -12), Vector3(20, 6.2, -12), Vector3(0, 6.2, -27), Vector3(20, 6.2, -27)]:
		_b.box(MapKit.at(p), Vector3(1.6, 0.12, 0.4), "lamp_warm")
		_light(p + Vector3.DOWN * 0.4, Color(1.0, 0.82, 0.6), 2.6, 13.0, p.x > 10)
	_perk("speed", Vector3(29.0, 0, -15.0), -90)
	_perk("damage", Vector3(-9.0, 0, -30.0), 90)
	MapKit.sign(self, "MANTENGA DESPEJADO", MapKit.at(Vector3(10, 4.5, -33.7), 0), Color(0.9, 0.3, 0.2), 64)
	_inside_spawn(Vector3(0.0, 0, -22.0), "warehouse")
	_inside_spawn(Vector3(20.0, 0, -22.0), "warehouse")
	_inside_spawn(Vector3(12.0, 0, -12.0), "warehouse")


func _lab_zone() -> void:
	_floor(-34, -34, -10, -6, "tiles", 0.0, 0.3)
	_wall(Vector2(-34, -34), Vector2(-34, -6), WALL_H, "concrete", [
		{"at": 6.0, "w": 1.8, "kind": "window", "zone": "lab"},
		{"at": 20.0, "w": 1.8, "kind": "window", "zone": "lab"}], Vector3(1, 0, 0))
	_wall(Vector2(-34.25, -34), Vector2(-10, -34), WALL_H, "concrete", [{"at": 12.25, "w": 1.8, "kind": "window", "zone": "lab"}], Vector3(0, 0, 1))
	# hazard ring around the forge
	_b.box(MapKit.at(Vector3(-22, 0.015, -22)), Vector3(7.0, 0.02, 7.0), "hazard", 0.5, false)
	_b.box(MapKit.at(Vector3(-22, 0.02, -22)), Vector3(6.2, 0.02, 6.2), "concrete", 0.25, false)
	var forge := PackAPunch.new()
	forge.transform = MapKit.at(Vector3(-22, 0, -23.5), 0)
	nav_region.add_child(forge)
	_light(Vector3(-22, 3.5, -21), Color(0.5, 1.0, 0.3), 2.5, 11.0)
	# transformers & cables
	for p in [Vector3(-31, 0, -31), Vector3(-31, 0, -10), Vector3(-13, 0, -31)]:
		MapKit.solid(_b, _geo, MapKit.at(p + Vector3(0, 1.2, 0)), Vector3(2.2, 2.4, 1.6), "olive")
		for k in 3:
			_b.mesh(MapKit.cylinder(0.12, 0.9, 6), MapKit.at(p + Vector3(-0.7 + k * 0.7, 2.85, 0)), "steel")
			_b.box(MapKit.at(p + Vector3(-0.7 + k * 0.7, 3.35, 0)), Vector3(0.16, 0.16, 0.16), "lamp_green")
		_b.box(MapKit.at(p + Vector3(0, 1.2, 0.81)), Vector3(1.2, 0.4, 0.02), "hazard", 1.0)
		_light(p + Vector3(0, 3.6, 0), Color(0.45, 1.0, 0.3), 1.2, 6.0, true)
	for i in 6:
		var x := -32.0 + i * 3.6
		MapKit.solid(_b, _geo, MapKit.at(Vector3(x, 2.5, -33.3)), Vector3(0.25, 5.0, 0.25), "wood")
	_b.box(MapKit.at(Vector3(-23.0, 4.6, -33.3)), Vector3(19.0, 0.06, 0.06), "black")
	MapKit.crate(_b, _geo, Vector3(-12.2, 0, -8.2), 1.0, 0)
	MapKit.barrel(_b, _geo, Vector3(-32.8, 0, -18.0), "hazard")
	_perk("regen", Vector3(-33.0, 0, -20.5), 90)
	MapKit.sign(self, "SUBESTACIÓN 4", MapKit.at(Vector3(-22, 3.4, -6.3), 180), Color(0.6, 1.0, 0.4), 80)
	MapKit.sign(self, "LA FORJA", MapKit.at(Vector3(-22, 4.2, -23.9), 0), Color(0.6, 1.0, 0.4), 72)
	_inside_spawn(Vector3(-28.0, 0, -16.0), "lab")
	_inside_spawn(Vector3(-15.0, 0, -26.0), "lab")


func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 26:
		var ang := float(i) / 26.0 * TAU
		var r := rng.randf_range(62, 85)
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var h := rng.randf_range(10, 34)
		var w := rng.randf_range(8, 16)
		_b.box(Transform3D(Basis(Vector3.UP, rng.randf() * PI), p + Vector3(0, h * 0.5, 0)), Vector3(w, h, w * 0.8), "roof", 0.08, false)
		if rng.randf() < 0.5:
			_b.box(Transform3D(Basis(), p + Vector3(0, h * rng.randf_range(0.3, 0.8), 0)), Vector3(w * 0.3, 0.6, w * 0.82), "neon_orange", 1.0, false)


# ==============================================================================
# navigation & zones
# ==============================================================================

static func make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 32
	nm.filter_baking_aabb = AABB(Vector3(-52, -2, -52), Vector3(100, 12, 104))
	return nm


func _navigation(bake_if_missing: bool) -> void:
	if ResourceLoader.exists(NAVMESH_PATH):
		nav_region.navigation_mesh = load(NAVMESH_PATH)
		print("SectorMap: pre-baked navmesh loaded (%d polygons)" % nav_region.navigation_mesh.get_polygon_count())
	elif bake_if_missing:
		nav_region.navigation_mesh = make_navmesh()
		nav_region.bake_navigation_mesh(false)
		print("SectorMap: navmesh baked at runtime (%d polygons)" % nav_region.navigation_mesh.get_polygon_count())


func _on_door_opened(d: Door) -> void:
	var link: NavigationLink3D = d.get_meta("link")
	if link:
		link.enabled = true
	for z in [d.zone_a, d.zone_b]:
		if not zones.get(z, false):
			zones[z] = true
			zone_opened.emit(z)
