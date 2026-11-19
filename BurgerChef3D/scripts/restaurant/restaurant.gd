class_name Restaurant
extends Node3D
## Construye el restaurante 3D completo (cocina, mostrador, estaciones, sala, iluminación y decoración) a partir de
## resources/data/layout.json y de la personalización equipada. Los muebles y equipos usan modelos reales: KayKit
## Restaurant Bits y Kenney Food Kit (CC0) y los modelos propios del usuario (assets/models/custom/: freidora,
## dispensador de bebidas, bandeja, campanita, bote de basura, lámpara colgante y planta). La estructura (paredes,
## suelos, techo), los carteles, las ventanas y los clientes siguen siendo geometría procedural low-poly.

const SURF := 1.06         # altura de la superficie de trabajo de los mostradores
const MODULE_W := 2.0      # ancho de un módulo de mostrador o fogón de KayKit
const MODULE_D := 2.0      # fondo de un módulo de mostrador de KayKit
const STOVE_TOP := 1.17    # altura de las parrillas del fogón, donde se apoya la comida
const BIN_SURF := 0.75     # mostradores de ingredientes: más bajos para ver desde arriba qué hay en cada caja
## Cesta de la freidora (modelo propio): las patatas del modelo están a esta fracción de su alto y de su fondo.
const FRYER_BASKET_H := 0.8
const FRYER_BASKET_Z := -0.063
const LAMP_SPOTS: Array = [Vector3(-3.2, 0, 0.9), Vector3(0, 0, 0.9), Vector3(3.2, 0, 0.9),
	Vector3(-3.5, 0, 4.5), Vector3(-0.6, 0, 4.5), Vector3(2.4, 0, 4.5), Vector3(-4, 0, -4), Vector3(0, 0, -4.5), Vector3(4, 0, -3)]
const PLANT_SPOTS: Array = [Vector3(-8.2, 0, -8.2), Vector3(5.2, 0, -8.3), Vector3(-8.2, 0, -0.3), Vector3(8.3, 0, -0.5)]
## Plantas extra en las esquinas libres de la cocina (artículo «Jardín completo» del catálogo de decoración).
const KITCHEN_PLANT_SPOTS: Array = [Vector3(-8.25, 0, 8.25), Vector3(8.25, 0, 8.25)]
## Modelo de la caja de cada ingrediente de estantería.
const CRATE_MODELS: Dictionary = {"bun_bottom": "crate_buns", "bun_top": "crate_buns", "lettuce": "crate_lettuce",
	"tomato": "crate_tomatoes", "onion": "crate_onions", "fries": "crate_potatoes"}

var service_points: Array = []
var bells: Array = []
var sink: SinkStation = null
var trash: TrashBin = null
var assembly_boards: Array = []
var grill: CookStation = null
var fryer: CookStation = null
var crates: Array = []
var player_spawn: Vector3 = Vector3(0.9, 0.1, 5.8)
var room_h: float = 3.4
var _cfg: Dictionary = {}
var _menu_root: Node3D = null

func build() -> void:
	_cfg = Catalog.layout
	var r: Dictionary = _cfg["room"]
	room_h = float(r["height"])
	var sp: Dictionary = _cfg["player_spawn"]
	player_spawn = Vector3(float(sp["x"]), 0.1, float(sp["z"]))
	_build_environment()
	_build_shell()
	_build_service_counter()
	_build_island()
	_build_bins()
	_build_utilities()
	_build_hall()
	_build_lighting()
	_build_decor()
	SettingsManager.apply_graphics()

# ------------------------------------------------------------------ personalización
func _eq_color(category: String, key: String, fallback: String) -> Color:
	return Util.html_color(str(EconomyManager.equipped_param(category, key, fallback)))

func set_free_restock(v: bool) -> void:
	for c in crates:
		(c as IngredientCrate).restock_free = v

func refill_all() -> void:
	for c in crates:
		(c as IngredientCrate).refill()

# ------------------------------------------------------------------ entorno
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("#a9d8f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html("#fff2dc")
	env.ambient_light_energy = 0.68
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 28, 0)
	sun.light_energy = 0.45
	sun.light_color = Color.html("#fff0d6")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0
	sun.directional_shadow_fade_start = 0.85
	sun.add_to_group(Const.GROUP_SHADOW_LIGHTS)
	add_child(sun)

