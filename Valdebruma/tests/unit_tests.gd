extends Node
## Pruebas unitarias sin ventana: inventario, persistencia (escritura atómica, corrupción y copias),
## saneado de entradas de red, mapa del mundo, referencias cruzadas de datos, recursos de arte
## referenciados, traducciones y escenas/guiones que deben cargar.
## Uso: godot --headless --path . -- --unit-tests   (código de salida 0 = todo correcto)
## Se lanza desde Boot para que los autoloads ya existan al compilar los guiones probados.

var _ok := 0
var _fail := 0
var _section := ""

func check(cond: bool, what: String) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
		print("  FALLO [%s] %s" % [_section, what])

var _finished: Dictionary = {}

func section(name: String) -> void:
	_section = name
	print("— " + name)

## Marca la sección como terminada: si un error de ejecución la corta a medias, no llega aquí.
func done() -> void:
	_finished[_section] = true

func run() -> void:
	await get_tree().process_frame
	var gd: Node = get_node("/root/GameData")
	var sections := ["inventario", "persistencia", "saneado de red", "mundo", "referencias de datos", "recursos de arte", "sonido", "traducciones", "guiones y escenas"]
	test_inventory(gd)
	test_persistence()
	test_guard()
	test_world(gd)
	test_data(gd)
	test_assets(gd)
	test_audio()
	test_translations()
	test_scripts()
	for sec: String in sections:
		if not _finished.has(sec):
			_fail += 1
			print("  FALLO [%s] la sección no terminó (error de ejecución)" % sec)
	print("RESULTADO PRUEBAS UNITARIAS: %s (%d correctas, %d fallos)" % ["CORRECTO" if _fail == 0 else "CON FALLOS", _ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

# ---- inventario -----------------------------------------------------------------------------------
func test_inventory(gd: Node) -> void:
	section("inventario")
	var inv := Inventory.new(4)
	var mx: int = gd.stack_max("palo")
	check(mx > 1, "palo es apilable")
	check(inv.add("palo", mx + 3) == 0, "añadir más de una pila cabe en dos huecos")
	check(inv.count("palo") == mx + 3 and inv.used() == 2, "cuenta y huecos usados")
	check(inv.add("objeto_inexistente", 2) == 2, "un objeto desconocido no entra")
	check(not inv.remove("palo", mx + 4), "no se quita más de lo que hay")
	check(inv.count("palo") == mx + 3, "un fallo al quitar no altera nada")
	check(inv.remove("palo", 3) and inv.count("palo") == mx, "quitar unidades")
	check(inv.add_all("linterna", 1), "añadir objeto no apilable")
	var full := Inventory.new(1)
	full.add("linterna", 1)
	check(not full.add_all("linterna", 1), "add_all es todo o nada")
	check(full.room_for("palo") == 0, "sin sitio")
	var a := Inventory.new(3)
	var b := Inventory.new(3)
	a.add("piedra", 5)
	check(Inventory.transfer(a, 0, b, -1, 2) and a.count("piedra") == 3 and b.count("piedra") == 2, "transferir parte de una pila")
	check(not Inventory.transfer(a, 0, b, -1, 99), "no se transfiere más de la pila")
	check(a.count("piedra") + b.count("piedra") == 5, "las transferencias no duplican ni pierden")
	check(a.has_all({"piedra": 3}) and not a.has_all({"piedra": 4}), "has_all")
	check(a.remove_all({"piedra": 3}) and a.is_empty(), "remove_all")
	var c := Inventory.new(5)
	c.add("palo", 8)
	check(c.split(0, 3) and c.used() == 2 and c.count("palo") == 8, "dividir una pila")
	var round_trip := Inventory.from_data(c.to_data(), c.size())
	check(round_trip.count("palo") == 8 and round_trip.size() == 5, "serializar y recuperar")
	var shrink := c.resize(1)
	check(c.size() == 1 and c.count("palo") == 8 and shrink.is_empty(), "reducir huecos reagrupa en las pilas que quedan")
	var d := Inventory.new(2)
	d.add("linterna", 1)
	d.add("martillo", 1)
	var over := d.resize(1)
	check(d.size() == 1 and over.size() == 1 and String(over[0].id) == "martillo", "reducir huecos devuelve lo que no cabe")
	done()

# ---- persistencia -------------------------------------------------------------------------------------
func test_persistence() -> void:
	section("persistencia")
	var dir := "user://unit_tests"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/estado.json"
	for f in [path, path + ".bak1", path + ".bak2", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	check(ServerPersistence.write_atomic(path, {"v": 1, "n": "uno"}), "escritura atómica")
	check(int(ServerPersistence.read_safe(path).get("v", 0)) == 1, "lectura con suma de control")
	ServerPersistence.write_atomic(path, {"v": 2})
	ServerPersistence.write_atomic(path, {"v": 3})
	check(FileAccess.file_exists(path + ".bak1") and FileAccess.file_exists(path + ".bak2"), "rotación de copias")
	check(not FileAccess.file_exists(path + ".tmp"), "no quedan temporales")
	# corrupción: se altera un byte del cuerpo; debe recuperarse de la copia .bak1 (v = 2)
	var text := FileAccess.get_file_as_string(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text.left(text.length() - 3) + "9}\n")
	f.close()
	var rec := ServerPersistence.read_safe(path)
	check(int(rec.get("v", 0)) == 2, "un archivo dañado se descarta y se usa la copia (%s)" % str(rec))
	var aside := false
	for n in DirAccess.get_files_at(dir):
		if n.begins_with("estado.json.corrupt-"):
			aside = true
	check(aside, "el archivo dañado se aparta para revisarlo")
	# archivo truncado (corte de corriente a mitad de escritura)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("abc")
	f.close()
	check(not ServerPersistence.read_safe(path).is_empty(), "un archivo truncado no deja el estado vacío si hay copia")
	check(ServerPersistence.read_safe(dir + "/no_existe.json").is_empty(), "un archivo inexistente devuelve vacío")
	done()

# ---- entradas de red -----------------------------------------------------------------------------------
func test_guard() -> void:
	section("saneado de red")
	check(Guard.i("7", 0, 10, -1) == -1, "texto en lugar de entero se rechaza")
	check(Guard.i(99, 0, 10, -1) == -1 or Guard.i(99, 0, 10, -1) == 10, "entero fuera de rango no se acepta tal cual")
	check(Guard.f(NAN, 0.0, 1.0, 0.5) == 0.5, "NaN se rechaza")
	check(Guard.s("x".repeat(500), 16).length() <= 16, "cadenas recortadas")
	check(Guard.v3(INF, 0, 0) == null, "vector con infinito se rechaza")
	check(Guard.arr("no", 2).is_empty(), "no-array se rechaza")
	check(Guard.dict([1, 2]).is_empty(), "no-diccionario se rechaza")
	check(Protocol.name_ok("Ana") and not Protocol.name_ok("a") and not Protocol.name_ok("<script>"), "validación de nombres")
	done()

# ---- mundo ----------------------------------------------------------------------------------------------
func test_world(gd: Node) -> void:
	section("mundo")
	var w: WorldMap = gd.world
	check(w != null, "mapa cargado")
	if w == null:
		return
	var mid := WorldMap.SIZE * 0.5
	check(is_finite(w.height(mid, mid)), "altura finita")
	check(w.in_bounds(mid, mid) and not w.in_bounds(-5.0, mid), "límites del valle")
	check(w.places.size() >= 20, "lugares del valle (%d)" % w.places.size())
	var spawns_ok := true
	for sp: Variant in (w.info.get("spawns", []) as Array):
		if not w.walkable(float(sp[0]), float(sp[1])):
			spawns_ok = false
	check(not (w.info.get("spawns", []) as Array).is_empty(), "hay puntos de aparición")
	check(spawns_ok, "los puntos de aparición son transitables")
	var regions := {}
	for i in 400:
		var x := fmod(float(i) * 97.3, WorldMap.SIZE)
		var z := fmod(float(i) * 61.7, WorldMap.SIZE)
		regions[w.region_name(x, z)] = true
	check(regions.size() >= 6, "variedad de regiones (%d)" % regions.size())
	check(WorldMap.sector_key(10, 10) != WorldMap.sector_key(70, 10), "claves de sector distintas")
	done()

# ---- datos ----------------------------------------------------------------------------------------------
func test_data(gd: Node) -> void:
	section("referencias de datos")
	var items: Dictionary = gd.items
	check(items.size() >= 40, "objetos (%d)" % items.size())
	for id: String in gd.recipes.keys():
		var r: Dictionary = gd.recipes[id]
		check(items.has(String(r.out)), "receta %s produce un objeto existente" % id)
		for k: String in (r.get("in", {}) as Dictionary).keys():
			check(items.has(k), "receta %s usa %s existente" % [id, k])
		if String(r.get("tool", "")) != "":
			check(items.has(String(r.tool)), "herramienta de %s existe" % id)
	for id: String in gd.loot_tables.keys():
		for e: Array in gd.loot_tables[id].get("items", []):
			check(items.has(String(e[0])), "botín %s: %s existe" % [id, e[0]])
	for id: String in gd.structures.keys():
		var s: Dictionary = gd.structures[id]
		for key: String in ["cost", "frame_cost"]:
			for k: String in (s.get(key, {}) as Dictionary).keys():
				check(items.has(k), "estructura %s: %s existe" % [id, k])
	for id: String in gd.harvest.keys():
		for y: Array in gd.harvest[id].get("yield", []):
			check(items.has(String(y[0])), "recolección %s: %s existe" % [id, y[0]])
	for id: String in items.keys():
		var it: Dictionary = items[id]
		var eff: Variant = (it.get("use", {}) as Dictionary).get("effect")
		if eff is Array:
			check(gd.effects.has(String(eff[0])), "efecto de %s existe" % id)
		for k: String in ["gives", "fuel"]:
			if String(it.get(k, "")) != "":
				check(items.has(String(it[k])), "%s de %s existe" % [k, id])
		check(String((it.name as Dictionary).get("es", "")) != "" and String((it.name as Dictionary).get("en", "")) != "", "%s tiene nombre es/en" % id)
	var prog: Dictionary = gd.progression
	for id: String in (prog.get("contracts", {}) as Dictionary).keys():
		var c: Dictionary = prog.contracts[id]
		for k: String in (c.get("reward", {}) as Dictionary).keys():
			check(items.has(k), "recompensa de %s existe" % id)
		if c.has("read"):
			check(gd.documents.has(String(c.read)), "documento del encargo %s existe" % id)
	for id: String in (prog.get("cosmetics", {}) as Dictionary).keys():
		var u := String(prog.cosmetics[id].get("unlock", ""))
		check(u == "" or (prog.challenges as Dictionary).has(u) or (prog.achievements as Dictionary).has(u), "desbloqueo de %s existe" % id)
	for id: String in gd.creatures.keys():
		check(AssetLib.has_model(String(gd.creatures[id].model)), "modelo de criatura %s" % id)
	done()

# ---- recursos de arte -----------------------------------------------------------------------------------
func test_assets(gd: Node) -> void:
	section("recursos de arte")
	for id: String in gd.items.keys():
		check(AssetLib.has_model("items/" + id), "modelo del objeto %s" % id)
		check(ResourceLoader.exists("res://assets/icons/items/%s.png" % id), "icono del objeto %s" % id)
	for id: String in gd.structures.keys():
		check(AssetLib.has_model("structures/" + id), "modelo de estructura %s" % id)
	var props := DataFiles.dict("res://data/models/props.json")
	for b: Dictionary in gd.world.buildings:
		check(ResourceLoader.exists("res://data/buildings/%s.json" % String(b.type)), "ficha del edificio %s" % b.type)
	var missing := 0
	for p: Variant in gd.world.props:
		var t := String(p[0]) if p is Array else String((p as Dictionary).get("type", ""))
		if t != "" and not props.has(t):
			missing += 1
	check(missing == 0, "todos los objetos del mundo tienen modelo (%d sin modelo)" % missing)
	for m: String in ["characters/survivor", "characters/fp_arms", "creatures/brumal", "creatures/zarzo", "creatures/farol"]:
		var n := AssetLib.model(m)
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false) if n != null else null
		check(ap != null and ap.get_animation_list().size() >= 6, "%s tiene animaciones" % m)
		if n != null:
			n.free()
	var mats := DataFiles.dict("res://data/materials.json")
	for k: String in mats.keys():
		if not k.begins_with("_"):
			check(ResourceLoader.exists("res://assets/materials/%s.tres" % k), "material %s generado" % k)
	for s: String in Vfx.SCENES.values():
		check(ResourceLoader.exists(s), "efecto " + s.get_file())
	done()

# ---- sonido ---------------------------------------------------------------------------------------------
func test_audio() -> void:
	section("sonido")
	var names := {}
	var re := RegEx.create_from_string("(?:play_ui|play_at|stream|play_music)\\(\"([a-z0-9_]+)\"")
	for path in _files("res://scripts", ".gd") + _files("res://autoload", ".gd"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			names[m.get_string(1)] = true
	for b: String in AudioDirector.BEDS:
		names[b] = true
	for surf: String in ["dirt", "grass", "leaves", "road", "rock", "water", "wood"]:
		for i in 3:
			names["step_%s_%d" % [surf, i + 1]] = true
	for n: String in ["door_close", "container_close"]:
		names[n] = true
	check(names.size() >= 40, "sonidos referenciados (%d)" % names.size())
	for n: String in names.keys():
		var path := "res://assets/audio/%s.ogg" % n
		check(ResourceLoader.exists(path), "existe el sonido " + n)
	for b: String in AudioDirector.BEDS + ["fire_loop", "music_menu"]:
		var st: AudioStreamOggVorbis = load("res://assets/audio/%s.ogg" % b)
		check(st != null and st.loop, "%s se reproduce en bucle" % b)
	done()

# ---- traducciones ----------------------------------------------------------------------------------------
func test_translations() -> void:
	section("traducciones")
	var used := {}
	var re := RegEx.create_from_string("tr\\(\"([A-Z0-9_]+)\"\\)")
	for path in _files("res://scripts", ".gd") + _files("res://autoload", ".gd"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = true
	for lang: String in ["es", "en"]:
		TranslationServer.set_locale(lang)
		var missing: PackedStringArray = []
		for k: String in used.keys():
			if TranslationServer.translate(k) == k:
				missing.append(k)
		check(missing.is_empty(), "claves sin texto en %s: %s" % [lang, ", ".join(missing)])
	TranslationServer.set_locale("es")
	check(used.size() > 150, "claves usadas (%d)" % used.size())
	done()

func _files(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub, ext))
	return out

# ---- guiones y escenas ------------------------------------------------------------------------------------
func test_scripts() -> void:
	section("guiones y escenas")
	for path in _files("res://scripts", ".gd") + _files("res://autoload", ".gd"):
		var s: GDScript = load(path)
		check(s != null and s.can_instantiate(), "compila " + path)
	for path in ["res://scenes/boot/boot.tscn", "res://scenes/boot/splash.tscn", "res://scenes/menus/menu.tscn", "res://scenes/world/world.tscn"]:
		check(load(path) is PackedScene, "escena " + path)
	done()
