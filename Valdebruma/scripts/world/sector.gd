class_name Sector
extends Node3D
## Sector — un trozo de 64×64 m del valle cargado en el cliente.
##
## Responsabilidad: construir por pasos (sin congelar el juego) el terreno, la vegetación
## instanciada con niveles de detalle, carreteras, objetos, edificios e interiores del sector,
## y liberar lo que sobra cuando el jugador se aleja.
## Niveles: 0 = cercano (todo + colisiones + hierba), 1 = medio (sin hierba ni troncos sólidos),
## 2 = lejano (terreno simplificado, árboles de bajo detalle, solo objetos grandes).
## Lo llama: WorldStreamer. Los pasos son idempotentes: se pueden repetir sin duplicar nada.

const CELLS := 32                  # celdas de 2 m por lado
const BIG_PROPS: Array[String] = ["bridge_road", "bridge_wood", "boardwalk", "dock", "silo", "water_tower", "radio_mast", "windpump", "power_pole",
	"shipping_container", "bus_stop", "car_van", "car_sedan", "car_sedan_red", "tractor", "trailer", "fountain", "notice_board", "market_stall", "well", "tent_camp"]
const LOD2_ALIAS := {"tree_pine_b": "tree_pine_a", "tree_fir_b": "tree_fir_a", "tree_oak_b": "tree_oak_a", "tree_birch_b": "tree_birch_a", "tree_dead_b": "tree_dead_a"}
const SOLID_VEG := {"rock_a": 0.55, "rock_b": 1.0, "rock_c": 1.7, "rock_e": 2.3, "cliff_a": 4.2, "stump": 0.35}

static var _leaf_only: Dictionary = {}
static var _veg_meta: Dictionary = {}

var key := 0
var coord := Vector2i.ZERO
var origin := Vector3.ZERO
var level := -1
var world: WorldMap
var terrain: MeshInstance3D
var terrain_lod := -1
var ground_body: StaticBody3D
var trunk_body: StaticBody3D
var tree_sets: Array = [null, null, null]
var detail: Node3D
var big_veg: Node3D
var grass: Node3D
var roads: Node3D
var props_big: Node3D
var props_small: Node3D
var buildings: Node3D
var interiors: Node3D
var _veg: PackedFloat32Array

func setup(k: int, w: WorldMap) -> void:
	key = k
	world = w
	coord = Vector2i(k % WorldMap.SECTORS, k / WorldMap.SECTORS)
	origin = Vector3(float(coord.x) * WorldMap.SECTOR, 0, float(coord.y) * WorldMap.SECTOR)
	position = origin
	name = "S_%d_%d" % [coord.x, coord.y]
	_veg = world.sector_veg(key)
	if _veg_meta.is_empty():
		_veg_meta = DataFiles.dict("res://data/models/vegetation.json")

## Pasos necesarios para pasar al nivel pedido (el streamer los ejecuta repartidos en el tiempo).
func jobs_for(new_level: int) -> Array:
	var jobs: Array = []
	var old := level
	level = new_level
	var lod := 0 if new_level <= 1 else 1
	if terrain_lod != lod:
		jobs.append(_build_terrain.bind(lod))
	jobs.append(_show_trees.bind(new_level))
	if roads == null:
		jobs.append(_build_roads)
	if buildings == null:
		jobs.append(_build_buildings)
	if props_big == null:
		jobs.append(_build_props.bind(true))
	if big_veg == null:
		jobs.append(_build_big_veg)
	if new_level <= 1:
		if detail == null:
			jobs.append(_build_detail)
		if props_small == null:
			jobs.append(_build_props.bind(false))
		if interiors == null:
			jobs.append(_build_interiors)
	else:
		jobs.append(_free_part.bind("detail"))
		jobs.append(_free_part.bind("props_small"))
		jobs.append(_free_part.bind("interiors"))
	if new_level == 0:
		if ground_body == null:
			jobs.append(_build_ground_collision)
		if trunk_body == null:
			jobs.append(_build_trunks)
		jobs.append(_build_grass)
	else:
		jobs.append(_free_part.bind("ground_body"))
		jobs.append(_free_part.bind("trunk_body"))
		jobs.append(_free_part.bind("grass"))
	if (old <= 1) != (new_level <= 1):
		jobs.append(func() -> void: WorldRoot.current.sector_detail(key, new_level <= 1))
	return jobs