# ------------------------------------------------------------------ estructura
func _build_shell() -> void:
	var r: Dictionary = _cfg["room"]
	var x0 := float(r["x_min"])
	var x1 := float(r["x_max"])
	var z0 := float(r["z_min"])
	var z1 := float(r["z_max"])
	var split := float(r["split_z"])
	var door0 := float(r["door_x_min"])
	var w := x1 - x0
	var d := z1 - z0
	var h := room_h
	var wall := Prims.mat(_eq_color("wall", "color", "#f3e3c3"), 0.9)
	var hall_floor := Prims.tex_mat(str(EconomyManager.equipped_param("floor", "tex", "floor_red")), Color.WHITE, 0.5)
	var kitchen_floor := Prims.tex_mat("tiles", Color.WHITE, 0.5)
	# suelos (con colisión) y terreno exterior
	var hall_body := Prims.collider_box(self, Vector3(w, 0.2, split - z0), Vector3((x0 + x1) * 0.5, -0.1, (z0 + split) * 0.5))
	Prims.box(hall_body, Vector3(w, 0.2, split - z0), Vector3.ZERO, hall_floor, false)
	var kit_body := Prims.collider_box(self, Vector3(w, 0.2, z1 - split), Vector3((x0 + x1) * 0.5, -0.1, (split + z1) * 0.5))
	Prims.box(kit_body, Vector3(w, 0.2, z1 - split), Vector3.ZERO, kitchen_floor, false)
	Prims.box(self, Vector3(80, 0.2, 80), Vector3(0, -0.14, -20), Prims.mat(Color.html("#8e939a")), false)
	Prims.box(self, Vector3(9, 0.06, 4), Vector3((door0 + x1) * 0.5, -0.02, -10.5), Prims.mat(Color.html("#b9bdc2")), false)
	# paredes (sin sombra para no oscurecer el interior)
	_wall(Vector3(x0 - 0.15, h * 0.5, (z0 + z1) * 0.5), Vector3(0.3, h, d + 0.6), wall)
	_wall(Vector3(x1 + 0.15, h * 0.5, (z0 + z1) * 0.5), Vector3(0.3, h, d + 0.6), wall)
	_wall(Vector3((x0 + x1) * 0.5, h * 0.5, z1 + 0.15), Vector3(w + 0.6, h, 0.3), wall)
	var seg_w := door0 - (x0 - 0.3)
	_wall(Vector3(x0 - 0.3 + seg_w * 0.5, h * 0.5, z0 - 0.15), Vector3(seg_w, h, 0.3), wall)
	Prims.box(self, Vector3(x1 - door0, 0.9, 0.3), Vector3((door0 + x1) * 0.5, h - 0.45, z0 - 0.15), wall, false)
	Prims.box(self, Vector3(x1 - door0 + 0.2, 0.12, 0.4), Vector3((door0 + x1) * 0.5, h - 0.95, z0 - 0.15), Prims.mat(Palette.KETCHUP), false)
	# ceiling
	Prims.box(self, Vector3(w + 0.6, 0.2, d + 0.6), Vector3((x0 + x1) * 0.5, h + 0.1, (z0 + z1) * 0.5), Prims.mat(Color.html("#fff6e6")), false)
	# friso de azulejo en la cocina
	var tiles := Prims.tex_mat("tiles", Color.WHITE, 0.5)
	Prims.box(self, Vector3(0.03, 1.5, z1 - split), Vector3(x0 + 0.015, 0.75, (split + z1) * 0.5), tiles, false)
	Prims.box(self, Vector3(0.03, 1.5, z1 - split), Vector3(x1 - 0.015, 0.75, (split + z1) * 0.5), tiles, false)
	Prims.box(self, Vector3(w, 1.5, 0.03), Vector3((x0 + x1) * 0.5, 0.75, z1 - 0.015), tiles, false)
	# pilares que cierran el hueco entre el mostrador y las paredes laterales
	for g in _cfg["gates"]:
		var gb := Prims.collider_box(self, Vector3(float(g["w"]), h, float(g["d"])), Vector3(float(g["x"]), h * 0.5, float(g["z"])))
		Prims.box(gb, Vector3(float(g["w"]), h, float(g["d"])), Vector3.ZERO, wall, false)

