class_name CreatureView
extends Node3D
## CreatureView — representación en el cliente de una criatura simulada por el servidor.
##
## Interpola posición y giro entre fotos de estado, elige la animación según el estado de la
## IA (reposo, patrulla, investigación, alerta, búsqueda, retirada, recuperación…) y reproduce
## sus sonidos. La lógica y la percepción viven en ServerCreatures.

const ANIMS := {
	"brumal": {0: "idle", 1: "walk", 2: "search", 3: "alert", 4: "run", 5: "sniff", 6: "run", 7: "trot", 8: "rest"},
	"zarzo": {0: "idle", 1: "walk", 9: "run", 10: "curled"},
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

func setup(id: int, type_name: String) -> void:
	cid = id
	type = type_name
	model = AssetLib.model("creatures/" + type)
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	CharacterLook.fix_loops(anim, "res://data/models/%s.json" % type)
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

func event(code: int) -> void:
	match code:
		1: AudioDirector.play_at("brumal_alert", global_position, 3.0)
		2: AudioDirector.play_at("brumal_call", global_position, 2.0)
		3: AudioDirector.play_at("farol_puff", global_position, 2.0)

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
	if anim == null:
		return
	var state := int(b[3])
	var moving := int(b[4])
	var map: Dictionary = ANIMS.get(type, {})
	var clip := String(map.get(state, "idle" if type != "farol" else "float"))
	if type == "brumal":
		if state in [2, 5] and moving == 0:
			clip = "sniff"
		elif state == 0:
			_idle_alt += delta
			clip = "look" if fmod(_idle_alt, 14.0) > 9.0 else "idle"
		elif moving == 0 and state in [1, 7]:
			clip = "idle"
	elif type == "zarzo":
		if state == 0:
			_idle_alt += delta
			clip = "forage" if fmod(_idle_alt, 10.0) > 5.0 else "idle"
		elif state == 10 and _state != 10:
			clip = "curl"
		elif moving == 2:
			clip = "run"
	if state != _state and state == 10 and type == "zarzo":
		AudioDirector.play_at("zarzo_squeak", global_position)
	_state = state
	if clip != _clip and anim.has_animation(clip):
		if _clip == "curl" and clip == "curled" and anim.is_playing() and anim.current_animation == "curl":
			return
		_clip = clip
		anim.play(clip, 0.3)