func _free_part(field: String) -> void:
	var n: Node = get(field)
	if n != null:
		if field == "interiors":
			WorldRoot.current.forget_interior(key)
		n.queue_free()
		set(field, null)

# ---- terreno -----------------------------------------------------------------------------------------
func _build_terrain(lod: int) -> void:
	var stepc := 1 << lod
	var n := CELLS / stepc
	var s := world.samples
	var i0 := coord.x * CELLS
	var j0 := coord.y * CELLS
	var hs := world.heights
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tans := PackedFloat32Array()
	var idx := PackedInt32Array()
	var side := n + 1
	verts.resize(side * side)
	norms.resize(side * side)
	uvs.resize(side * side)
	for j in side:
		for i in side:
			var hx := i0 + i * stepc
			var hz := j0 + j * stepc
			var o := hz * s + hx
			var h := hs[o]
			var hl := hs[o - 1] if hx > 0 else h
			var hr := hs[o + 1] if hx < s - 1 else h
			var hu := hs[o - s] if hz > 0 else h
			var hd := hs[o + s] if hz < s - 1 else h
			var vi := j * side + i
			verts[vi] = Vector3(float(i * stepc) * 2.0, h, float(j * stepc) * 2.0)
			norms[vi] = Vector3(hl - hr, 4.0, hu - hd).normalized()
			uvs[vi] = Vector2(origin.x + float(i * stepc) * 2.0, origin.z + float(j * stepc) * 2.0)
	for j in n:
		for i in n:
			var a := j * side + i
			idx.append_array(PackedInt32Array([a, a + 1, a + side, a + 1, a + side + 1, a + side]))
	# faldones: tapan las juntas entre sectores con distinto nivel de detalle
	var drop := 2.5 if lod == 0 else 6.0
	for e in 4:
		for k in n:
			var a: int
			var b: int
			match e:
				0: a = k; b = k + 1
				1: a = n * side + k + 1; b = n * side + k
				2: a = (k + 1) * side; b = k * side
				_: a = k * side + n; b = (k + 1) * side + n
			var base := verts.size()
			verts.append(verts[a] - Vector3(0, drop, 0))
			verts.append(verts[b] - Vector3(0, drop, 0))
			norms.append(norms[a]); norms.append(norms[b])
			uvs.append(uvs[a]); uvs.append(uvs[b])
			idx.append_array(PackedInt32Array([a, base, b, b, base, base + 1]))
	tans.resize(verts.size() * 4)
	for v in verts.size():
		tans[v * 4] = 1.0
		tans[v * 4 + 3] = 1.0
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, AssetLib.material("terrain"))
	if terrain == null:
		terrain = MeshInstance3D.new()
		terrain.name = "Terrain"
		terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(terrain)
	terrain.mesh = mesh
	terrain_lod = lod

func _build_ground_collision() -> void:
	ground_body = StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	var w := 65
	var data := PackedFloat32Array()
	data.resize(w * w)
	for j in w:
		for i in w:
			data[j * w + i] = world.height(origin.x + float(i), origin.z + float(j))
	shape.map_width = w
	shape.map_depth = w
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(32, 0, 32)
	ground_body.add_child(cs)
	add_child(ground_body)

# ---- vegetación instanciada ---------------------------------------------------------------------------------
func _veg_groups(want_trees: bool) -> Dictionary:
	var types: Array = world.info.get("veg_types", [])
	var groups: Dictionary = {}
	for i in _veg.size() / 6:
		var t := String(types[int(_veg[i * 6])])
		if t.begins_with("tree_") != want_trees:
			continue
		if not groups.has(t):
			groups[t] = []
		var b := Basis(Vector3.UP, _veg[i * 6 + 4]).scaled(Vector3.ONE * _veg[i * 6 + 5])
		(groups[t] as Array).append(Transform3D(b, Vector3(_veg[i * 6 + 1], _veg[i * 6 + 2], _veg[i * 6 + 3]) - origin))
	return groups