func _wall(pos: Vector3, size: Vector3, m: Material) -> void:
	var body := Prims.collider_box(self, size, pos)
	Prims.box(body, size, Vector3.ZERO, m, false)

# ------------------------------------------------------------------ mostrador y puestos de servicio
## Personalización de color como tinte sobre el modelo real: la opción por defecto deja el modelo tal cual.
func _eq_tint(category: String, key: String, default_hex: String) -> Color:
	var hex := str(EconomyManager.equipped_param(category, key, default_hex))
	if hex.to_lower() == default_hex.to_lower():
		return Color.WHITE
	return Color.WHITE.lerp(Util.html_color(hex), 0.7)

## Mostrador continuo hecho con módulos de mostrador de KayKit estirados al ancho (w) y al fondo (d) pedidos.
## center es el centro del mostrador respecto a parent y rot_y gira su frente (+Z del modelo); height es la altura de
## la encimera (SURF salvo los mostradores bajos de ingredientes, BIN_SURF).
func _counter_run(parent: Node3D, center: Vector3, w: float, d: float, rot_y: float, tint: Color, with_collider: bool, height: float = SURF) -> void:
	var n := maxi(1, roundi(w / MODULE_W))
	var mw := w / float(n)
	var run := Node3D.new()
	run.position = Vector3(center.x, 0.0, center.z)
	run.rotation.y = rot_y
	parent.add_child(run)
	for i in n:
		var m := ModelLib.spawn("counter_a" if i % 2 == 0 else "counter_b", Vector3(mw / MODULE_W, height, d / MODULE_D))
		m.position = Vector3(-w * 0.5 + mw * (float(i) + 0.5), 0.0, 0.0)
		if tint != Color.WHITE:
			ModelLib.tint(m, tint)
		run.add_child(m)
	if with_collider:
		var along_z := absf(sin(rot_y)) > 0.5
		var size := Vector3(d, height, w) if along_z else Vector3(w, height, d)
		Prims.collider_box(parent, size, Vector3(center.x, height * 0.5, center.z))

func _build_service_counter() -> void:
	var sc: Dictionary = _cfg["service_counter"]
	var tint := _eq_tint("counter", "color", "#e9e4d8")
	# el frente (puertas) del mueble mira a la sala de clientes
	_counter_run(self, Vector3(float(sc["x"]), 0, float(sc["z"])), float(sc["w"]), float(sc["d"]), PI, tint, true)
	var ts := ModelLib.size_of("tray")
	var i := 0
	for e in _cfg["service_points"]:
		var x := float(e["x"])
		var sp := ServicePoint.new()
		sp.position = Vector3(x, 0.0, float(sc["z"]) - 0.05)
		sp.configure(i, SURF + 0.03, Vector3(x, 0, float(e["front_z"])), Vector3(x, 0, float(e["back_z"])))
		sp.add_box_collider(Vector3(1.5, 0.06, 0.7), Vector3(0, SURF + 0.03, 0))
		# bandeja de servicio (modelo propio) estirada a 1,5 x 0,7 m para las tres ranuras, con 7 cm de alto
		var tray := ModelLib.spawn("tray", Vector3(1.5 / ts.x, 0.07 / ts.y, 0.7 / ts.z))
		tray.position = Vector3(0, SURF, 0)
		sp.add_child(tray)
		sp.set_tray_model(tray)
		add_child(sp)
		service_points.append(sp)
		_make_bell(sp, x)
		# placa con el número del puesto (las comandas del HUD usan el mismo número)
		var plate := Prims.box(self, Vector3(0.5, 0.32, 0.06), Vector3(x, 2.25, 0.62), Prims.mat(Palette.BROWN))
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Prims.label3d(self, str(i + 1), Vector3(x, 2.25, 0.66), 0.006, 72, Palette.CREAM, false)
		Prims.cyl(self, 0.012, 0.012, room_h - 2.4, Vector3(x, (room_h + 2.4) * 0.5, 0.62), Prims.mat(Palette.BROWN_LIGHT), 6)
		i += 1

