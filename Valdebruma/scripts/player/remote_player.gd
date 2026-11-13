class_name RemotePlayer
extends Node3D
## RemotePlayer — representación de otro jugador real conectado.
##
## Responsabilidad: interpolar entre las fotos de estado del servidor (se dibuja ~120 ms en el
## pasado para suavizar latencia y pérdida de paquetes), animar el cuerpo según velocidad y
## acción, y mostrar equipo, colores y nombre. No contiene lógica de juego.

const DELAY_MS := 130

var peer := 0
var model: Node3D
var anim: AnimationPlayer
var label: Label3D
var info: Dictionary = {}
var _buf: Array = []          # [ms local, pos, yaw, flags, anim]
var _speed := 0.0
var _last_pos := Vector3.ZERO
var _clip := ""
var _held: Node3D
var _held_id := "-"
var _light: OmniLight3D
var _clips: Dictionary = {}   # metadatos de los clips (duración, bucle, velocidad de marcha)

func setup(d: Dictionary) -> void:
	peer = int(d.id)
	model = AssetLib.model("characters/survivor")
	model.rotation.y = PI
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	CharacterLook.fix_loops(anim, "res://data/models/survivor.json")
	_clips = DataFiles.dict("res://data/models/survivor.json").get("clips", {})
	label = Label3D.new()
	label.position.y = 2.05
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.004
	label.no_depth_test = false
	label.modulate = Color(0.95, 0.93, 0.85)
	add_child(label)
	_light = OmniLight3D.new()
	_light.position = Vector3(0.2, 1.3, -0.4)
	_light.omni_range = 8.0
	_light.light_color = Color(1.0, 0.85, 0.6)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	apply_info(d)

func apply_info(d: Dictionary) -> void:
	info = d
	var eq: Dictionary = d.get("eq", {})
	CharacterLook.equipment(model, eq)
	CharacterLook.tint(model, d.get("cos", {}), bool(eq.get("rain", false)))
	var same_group := int(d.get("group", 0)) != 0 and int(d.get("group", 0)) == int(Session.group.get("id", 0))
	label.text = String(d.get("name", ""))
	label.modulate = Color(0.6, 0.9, 0.7) if same_group else Color(0.95, 0.93, 0.85)
	label.visible = Config.b("game", "show_names") and (not bool(d.get("hide", false)) or same_group)
	var held_id := String(eq.get("held", ""))
	if held_id != _held_id:
		_held_id = held_id
		if _held != null:
			_held.queue_free()
			_held = null
		var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
		if held_id != "" and sk != null and sk.find_bone("item.R") >= 0 and AssetLib.has_model("items/" + held_id):
			var att := BoneAttachment3D.new()
			att.bone_name = "item.R"       # palma: Y = eje del puño, Z = hacia los dedos
			sk.add_child(att)
			att.add_child(AssetLib.model("items/" + held_id))
			_held = att

func push(pos: Vector3, yaw: float, flags: int, a: int) -> void:
	_buf.append([Time.get_ticks_msec(), pos, yaw, flags, a])
	if _buf.size() > 12:
		_buf.pop_front()
	if _buf.size() == 1:
		global_position = pos
		_last_pos = pos

func _process(delta: float) -> void:
	if _buf.is_empty():
		return
	var t := Time.get_ticks_msec() - DELAY_MS
	var a: Array = _buf[0]
	var b: Array = _buf[_buf.size() - 1]
	for i in _buf.size() - 1:
		if int(_buf[i + 1][0]) >= t:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var span := maxf(1.0, float(int(b[0]) - int(a[0])))
	var k := clampf(float(t - int(a[0])) / span, 0.0, 1.25)      # extrapola un poco si falta un paquete
	global_position = (a[1] as Vector3).lerp(b[1], k)
	rotation.y = lerp_angle(float(a[2]), float(b[2]), minf(k, 1.0))
	var v := (global_position - _last_pos).length() / maxf(delta, 0.001)
	_last_pos = global_position
	_speed = lerpf(_speed, v, clampf(delta * 8.0, 0.0, 1.0))
	var fl := int(b[3])
	_light.visible = (fl & Protocol.F_LIGHT) != 0
	_animate(fl, int(b[4]))

## Ritmo de un clip de marcha para que los pies no patinen: velocidad real / velocidad del clip.
func _pace(clip: String, lo: float, hi: float) -> float:
	var v := float((_clips.get(clip, {}) as Dictionary).get("speed", 0.0))
	return clampf(_speed / v, lo, hi) if v > 0.05 else 1.0

func _animate(fl: int, code: int) -> void:
	if anim == null:
		return
	var clip := "idle"
	var rate := 1.0
	if (fl & Protocol.F_DOWN) != 0:
		clip = "faint"
	elif (fl & Protocol.F_SWIM) != 0:
		clip = "swim"
		rate = clampf(0.6 + _speed * 0.35, 0.6, 1.4)
	elif code != Protocol.A.NONE and _speed < 1.0:
		clip = ["idle", "interact", "pickup", "consume", "open_door", "search", "build", "wave", "point", "sit", "cold", "tired", "sit"][clampi(code, 0, 12)]
	elif (fl & Protocol.F_ON_FLOOR) == 0 and _speed > 1.0:
		clip = "fall"
	elif (fl & Protocol.F_CROUCH) != 0:
		clip = "crouch_walk" if _speed > 0.4 else "crouch_idle"
		rate = _pace(clip, 0.6, 1.7) if _speed > 0.4 else 1.0
	elif _speed > 4.9:
		clip = "sprint"
		rate = _pace(clip, 0.8, 1.3)
	elif _speed > 2.1:
		clip = "jog"
		rate = _pace(clip, 0.7, 1.5)
	elif _speed > 0.35:
		clip = "walk"
		rate = _pace(clip, 0.6, 1.5)
	if clip != _clip and anim.has_animation(clip):
		_clip = clip
		anim.play(clip, 0.25)
	anim.speed_scale = rate