func _mm(mesh: Mesh, xforms: Array, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Malla solo con la superficie de hojas (para el nivel lejano: un único dibujado por especie).
static func leaf_only(rel: String) -> Mesh:
	if _leaf_only.has(rel):
		return _leaf_only[rel]
	var src := AssetLib.mesh(rel)
	var out: Mesh = src
	if src != null and src.get_surface_count() > 1:
		var am := ArrayMesh.new()
		for s in src.get_surface_count():
			var mat := src.surface_get_material(s)
			if mat is ShaderMaterial:
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
				am.surface_set_material(am.get_surface_count() - 1, mat)
		if am.get_surface_count() > 0:
			out = am
	_leaf_only[rel] = out
	return out

func _show_trees(lvl: int) -> void:
	for l in 3:
		if l != lvl and tree_sets[l] != null:
			(tree_sets[l] as Node3D).queue_free()
			tree_sets[l] = null
	if tree_sets[lvl] != null:
		return
	var holder := Node3D.new()
	holder.name = "Trees%d" % lvl
	var groups := _veg_groups(true)
	if lvl == 2:                      # agrupa variantes: menos dibujados a lo lejos
		var merged: Dictionary = {}
		for t: String in groups.keys():
			var alias: String = LOD2_ALIAS.get(t, t)
			if not merged.has(alias):
				merged[alias] = []
			(merged[alias] as Array).append_array(groups[t])
		groups = merged
	for t: String in groups.keys():
		var rel := "vegetation/%s_lod%d" % [t, lvl]
		var mesh: Mesh = leaf_only(rel) if lvl == 2 else AssetLib.mesh(rel)
		if mesh != null:
			holder.add_child(_mm(mesh, groups[t], lvl < 2))
	add_child(holder)
	tree_sets[lvl] = holder

func _build_detail() -> void:
	detail = Node3D.new()
	detail.name = "Detail"
	var groups := _veg_groups(false)
	for t: String in groups.keys():
		if SOLID_VEG.has(t) and float(SOLID_VEG[t]) > 1.5:
			continue
		var mesh := AssetLib.mesh("vegetation/" + t)
		if mesh != null:
			detail.add_child(_mm(mesh, groups[t], t.begins_with("rock") or t == "fallen_log" or t == "stump"))
	add_child(detail)

func _build_big_veg() -> void:
	big_veg = Node3D.new()
	big_veg.name = "BigVeg"
	var groups := _veg_groups(false)
	for t: String in groups.keys():
		if SOLID_VEG.has(t) and float(SOLID_VEG[t]) > 1.5:
			var mesh := AssetLib.mesh("vegetation/" + t)
			if mesh != null:
				big_veg.add_child(_mm(mesh, groups[t], true))
	add_child(big_veg)

func _build_trunks() -> void:
	trunk_body = StaticBody3D.new()
	trunk_body.name = "Trunks"
	trunk_body.collision_layer = 1
	trunk_body.collision_mask = 0
	var types: Array = world.info.get("veg_types", [])
	var cyl: Dictionary = {}
	for i in _veg.size() / 6:
		var t := String(types[int(_veg[i * 6])])
		var sc := _veg[i * 6 + 5]
		var pos := Vector3(_veg[i * 6 + 1], _veg[i * 6 + 2], _veg[i * 6 + 3]) - origin
		var cs := CollisionShape3D.new()
		if t.begins_with("tree_"):
			var r := float((_veg_meta.get(t, {}) as Dictionary).get("trunk_r", 0.2)) * sc
			if r < 0.07:
				continue
			var rk := snappedf(r, 0.05)
			if not cyl.has(rk):
				var c := CylinderShape3D.new()
				c.radius = rk
				c.height = 4.0
				cyl[rk] = c
			cs.shape = cyl[rk]
			cs.position = pos + Vector3(0, 2.0, 0)
		elif SOLID_VEG.has(t):
			var sp := SphereShape3D.new()
			sp.radius = float(SOLID_VEG[t]) * sc
			cs.shape = sp
			cs.position = pos + Vector3(0, sp.radius * 0.45, 0)
		else:
			continue
		trunk_body.add_child(cs)
	add_child(trunk_body)

func _build_grass() -> void:
	var amount := Config.f("video", "grass")
	if grass != null:
		if grass.get_meta(&"amount", -1.0) == amount:
			return
		grass.queue_free()
		grass = null
	if amount <= 0.01:
		return
	grass = Node3D.new()
	grass.name = "Grass"
	grass.set_meta(&"amount", amount)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key * 7919 + 13)
	var sets := {"grass_a": [], "grass_b": [], "grass_flowers": [], "fern": []}
	var region := world.region_name(origin.x + 32.0, origin.z + 32.0)
	for i in int(1500.0 * amount):
		var x := origin.x + rng.randf() * WorldMap.SECTOR
		var z := origin.z + rng.randf() * WorldMap.SECTOR
		var c := world.cover(x, z)
		var wg := 1.0 - c.x - c.y - c.z
		var roll := rng.randf()
		var flags := world.cell_flags(x, z)
		var h := world.height(x, z)
		if h < world.water_level + 0.2 or (flags & (WorldMap.F_BUILDING | WorldMap.F_DECK)) != 0 or c.y > 0.55:
			continue
		var t := ""
		if c.x > 0.4 and roll < 0.22:
			t = "fern"
		elif wg > 0.35 and roll < wg:
			t = "grass_b" if (region in ["eras", "alto"] and rng.randf() < 0.6) else ("grass_flowers" if rng.randf() < 0.12 else "grass_a")
		if t == "":
			continue
		var s := rng.randf_range(0.75, 1.35)
		(sets[t] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(x, h - 0.03, z) - origin))
	for t: String in sets.keys():
		if not (sets[t] as Array).is_empty():
			var mi := _mm(AssetLib.mesh("vegetation/" + t), sets[t], false)
			mi.visibility_range_end = 78.0
			grass.add_child(mi)
	add_child(grass)