func _make_bell(sp: ServicePoint, x: float) -> void:
	var bell := ServiceBell.new()
	bell.position = Vector3(x + 1.05, SURF, float(_cfg["service_counter"]["z"]) - 0.2)
	bell.point = sp
	bell.add_box_collider(Vector3(0.32, 0.26, 0.32), Vector3(0, 0.13, 0))
	# campanita de servicio (modelo propio, base en y=0): al pulsarla se aplasta y rebota entera. El modelo va dentro
	# de un nodo pivote de escala 1, porque la animación de ServiceBell lleva la escala a (1, 0,6, 1) y de vuelta a 1
	var pivot := Node3D.new()
	bell.add_child(pivot)
	pivot.add_child(ModelLib.spawn("bell"))
	bell.set_dome(pivot)
	add_child(bell)
	bells.append(bell)

# ------------------------------------------------------------------ isla de cocina
func _build_island() -> void:
	var tint := _eq_tint("counter", "color", "#e9e4d8")
	# plancha: se cocina directamente sobre las cuatro parrillas de un fogón de KayKit
	var g: Dictionary = _cfg["grill"]
	grill = CookStation.new()
	grill.position = Vector3(float(g["x"]), 0, float(g["z"]))
	grill.add_child(ModelLib.spawn("stove"))
	var burners: Array = [Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]
	grill.configure("grill", burners, STOVE_TOP)
	grill.add_box_collider(Vector3(float(g["w"]), STOVE_TOP + 0.03, float(g["d"])), Vector3(0, (STOVE_TOP + 0.03) * 0.5, 0))
	grill.set_blocking(true)
	_hood(grill)
	add_child(grill)
	# mostrador de apoyo junto a la plancha
	var sa: Dictionary = _cfg["stage_a"]
	_stage(float(sa["x"]), float(sa["z"]), float(sa["w"]), float(sa["d"]), tint)
	# isla de montaje con tres tablas de cortar
	var isl: Dictionary = _cfg["island"]
	_counter_run(self, Vector3(float(isl["x"]), 0, float(isl["z"])), float(isl["w"]), float(isl["d"]), 0.0, tint, true)
	var bsz := ModelLib.size_of("board")
	var idx := 0
	for b in _cfg["assembly"]:
		var st := AssemblyStation.new()
		st.position = Vector3(float(b["x"]), 0, float(b["z"]))
		var board := ModelLib.spawn("board", Vector3(1.0 / bsz.x, 0.06 / bsz.y, 0.72 / bsz.z))
		board.position = Vector3(0, SURF, 0)
		st.add_child(board)
		st.configure(idx, SURF + 0.06)
		st.add_box_collider(Vector3(1.0, 0.1, 0.72), Vector3(0, SURF + 0.05, 0))
		add_child(st)
		assembly_boards.append(st)
		idx += 1
	# freidora: dos freidoras de sobremesa (modelo propio) sobre un mostrador, con la cesta y el asa hacia la
	# cocina (+Z); la segunda aparece al comprar la mejora. La comida se apoya sobre las patatas de la cesta y la
	# marca de ranura bloqueada se queda en la encimera.
	var f: Dictionary = _cfg["fryer"]
	var fw := float(f["w"])
	var fd := float(f["d"])
	fryer = CookStation.new()
	fryer.position = Vector3(float(f["x"]), 0, float(f["z"]))
	_counter_run(fryer, Vector3.ZERO, fw, fd, 0.0, tint, false)
	var fsz := ModelLib.size_of("fryer")
	var baskets: Array = [Vector2(-fw * 0.25, FRYER_BASKET_Z * fsz.z), Vector2(fw * 0.25, FRYER_BASKET_Z * fsz.z)]
	fryer.configure("fryer", baskets, SURF + fsz.y * FRYER_BASKET_H, SURF)
	for bp in baskets:
		var unit := ModelLib.spawn("fryer")
		unit.position = Vector3((bp as Vector2).x, SURF, 0.0)
		fryer.add_child(unit)
		fryer.slot_props.append(unit)
	fryer.refresh_capacity()
	var fh := SURF + fsz.y
	fryer.add_box_collider(Vector3(fw, fh, fd), Vector3(0, fh * 0.5, 0))
	fryer.set_blocking(true)
	_hood(fryer)
	add_child(fryer)
	var sb: Dictionary = _cfg["stage_b"]
	_stage(float(sb["x"]), float(sb["z"]), float(sb["w"]), float(sb["d"]), tint)

