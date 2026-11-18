extends Node3D
## BuildMode — colocación de estructuras con vista previa.
##
## Responsabilidad: mostrar el armazón «fantasma» de la pieza elegida donde mira el jugador,
## encajar las piezas modulares (2,4 m) en suelos existentes, permitir girarla y enviar la
## PETICIÓN de colocación. La validación local (distancia, agua, pendiente, solape, materiales)
## solo orienta al jugador: el servidor repite todas las comprobaciones y decide.
## Datos: type/def (data/structures.json). Señales: ninguna; informa al HUD con set_build_text.

const MODULE := 2.4
const WALL_H := 2.65
const MAX_DIST := 6.8

var active := false
var type := ""
var def: Dictionary = {}
var yaw_deg := 0.0
var pos := Vector3.ZERO
var why := ""
var _ghost: Node3D = null
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _turn := 0.0
var _last_ok := true

func _ready() -> void:
	_ok_mat = _mat(Color(0.45, 0.95, 0.6, 0.45))
	_bad_mat = _mat(Color(0.95, 0.35, 0.25, 0.45))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func start(type_id: String) -> void:
	cancel()
	def = GameData.structures.get(type_id, {})
	if def.is_empty():
		return
	type = type_id
	var rel := "structures/%s_frame" % type
	if not AssetLib.has_model(rel):
		rel = "structures/" + type
	_ghost = AssetLib.model(rel)
	add_child(_ghost)
	_paint(_ok_mat)
	active = true
	_turn = 0.0
	var pl := WorldRoot.current.player
	yaw_deg = snappedf(rad_to_deg(pl.yaw), 15.0)
	set_process(true)

func cancel() -> void:
	active = false
	type = ""
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if Ui.hud != null:
		Ui.hud.call("set_build_text", "", true)

func rotate_step() -> void:
	_turn += 90.0 if bool(def.get("snap", false)) else 15.0

func confirm() -> void:
	if not active:
		return
	if why != "":
		Ui.toast(tr("WHY_" + why.to_upper()), "bad", "warn")
		return
	Net.send(Protocol.C.BUILD_PLACE, [type, pos.x, pos.y, pos.z, yaw_deg])
	AudioDirector.play_ui("build_place")
	# las piezas modulares se suelen colocar en serie: el modo sigue activo con ellas
	if not bool(def.get("snap", false)):
		cancel()

func _paint(m: Material) -> void:
	for n: Node in _ghost.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_delta: float) -> void:
	if not active or WorldRoot.current == null:
		return
	var pl := WorldRoot.current.player
	var world := GameData.world
	# punto al que mira el jugador sobre el terreno (paso fijo a lo largo del rayo de cámara)
	var origin := pl.cam.global_position
	var dir := -pl.cam.global_transform.basis.z
	var aim := origin + dir * 3.0
	for i in 28:
		var p := origin + dir * (0.6 + float(i) * 0.25)
		if p.y <= world.ground(p.x, p.z) + 0.05:
			aim = p
			break
		aim = p
	var flat := Vector2(aim.x - pl.global_position.x, aim.z - pl.global_position.z)
	if flat.length() > MAX_DIST:
		flat = flat.normalized() * MAX_DIST
		aim.x = pl.global_position.x + flat.x
		aim.z = pl.global_position.z + flat.y
	aim.y = world.ground(aim.x, aim.z)
	var yaw := snappedf(rad_to_deg(pl.yaw), 15.0) + _turn
	var snapped_to := {}
	if bool(def.get("snap", false)):
		snapped_to = _nearest_floor(aim)
	if not snapped_to.is_empty():
		var base_pos: Vector3 = snapped_to.pos
		var byaw := float(snapped_to.yaw)
		var local := (aim - base_pos).rotated(Vector3.UP, -deg_to_rad(byaw))
		match type:
			"suelo":
				var cell := Vector3(roundf(local.x / MODULE) * MODULE, 0, roundf(local.z / MODULE) * MODULE)
				if cell.length() < 0.1:
					cell = Vector3(MODULE * signf(local.x), 0, 0) if absf(local.x) > absf(local.z) else Vector3(0, 0, MODULE * signf(local.z))
				aim = base_pos + cell.rotated(Vector3.UP, deg_to_rad(byaw))
				yaw = byaw
			"tejado":
				aim = base_pos + Vector3(0, WALL_H, 0)
				yaw = byaw + _turn
			_:
				if absf(local.x) > absf(local.z):
					aim = base_pos + Vector3(MODULE * 0.5 * signf(local.x), 0, 0).rotated(Vector3.UP, deg_to_rad(byaw))
					yaw = byaw + 90.0
				else:
					aim = base_pos + Vector3(0, 0, MODULE * 0.5 * signf(local.z)).rotated(Vector3.UP, deg_to_rad(byaw))
					yaw = byaw
	pos = aim
	yaw_deg = fposmod(yaw, 360.0)
	_ghost.global_position = pos
	_ghost.rotation_degrees = Vector3(0, yaw_deg, 0)
	why = _check(pl, not snapped_to.is_empty())
	var ok := why == ""
	if ok != _last_ok:
		_last_ok = ok
		_paint(_ok_mat if ok else _bad_mat)
	if Ui.hud != null:
		var name_ := GameData.text(def.get("name", type))
		var text := tr("BUILD_PLACE_HINT_TOUCH" if bool(Ui.hud.get("use_touch")) else "BUILD_PLACE_HINT") % name_
		Ui.hud.call("set_build_text", text if ok else name_ + " — " + tr("WHY_" + why.to_upper()), ok)

func _nearest_floor(p: Vector3) -> Dictionary:
	var best := {}
	var best_d := 3.4
	for id: int in Session.structs.keys():
		var s: Dictionary = Session.structs[id]
		if String(s.type) != "suelo":
			continue
		var d := Vector2(p.x - s.pos.x, p.z - s.pos.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best

## Mismas reglas que ServerActions.place_block, en versión orientativa.
func _check(pl: PlayerController, on_floor: bool) -> String:
	var world := GameData.world
	if Vector2(pos.x - pl.global_position.x, pos.z - pl.global_position.z).length() > 7.3:
		return "far"
	if not world.in_bounds(pos.x, pos.z, 6.0):
		return "bounds"
	var flags := world.cell_flags(pos.x, pos.z)
	var snap := bool(def.get("snap", false))
	for id: int in Session.structs.keys():
		var s: Dictionary = Session.structs[id]
		var od: Dictionary = GameData.structures.get(String(s.type), {})
		var dist := Vector2(pos.x - s.pos.x, pos.z - s.pos.z).length()
		if dist > 3.2:
			continue
		var min_d := 0.35 if (snap and bool(od.get("snap", false))) else (float(def.get("radius", 1.0)) + float(od.get("radius", 1.0))) * 0.8
		if dist < min_d and not (snap and String(s.type) == "suelo") and type != "tejado":
			return "overlap"
	if flags & WorldMap.F_BUILDING != 0 and world.building_at(pos + Vector3(0, 0.5, 0)) < 0 and not on_floor:
		return "blocked"
	if flags & WorldMap.F_ROAD != 0 and not snap:
		return "road"
	if world.height(pos.x, pos.z) < world.water_level - 0.1 and flags & WorldMap.F_DECK == 0:
		return "water"
	if not on_floor and type != "tejado" and world.slope_deg(pos.x, pos.z) > 28.0:
		return "slope"
	if not Session.inv.has_all(def.get("frame_cost", {})):
		return "materials"
	if bool(def.get("instant", false)) and not Session.inv.has_all(def.get("cost", {})):
		return "materials"
	return ""
