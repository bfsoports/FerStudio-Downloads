extends Node
## AudioDirector — mezcla y reproducción de audio (autoload).
##
## Responsabilidad: crear los buses (Music, Ambient, SFX), aplicar volúmenes y silencios de
## Config, reproducir efectos 2D/3D desde un fondo de reproductores, pasos por superficie,
## música de menú y capas de ambiente (bosque, noche, pueblo, marjal, interior, polígono,
## viento, lluvia) que se funden según región, hora, clima e interior.
## Datos: caché de AudioStream de assets/audio/*.ogg. Si falta un archivo, simplemente no suena.
## Señales: ninguna. Todo el audio es original, sintetizado con tools/audio/synth.py.

const BEDS: Array[String] = ["amb_forest_day", "amb_night", "amb_town", "amb_marsh", "amb_interior", "amb_industrial", "amb_wind", "amb_rain"]

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _ui: Array[AudioStreamPlayer] = []
var _ui_i := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _beds: Dictionary = {}
var _bed_target: Dictionary = {}
var _step_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "Ambient", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.max_distance = 45.0
		p.unit_size = 5.0
		add_child(p)
		_pool.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = &"SFX"
		add_child(u)
		_ui.append(u)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	for b in BEDS:
		var pl := AudioStreamPlayer.new()
		pl.bus = &"Ambient"
		pl.volume_db = -60.0
		add_child(pl)
		_beds[b] = pl
		_bed_target[b] = 0.0
	Config.changed.connect(func(section: String, _k: String) -> void:
		if section == "audio":
			apply_volumes())
	apply_volumes()

func apply_volumes() -> void:
	_set_bus("Master", Config.f("audio", "master"), false)
	_set_bus("Music", Config.f("audio", "music"), Config.b("audio", "mute_music"))
	_set_bus("Ambient", Config.f("audio", "ambient"), false)
	_set_bus("SFX", Config.f("audio", "sfx"), Config.b("audio", "mute_sfx"))

func _set_bus(bus: String, linear: float, mute: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, mute or linear <= 0.001)

func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := "res://assets/audio/%s.ogg" % sound
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[sound] = s
	return s

func play_ui(sound: String, volume_db := 0.0) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _ui[_ui_i]
	_ui_i = (_ui_i + 1) % _ui.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()

func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch_var := 0.07) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func footstep(surface: String, pos: Vector3, loud := 0.0) -> void:
	_step_i = (_step_i + 1) % 3
	var sound := "step_%s_%d" % [surface, _step_i + 1]
	if stream(sound) == null:
		sound = "step_%s_1" % surface
	if stream(sound) == null:
		sound = "step_dirt_%d" % (_step_i + 1)
	play_at(sound, pos, -9.0 + loud, 0.12)

func play_music(sound: String) -> void:
	if sound == _music_name:
		return
	_music_name = sound
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -50.0, 0.8)
	tw.tween_callback(func() -> void:
		_music.stop()
		var s := stream(sound) if sound != "" else null
		if s != null:
			_music.stream = s
			_music.volume_db = -30.0
			_music.play()
			create_tween().tween_property(_music, "volume_db", -4.0, 1.5))

## Ambiente objetivo según el contexto del jugador (se llama un par de veces por segundo).
func set_context(region: String, indoors: bool, night: bool, rain: float, wind: float, mist: float) -> void:
	for b in BEDS:
		_bed_target[b] = 0.0
	var out := 0.25 if indoors else 1.0
	match region:
		"robledal", "collado", "pradera", "alto", "eras", "ribera":
			_bed_target["amb_night" if night else "amb_forest_day"] = (0.8 if region == "robledal" else 0.55) * out
		"sotoalto":
			_bed_target["amb_town"] = 0.7 * out
			_bed_target["amb_night" if night else "amb_forest_day"] = 0.25 * out
		"fragua":
			_bed_target["amb_industrial"] = 0.7 * out
		"marjal", "bruma":
			_bed_target["amb_marsh"] = (0.8 + 0.2 * mist) * out
			_bed_target["amb_night"] = 0.3 * out if night else 0.0
	if indoors:
		_bed_target["amb_interior"] = 0.7
	_bed_target["amb_wind"] = clampf(0.15 + wind * 0.8, 0.0, 1.0) * (0.35 if indoors else 1.0)
	_bed_target["amb_rain"] = clampf(rain * 1.2, 0.0, 1.0) * (0.5 if indoors else 1.0)

func stop_ambience() -> void:
	for b in BEDS:
		_bed_target[b] = 0.0

func _process(delta: float) -> void:
	for b in BEDS:
		var pl: AudioStreamPlayer = _beds[b]
		var target: float = _bed_target[b]
		var cur := db_to_linear(pl.volume_db)
		var nxt := move_toward(cur, target, delta * 0.4)
		if nxt > 0.003:
			if not pl.playing:
				var s := stream(b)
				if s != null:
					pl.stream = s
					pl.play()
			pl.volume_db = linear_to_db(nxt)
		elif pl.playing:
			pl.stop()
			pl.volume_db = -60.0