func _stage(x: float, z: float, w: float, d: float, tint: Color) -> void:
	var st := CounterSurface.new()
	st.position = Vector3(x, 0, z)
	_counter_run(st, Vector3.ZERO, w, d, 0.0, tint, false)
	for o in [-w * 0.25, w * 0.25]:
		st.add_slot(Vector3(float(o), SURF, 0.0))
	st.add_box_collider(Vector3(w, SURF, d), Vector3(0, SURF * 0.5, 0))
	st.set_blocking(true)
	add_child(st)

## Campana extractora de KayKit sobre un fogón. El modelo nace pegado a la pared (su fondo está en z=0), así que se
## desplaza para centrarla sobre los fogones, y se estira en vertical para que su chimenea llegue al techo.
func _hood(parent: Node3D) -> void:
	var bottom := 2.2
	var sy := (room_h - bottom) / ModelLib.size_of("hood").y
	var hood := ModelLib.spawn("hood", Vector3(1.0, sy, 1.0))
	hood.position = Vector3(0.0, bottom - 2.0 * sy, -0.8)
	parent.add_child(hood)

# ------------------------------------------------------------------ cajas de ingredientes
## Pared en la que está un puesto de ingrediente según su posición: "south", "west" o "east".
func _bin_wall(x: float) -> String:
	if x < -7.0:
		return "west"
	if x > 7.0:
		return "east"
	return "south"

func _build_bins() -> void:
	var tint := _eq_tint("counter", "color", "#e9e4d8")
	# un mostrador bajo (BIN_SURF) y continuo por pared bajo todos los ingredientes de esa pared, para ver desde
	# arriba lo que hay en cada caja o tabla
	var runs: Dictionary = {}
	for b in _cfg["bins"]:
		var x := float(b["x"])
		var z := float(b["z"])
		var wall := _bin_wall(x)
		var along := x if wall == "south" else z
		var fixed := z if wall == "south" else x
		if not runs.has(wall):
			runs[wall] = [along, along, fixed]
		var r: Array = runs[wall]
		r[0] = minf(float(r[0]), along)
		r[1] = maxf(float(r[1]), along)
	for wall in runs:
		var r: Array = runs[wall]
		var length := float(r[1]) - float(r[0]) + 1.2
		var mid := (float(r[0]) + float(r[1])) * 0.5
		var fixed := float(r[2])
		var center := Vector3(mid, 0, fixed) if wall == "south" else Vector3(fixed, 0, mid)
		# el frente (+Z del modelo) mira hacia el interior de la cocina
		var rot := PI
		if wall == "west":
			rot = PI * 0.5
		elif wall == "east":
			rot = -PI * 0.5
		_counter_run(self, center, length, 1.0, rot, tint, true, BIN_SURF)
	var bsz := ModelLib.size_of("board")
	for b in _cfg["bins"]:
		var id := str(b["ingredient"])
		var x := float(b["x"])
		var z := float(b["z"])
		var along_z := _bin_wall(x) != "south"
		var group := str(b.get("group", "shelf"))
		var face := 0.0
		if along_z:
			face = PI * 0.5 if x < 0.0 else -PI * 0.5
		var crate := IngredientCrate.new()
		crate.position = Vector3(x, 0, z)
		crate.set_blocking(true)
		var top_y := BIN_SURF
		var label_y := -1.0
		if group == "dispenser":
			# dispensador de bebidas (modelo propio) con un vaso de muestra a cada lado
			var dm := ModelLib.spawn("dispenser")
			dm.position = Vector3(0, BIN_SURF, 0)
			dm.rotation.y = face
			crate.add_child(dm)
			var dsz := ModelLib.size_of("dispenser")
			top_y = BIN_SURF + 0.02
			label_y = BIN_SURF + dsz.y + 0.25
			for side in [-1.0, 1.0]:
				var cup := FoodModels.build_item(id, 0.0)
				cup.scale = Vector3.ONE * 0.85
				var off := float(side) * (dsz.x * 0.5 + 0.12)
				cup.position = Vector3(0.0 if along_z else off, BIN_SURF, off if along_z else 0.0)
				crate.add_child(cup)
		elif group == "fridge":
			# carnes y queso: tabla de cortar de KayKit sobre el mostrador con dos muestras del ingrediente encima
			# (en la cocina no se ponen encima de una nevera)
			var board := ModelLib.spawn("board", Vector3(1.0 / bsz.x, 0.05 / bsz.y, 0.72 / bsz.z))
			board.position = Vector3(0, BIN_SURF, 0)
			board.rotation.y = face
			crate.add_child(board)
			top_y = BIN_SURF + 0.05
			for k in 2:
				var item := FoodModels.build_item(id, 0.0)
				item.scale = Vector3.ONE * 0.9
				var off := (float(k) - 0.5) * 0.46
				item.position = Vector3(0.0 if along_z else off, top_y, off if along_z else 0.0)
				crate.add_child(item)
			label_y = top_y + 0.6
		else:
			# caja de KayKit con su contenido
			var ckey := str(CRATE_MODELS.get(id, "crate_buns"))
			var cm := ModelLib.spawn(ckey)
			cm.position = Vector3(0, BIN_SURF, 0)
			crate.add_child(cm)
			top_y = BIN_SURF + ModelLib.size_of(ckey).y
			if id == "bun_bottom" or id == "bun_top":
				# las dos cajas de pan usan el mismo modelo: un pan de muestra distingue el inferior del superior
				var sample := FoodModels.build_item(id, 0.0)
				sample.scale = Vector3.ONE * 0.8
				sample.position = Vector3(0.0, top_y - 0.04, 0.0)
				crate.add_child(sample)
		var box_h := maxf(top_y, label_y - 0.25) if group == "dispenser" else top_y
		crate.add_box_collider(Vector3(1.0, box_h, 1.0), Vector3(0, box_h * 0.5, 0))
		crate.setup(id, top_y, Vector3(0, label_y if label_y > 0.0 else top_y + 0.45, 0))
		add_child(crate)
		crates.append(crate)