# ---- carreteras ----------------------------------------------------------------------------------------------------
func _build_roads() -> void:
	roads = Node3D.new()
	roads.name = "Roads"
	add_child(roads)
	var by_kind: Dictionary = {}
	for seg: Array in world.sector_road_segments(key):
		var r: Dictionary = world.roads[int(seg[0])]
		var kind := String(r.kind)
		if not by_kind.has(kind):
			by_kind[kind] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
		_ribbon(by_kind[kind], r.points, int(seg[1]), float(r.width))
	for kind: String in by_kind.keys():
		var d: Dictionary = by_kind[kind]
		if (d.v as PackedVector3Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = d.v
		arrays[Mesh.ARRAY_NORMAL] = d.n
		arrays[Mesh.ARRAY_TEX_UV] = d.uv
		arrays[Mesh.ARRAY_COLOR] = d.c
		arrays[Mesh.ARRAY_INDEX] = d.i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, AssetLib.material("road_" + kind))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roads.add_child(mi)

func _road_side(pts: Array, k: int) -> Vector3:
	var a: Array = pts[maxi(0, k - 1)]
	var b: Array = pts[mini(pts.size() - 1, k + 1)]
	var dir := Vector3(float(b[0]) - float(a[0]), 0, float(b[2]) - float(a[2])).normalized()
	return Vector3(-dir.z, 0, dir.x)

func _ribbon(d: Dictionary, pts: Array, k: int, width: float) -> void:
	var across: Array[float] = [-0.5 - 0.6 / width, -0.5 + 0.3 / width, 0.0, 0.5 - 0.3 / width, 0.5 + 0.6 / width]
	var alpha: Array[float] = [0.0, 1.0, 1.0, 1.0, 0.0]
	var base: int = (d.v as PackedVector3Array).size()
	for e in 2:
		var p: Array = pts[k + e]
		var c := Vector3(p[0], p[1], p[2])
		if c.y - world.height(c.x, c.z) > 0.9:          # tramo sobre un puente: lo cubre el modelo
			(d.v as PackedVector3Array).resize(base)
			(d.n as PackedVector3Array).resize(base)
			(d.uv as PackedVector2Array).resize(base)
			(d.c as PackedColorArray).resize(base)
			return
		var side := _road_side(pts, k + e)
		for a in 5:
			var wp := c + side * (across[a] * width)
			var y := world.height(wp.x, wp.z) + 0.07
			(d.v as PackedVector3Array).append(Vector3(wp.x, y, wp.z) - origin)
			(d.n as PackedVector3Array).append(world.normal(wp.x, wp.z))
			(d.uv as PackedVector2Array).append(Vector2(across[a] + 0.5, float(k + e) * 4.0))
			(d.c as PackedColorArray).append(Color(1, 1, 1, alpha[a]))
	for a in 4:
		var v0 := base + a
		var v1 := base + 5 + a
		(d.i as PackedInt32Array).append_array(PackedInt32Array([v0, v1, v0 + 1, v0 + 1, v1, v1 + 1]))

