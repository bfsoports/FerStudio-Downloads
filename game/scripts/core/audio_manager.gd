extends Node
## Pooled 2D/3D sound effects and music with crossfades.
## Sounds are referenced by name: res://assets/audio/sfx/<name>.wav
## Variants <name>_1.wav, <name>_2.wav ... are picked randomly when present.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_2D := 12
const POOL_3D := 24

var _streams := {}          # name -> Array[AudioStream]
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next2d := 0
var _next3d := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_name := ""
var _ambience: AudioStreamPlayer
var _last_played := {}       # name -> msec, throttles spam


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		p3.attenuation_filter_cutoff_hz = 6000.0
		add_child(p3)
		_pool3d.append(p3)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_current = _music_a
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	add_child(_ambience)


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _get_stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var list: Array[AudioStream] = []
		var base := SFX_DIR + sound
		if ResourceLoader.exists(base + ".wav"):
			list.append(load(base + ".wav"))
		for i in range(1, 8):
			var v := "%s_%d.wav" % [base, i]
			if ResourceLoader.exists(v):
				list.append(load(v))
			else:
				break
		_streams[sound] = list
	var arr: Array = _streams[sound]
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


func _throttled(sound: String, min_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if _last_played.has(sound) and now - int(_last_played[sound]) < min_ms:
		return true
	_last_played[sound] = now
	return false


func play(sound: String, volume_db: float = 0.0, pitch_random: float = 0.04, min_interval_ms: int = 0) -> void:
	if min_interval_ms > 0 and _throttled(sound, min_interval_ms):
		return
	var s := _get_stream(sound)
	if s == null:
		return
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch_random: float = 0.06, max_distance: float = 45.0, min_interval_ms: int = 0) -> void:
	if min_interval_ms > 0 and _throttled(sound, min_interval_ms):
		return
	var s := _get_stream(sound)
	if s == null:
		return
	# pick a free player, otherwise steal round-robin
	var p: AudioStreamPlayer3D = null
	for i in POOL_3D:
		var cand := _pool3d[(_next3d + i) % POOL_3D]
		if not cand.playing:
			p = cand
			_next3d = (_next3d + i + 1) % POOL_3D
			break
	if p == null:
		p = _pool3d[_next3d]
		_next3d = (_next3d + 1) % POOL_3D
	p.global_position = pos
	p.stream = s
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	p.play()


func play_music(track: String, fade: float = 2.0, volume_db: float = -6.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		return
	var next := _music_b if _music_current == _music_a else _music_a
	next.stream = load(path)
	next.volume_db = -60.0
	next.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(next, "volume_db", volume_db, fade)
	tw.tween_property(_music_current, "volume_db", -60.0, fade)
	var old := _music_current
	tw.chain().tween_callback(old.stop)
	_music_current = next


func stop_music(fade: float = 1.5) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music_current, "volume_db", -60.0, fade)
	tw.tween_callback(_music_current.stop)


func play_ambience(track: String, volume_db: float = -10.0) -> void:
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		return
	_ambience.stream = load(path)
	_ambience.volume_db = volume_db
	_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


func vibrate(ms: int) -> void:
	if Settings.vibration and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)