# ------------------------------------------------------------------ papelera y fregadero
func _build_utilities() -> void:
	var t: Dictionary = _cfg["trash"]
	var bin := TrashBin.new()
	bin.position = Vector3(float(t["x"]), 0, float(t["z"]))
	bin.set_blocking(true)
	bin.add_box_collider(Vector3(0.8, 1.0, 0.8), Vector3(0, 0.5, 0))
	# bote de basura (modelo propio) con su frente (logo y pedal) mirando hacia el interior de la cocina
	var tm := ModelLib.spawn("trash")
	tm.rotation.y = -PI * 0.5 if float(t["x"]) > 0.0 else PI * 0.5
	bin.add_child(tm)
	Prims.label3d(bin, Loc.t("label.trash"), Vector3(0, 1.3, 0), 0.004, 56, Color.WHITE, true, 10)
	add_child(bin)
	trash = bin
	var s: Dictionary = _cfg["sink"]
	# fregadero de KayKit contra la pared este, con el frente hacia la cocina: lava las bandejas sucias
	sink = SinkStation.new()
	sink.position = Vector3(float(s["x"]), 0, float(s["z"]))
	sink.set_blocking(true)
	var sink_len := 1.1
	var sink_depth := 1.0
	var sm := ModelLib.spawn("sink", Vector3(sink_len / MODULE_W, SURF, sink_depth / MODULE_D))
	sm.rotation.y = -PI * 0.5
	sink.add_child(sm)
	sink.add_box_collider(Vector3(sink_depth, SURF, sink_len), Vector3(0, SURF * 0.5, 0))
	sink.configure(SURF)
	var sl := Prims.label3d(sink, Loc.t("label.sink"), Vector3(0, 2.05, 0), 0.0034, 38, Color.WHITE, true, 8)
	sl.visibility_range_begin = IngredientCrate.LABEL_HIDE_NEAR
	add_child(sink)

