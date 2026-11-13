class_name CreatureView
extends Node3D
## CreatureView — representación en el cliente de una criatura simulada por el servidor.
##
## Interpola posición y giro entre fotos de estado, elige la animación según el estado de la
## IA (reposo, patrulla, investigación, alerta, búsqueda, retirada, recuperación…) y reproduce
## sus sonidos. La lógica y la percepción viven en ServerCreatures.

const ANIMS := {
	"brumal": {0: "idle", 1: "walk", 2: "search", 3: "alert", 4: "run", 5: "sniff", 6: "run", 7: "trot", 8: "rest"},
	"zarzo": {0: "idle", 1: "walk", 3: "alert", 9: "run", 10: "curled"},
	"farol": {0: "float", 1: "drift", 2: "drift", 3: "puff", 6: "retreat", 7: "drift", 8: "recover"},
}

var cid := 0
var type := ""
var model: Node3D
var anim: AnimationPlayer
var _buf: Array = []
var _clip := ""
var _state := -1
var _idle_alt := 0.0
var _clips: Dictionary = {}
var _speed := 0.0
var _last_pos := Vector3.ZERO
var _busy_until := 0      # ms: clip de transición en curso (salir de la madriguera)

func setup(id: int, type_name: String) -> void:
	cid = id
	type = type_name
	model = AssetLib.model("creatures/" + type)
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	CharacterLook.fix_loops(anim, "res://data/models/%s.json" % type)
	_clips = DataFiles.dict("res://data/models/%s.json" % type).get("clips", {})
	if type == "farol":
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.9)
		l.omni_range = 6.0
		l.light_energy = 1.1
		l.shadow_enabled = false
		l.position.y = 0.2
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		l.distance_fade_length = 12.0
		add_child(l)
	_idle_alt = randf() * 8.0

func push(pos: Vector3, yaw: float, state: int, moving: int) -> void:
	_buf.append([Time.get_ticks_msec(), pos, yaw, state, moving])
	if _buf.size() > 8:
		_buf.pop_front()
	if _buf.size() == 1:
		global_position = pos
		rotation.y = yaw
		_last_pos = pos

func event(code: int) -> void:
	match code:
		1: AudioDirector.play_at("brumal_alert", global_position, 3.0)
		2: AudioDirector.play_at("brumal_call", global_position, 2.0)
		3:
			AudioDirector.play_at("farol_puff", global_position, 2.0)
			var ground := GameData.world.ground(global_position.x, global_position.z)
			Vfx.cloud(Vector3(global_position.x, ground + 0.05, global_position.z), 3.2, 2.4, Color(0.45, 1.0, 0.82), Color(0.1, 0.42, 0.36))

func _process(delta: float) -> void:
	if _buf.is_empty():
		return
	var t := Time.get_ticks_msec() - 160
	var a: Array = _buf[0]
	var b: Array = _buf[_buf.size() - 1]
	for i in _buf.size() - 1:
		if int(_buf[i + 1][0]) >= t:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var k := clampf(float(t - int(a[0])) / maxf(1.0, float(int(b[0]) - int(a[0]))), 0.0, 1.15)
	global_position = (a[1] as Vector3).lerp(b[1], k)
	rotation.y = lerp_angle(float(a[2]), float(b[2]), minf(k, 1.0))
	var v := (global_position - _last_pos).length() / maxf(delta, 0.001)
	_last_pos = global_position
	_speed = lerpf(_speed, v, clampf(delta * 6.0, 0.0, 1.0))
	if anim == null:
		return
	var state := int(b[3])
	var moving := int(b[4])
	var map: Dictionary = ANIMS.get(type, {})
	var clip := String(map.get(state, "idle" if type != "farol" else "float"))
	if type == "brumal":
		if moving != 0:
			# el paso lo decide la velocidad real: andar, trote o carrera
			clip = "run" if _speed > 4.2 else ("trot" if _speed > 1.9 else ("search" if state in [2, 5] else "walk"))
		elif state in [2, 5]:
			clip = "sniff"
		elif state == 0:
			_idle_alt += delta
			clip = "look" if fmod(_idle_alt, 14.0) > 9.0 else "idle"
		elif state in [1, 7]:
			clip = "idle"
	elif type == "zarzo":
		if state == 0:
			_idle_alt += delta
			var k2 := fmod(_idle_alt, 16.0)
			clip = "forage" if k2 > 9.0 else ("dig" if k2 > 6.0 else "idle")
		elif state == 10:
			clip = "curl" if _state != 10 else "curled"
		elif moving == 2:
			clip = "run"
		elif moving == 0:
			clip = "alert" if state == 3 else "idle"
	if state != _state and state == 10 and type == "zarzo":
		AudioDirector.play_at("zarzo_squeak", global_position)
	if type == "zarzo" and _state == 10 and state != 10 and anim.has_animation("uncurl"):
		_clip = "uncurl"                       # sale de la tierra antes de seguir a lo suyo
		anim.speed_scale = 1.6
		anim.play("uncurl", 0.1)
		_busy_until = Time.get_ticks_msec() + int(float((_clips.get("uncurl", {}) as Dictionary).get("length", 2.0)) / 1.6 * 1000.0)
	_state = state
	if Time.get_ticks_msec() < _busy_until:
		return
	if clip != _clip and anim.has_animation(clip):
		if _clip == "curl" and clip == "curled" and anim.is_playing() and anim.current_animation == "curl":
			return
		_clip = clip
		anim.play(clip, 0.3)
	var cv := float((_clips.get(_clip, {}) as Dictionary).get("speed", 0.0))
	anim.speed_scale = clampf(_speed / cv, 0.6, 2.0) if cv > 0.05 and _speed > 0.1 else 1.0