# ---- objetos sueltos ---------------------------------------------------------------------------------------------------
func _build_props(big: bool) -> void:
	var holder := Node3D.new()
	holder.name = "PropsBig" if big else "PropsSmall"
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var defs := DataFiles.props()
	for pi: int in world.sector_props(key):
		var p: Dictionary = world.props[pi]
		var model := String(p.model)
		if (model in BIG_PROPS or model.begins_with("sign_")) != big:
			continue
		var lp: Vector3 = (p.pos as Vector3) - origin
		var inst := BuildingFactory.place_prop(model, lp, float(p.yaw), body)
		holder.add_child(inst)
		var def: Dictionary = defs.get(model, {})
		if def.has("spin") or def.has("sway"):
			inst.set_script(load("res://scripts/world/prop_motion.gd"))
			inst.call("setup", String(def.get("spin", "")), String(def.get("sway", "")))
		if def.has("station"):
			var st := Interactables.Station.new()
			st.setup(String(def.station), clampf(float((def.get("size", [1, 1, 1]) as Array)[1]) * 0.5, 0.5, 1.3))
			st.position = lp
			holder.add_child(st)
	add_child(holder)
	if big:
		props_big = holder
	else:
		props_small = holder

# ---- edificios e interiores -------------------------------------------------------------------------------------------------
func _build_buildings() -> void:
	buildings = Node3D.new()
	buildings.name = "Buildings"
	for bi: int in world.sector_buildings(key):
		var b: Dictionary = world.buildings[bi]
		var node := BuildingFactory.create(String(b.type), true, false)
		node.name = "B%d" % bi
		node.transform = Transform3D((b.xf as Transform3D).basis, (b.pos as Vector3) - origin)
		buildings.add_child(node)
	add_child(buildings)

func _build_interiors() -> void:
	interiors = Node3D.new()
	interiors.name = "Interiors"
	add_child(interiors)
	for bi: int in world.sector_buildings(key):
		var b: Dictionary = world.buildings[bi]
		var meta: Dictionary = b.meta
		var holder := Node3D.new()
		holder.transform = Transform3D((b.xf as Transform3D).basis, (b.pos as Vector3) - origin)
		interiors.add_child(holder)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		holder.add_child(body)
		for p: Dictionary in meta.get("props", []):
			holder.add_child(BuildingFactory.place_prop(String(p.model), DataFiles.v3(p.pos), float(p.yaw), body))
		for d: Dictionary in meta.get("doors", []):
			var door := Interactables.Door.new()
			door.setup(bi, d)
			holder.add_child(door)
			WorldRoot.current.door_nodes[door.oid] = door
		for c: Dictionary in meta.get("containers", []):
			var def := DataFiles.prop(String(c.model))
			var box := Interactables.Box.new()
			var lp := DataFiles.v3(c.pos) + Vector3(0, float(def.get("wall", 0.0)), 0)
			box.setup(Protocol.container_key(bi, int(c.id)), "props/" + String(c.model), def, tr("NAME_" + String(c.model).to_upper()))
			box.position = lp
			box.rotation_degrees.y = float(c.yaw)
			holder.add_child(box)
			BuildingFactory.add_prop_collider(body, String(c.model), lp, float(c.yaw))
			WorldRoot.current.box_nodes[box.oid] = box
		if meta.has("doc") and not (meta.get("loot", []) as Array).is_empty():
			var doc := Interactables.Doc.new()
			doc.setup(bi, String(meta.doc))
			var lp2 := DataFiles.v3(meta.loot[0].pos)
			doc.position = lp2 + Vector3(0.35, 0.0, 0.2)
			holder.add_child(doc)
		for l: Dictionary in meta.get("lights", []):
			var col: Array = l.get("color", [1, 0.85, 0.6])
			var lamp := WorldFx.lamp(DataFiles.v3(l.pos), Color(col[0], col[1], col[2]), float(l.get("range", 6.0)), 1.3)
			holder.add_child(lamp)