# ------------------------------------------------------------------ sala de clientes
func _build_hall() -> void:
	var table_tint := _eq_tint("tables", "color", "#b57b45")
	var chair_tint := _eq_tint("chairs", "color", "#d8392b")
	var ts := ModelLib.size_of("table")
	for t in _cfg["tables"]:
		var tx := float(t["x"])
		var tz := float(t["z"])
		# mesa redonda de KayKit ajustada a 1,4 m de diámetro y 0,78 m de alto
		var tbl := ModelLib.spawn("table", Vector3(1.4 / ts.x, 0.78 / ts.y, 1.4 / ts.z))
		tbl.position = Vector3(tx, 0, tz)
		if table_tint != Color.WHITE:
			ModelLib.tint(tbl, table_tint)
		add_child(tbl)
		var i := 0
		for p in [Vector2(1.0, 0), Vector2(-1.0, 0), Vector2(0, 1.0), Vector2(0, -1.0)]:
			var chair := ModelLib.spawn("chair_a" if i % 2 == 0 else "chair_b")
			chair.position = Vector3(tx + p.x, 0, tz + p.y)
			# el respaldo del modelo está en su lado -Z, así que su frente (+Z) debe mirar hacia la mesa
			chair.rotation.y = atan2(-p.x, -p.y)
			if chair_tint != Color.WHITE:
				ModelLib.tint(chair, chair_tint)
			add_child(chair)
			i += 1

# ------------------------------------------------------------------ iluminación
func _build_lighting() -> void:
	var lamp_col := _eq_color("lamps", "color", "#ffd9a0")
	var bulb := Prims.mat(lamp_col, 0.3, 2.0)
	# lámpara colgante (modelo propio) con el florón pegado al techo; el color equipado tiñe la luz y la bombilla,
	# que asoma bajo la pantalla
	var lh := ModelLib.size_of("lamp").y
	for p in LAMP_SPOTS:
		var lamp := ModelLib.spawn("lamp")
		lamp.position = Vector3(p.x, room_h - lh, p.z)
		add_child(lamp)
		var b := Prims.sphere(self, 0.07, Vector3(p.x, room_h - lh + 0.05, p.z), bulb, 1.0, false, 10)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rendimiento: en el renderizador Compatibility (móviles) cada luz puntual obliga a dibujar otra vez cada objeto que
	# toca, así que las 6 luces de las lámparas multiplicaban el coste de la escena. Su aporte (un relleno cálido y suave)
	# se consigue casi igual con una luz direccional de relleno sin sombras, que se calcula en la misma pasada.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-75, -150, 0)
	fill.light_energy = 0.32
	fill.light_color = lamp_col
	fill.shadow_enabled = false
	fill.light_specular = 0.2
	add_child(fill)

