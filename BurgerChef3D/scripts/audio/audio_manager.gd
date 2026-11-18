extends Node
## Audio: buses Music y SFX creados por código, efectos con pool de reproductores (anti-repetición)
## y música en bucle con fundido. Si falta algún archivo el juego sigue funcionando en silencio.

const SFX_NAMES: Array = ["click", "pickup", "place", "sizzle", "ding", "deliver", "happy", "impatient", "win", "lose",
	"buy", "burnt", "coin", "error", "cooked", "tick", "go"]
## Archivo de cada pista de música: la del menú es un bucle sintetizado (WAV) y la de las partidas una pista real
## comprimida en OGG Vorbis (ver docs/licenses.md).
const MUSIC_FILES: Dictionary = {"menu": "res://assets/audio/music_menu.ogg", "game": "res://assets/audio/music_jazz.ogg"}
const POOL_SIZE := 8
const MIN_GAP_MS := 45

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _pool: Array = []
var _next := 0
var _last_ms: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_name := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for n in SFX_NAMES:
		var p := "res://assets/audio/sfx_%s.wav" % n
		if ResourceLoader.exists(p):
			_sfx[n] = load(p)
	for n in MUSIC_FILES:
		var p2 := str(MUSIC_FILES[n])
		if ResourceLoader.exists(p2):
			var s := load(p2) as AudioStream
			if s is AudioStreamWAV:
				_make_loop(s as AudioStreamWAV)
			elif s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			if s != null:
				_music[n] = s
	for i in POOL_SIZE:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	Events.settings_changed.connect(apply_volumes)
	apply_volumes()

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _make_loop(s: AudioStreamWAV) -> void:
	var bytes_per_frame := 4 if s.stereo else 2
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	@warning_ignore("integer_division")
	s.loop_end = s.data.size() / bytes_per_frame

func apply_volumes() -> void:
	_set_bus("Music", SettingsManager.music_volume)
	_set_bus("SFX", SettingsManager.sfx_volume)

func _set_bus(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(idx, volume <= 0.001)

func play_sfx(sfx_name: String, volume_db: float = -3.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _sfx.get(sfx_name, null)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sfx_name, -1000)) < MIN_GAP_MS:
		return
	_last_ms[sfx_name] = now
	var pl := _pool[_next] as AudioStreamPlayer
	_next = (_next + 1) % POOL_SIZE
	pl.stream = stream
	pl.volume_db = volume_db
	pl.pitch_scale = pitch * randf_range(0.96, 1.04)
	pl.play()

## Devuelve una copia en bucle de un efecto (para sonidos continuos como la plancha).
func loop_stream(sfx_name: String) -> AudioStream:
	var s: AudioStream = _sfx.get(sfx_name, null)
	if s is AudioStreamWAV:
		var copy := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		_make_loop(copy)
		return copy
	return s

## true si la pista de música (menu o game) se ha cargado.
func has_music(music_name: String) -> bool:
	return _music.has(music_name)

func play_music(music_name: String) -> void:
	if music_name == _music_name and _music_player.playing:
		return
	var s: AudioStream = _music.get(music_name, null)
	if s == null:
		return
	_music_name = music_name
	_music_player.stream = s
	_music_player.volume_db = -30.0
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", -6.0, 0.9)

func stop_music() -> void:
	_music_name = ""
	_music_player.stop()