# ------------------------------------------------------------------ decoración y señalización
func _build_decor() -> void:
	var z0 := float(_cfg["room"]["z_min"])
	var sign_col := _eq_color("sign", "color", "#d8392b")
	var look := EconomyManager.look_level()
	# cartel principal en la pared del fondo de la sala
	var board := Prims.box(self, Vector3(5.6, 1.15, 0.14), Vector3(-1.0, 2.5, z0 + 0.08), Prims.mat(Palette.BROWN), false)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Prims.box(self, Vector3(5.8, 0.06, 0.16), Vector3(-1.0, 3.1, z0 + 0.09), Prims.mat(sign_col, 0.5, 0.0 if look < 3 else 1.2), false)
	Prims.box(self, Vector3(5.8, 0.06, 0.16), Vector3(-1.0, 1.9, z0 + 0.09), Prims.mat(sign_col, 0.5, 0.0 if look < 3 else 1.2), false)
	var title := Prims.label3d(self, "BURGER CHEF 3D", Vector3(-1.0, 2.5, z0 + 0.17), 0.011, 96, sign_col.lightened(0.25), false, 14)
	title.outline_modulate = Palette.BROWN
	# ventanas
	for wx in [-5.2, 3.0]:
		Prims.box(self, Vector3(2.9, 1.5, 0.06), Vector3(wx, 1.9, z0 + 0.04), Prims.unshaded(Color.html("#cfeaff")), false)
		var frame := Prims.mat(Palette.CREAM, 0.7)
		Prims.box(self, Vector3(3.1, 0.1, 0.1), Vector3(wx, 2.68, z0 + 0.06), frame, false)
		Prims.box(self, Vector3(3.1, 0.1, 0.1), Vector3(wx, 1.12, z0 + 0.06), frame, false)
		Prims.box(self, Vector3(0.1, 1.6, 0.1), Vector3(wx - 1.5, 1.9, z0 + 0.06), frame, false)
		Prims.box(self, Vector3(0.1, 1.6, 0.1), Vector3(wx + 1.5, 1.9, z0 + 0.06), frame, false)
		Prims.box(self, Vector3(0.06, 1.5, 0.1), Vector3(wx, 1.9, z0 + 0.06), frame, false)
	# cartel de la cocina (pared sur) con el icono real de la hamburguesa del pack de iconos
	var south := float(_cfg["room"]["z_max"])
	var sign_mat := StandardMaterial3D.new()
	sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign_mat.albedo_texture = UIKit.icon("burger", 256.0)
	sign_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sign_quad := Prims.quad(self, Vector2(1.5, 1.5), Vector3(0, 2.4, south - 0.04), sign_mat)
	sign_quad.rotation.y = PI
	var deco: Dictionary = {}
	deco["plants"] = bool(EconomyManager.equipped_param("decor", "plants", false)) or look >= 1
	deco["posters"] = bool(EconomyManager.equipped_param("decor", "posters", false))
	if bool(deco["plants"]):
		var k := 0
		for p in PLANT_SPOTS:
			_plant(p, float(k) * 1.7)
			k += 1
	if bool(EconomyManager.equipped_param("decor", "kitchen_plants", false)):
		var j := 0
		for p in KITCHEN_PLANT_SPOTS:
			_plant(p, 0.8 + float(j) * 2.1)
			j += 1
	if bool(deco["posters"]):
		var xw := float(_cfg["room"]["x_min"]) + 0.04
		var cols: Array = [Palette.KETCHUP, Palette.MUSTARD, Palette.TEAL]
		var zi := -6.5
		for c in cols:
			var frame2 := Prims.box(self, Vector3(0.06, 1.1, 0.8), Vector3(xw, 1.9, zi), Prims.mat(Palette.BROWN), false)
			frame2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Prims.box(self, Vector3(0.07, 0.9, 0.62), Vector3(xw + 0.01, 1.9, zi), Prims.mat((c as Color).lightened(0.2)), false)
			zi += 2.4
	if look >= 2:
		var open := Prims.label3d(self, Loc.t("label.open"), Vector3((float(_cfg["room"]["door_x_min"]) + float(_cfg["room"]["x_max"])) * 0.5 - 0.1, 2.05, z0 + 0.12), 0.007, 80, Color.html("#7cff9b"), false, 10)
		open.outline_modulate = Color.html("#0b3d1c")

## Planta en maceta (modelo propio); cada una gira distinto para que no parezcan copias.
func _plant(p: Vector3, yaw: float) -> void:
	var plant := ModelLib.spawn("plant")
	plant.position = p
	plant.rotation.y = yaw
	add_child(plant)

## Panel de menú sobre el mostrador con las recetas de este turno y sus precios.
func set_menu(recipe_ids: Array) -> void:
	if _menu_root != null:
		_menu_root.queue_free()
	_menu_root = Node3D.new()
	add_child(_menu_root)
	var n := recipe_ids.size()
	var h := 0.55 + 0.26 * n
	var board := Prims.box(_menu_root, Vector3(3.4, h, 0.08), Vector3(0, 2.15 + (1.25 - h) * 0.5 + 0.3, 0.56), Prims.mat(Palette.BROWN), false)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lines := ""
	for rid in recipe_ids:
		var r := Catalog.recipe(str(rid))
		lines += "%s  -  %d\n" % [Catalog.name_of(r), Util.to_int(r.get("price", 0))]
	var y := board.position.y
	var head := Prims.label3d(_menu_root, Loc.t("label.menu"), Vector3(0, y + h * 0.5 - 0.22, 0.61), 0.006, 72, Palette.MUSTARD, false, 8)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := Prims.label3d(_menu_root, lines.strip_edges(), Vector3(0, y - 0.12, 0.61), 0.0042, 56, Palette.CREAM, false, 6)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
