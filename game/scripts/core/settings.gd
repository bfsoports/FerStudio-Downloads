extends Node
## Persistent player settings (user://settings.cfg) and graphics profiles.

signal changed

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.cfg"

var quality: int = Quality.MEDIUM
var look_sensitivity: float = 1.0
var aim_sensitivity: float = 0.6
var invert_y: bool = false
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var controls_opacity: float = 0.55
var controls_scale: float = 1.0
var show_fps: bool = false
var fps_limit: int = 60
var hold_to_buy: bool = true
var vibration: bool = true

var _first_run := true


func _ready() -> void:
	load_settings()
	if _first_run:
		quality = _detect_quality()
		save_settings()
	apply_all()


func _detect_quality() -> int:
	# Conservative auto-detection: weak GPUs / small RAM start on LOW.
	if OS.get_name() != "Android":
		return Quality.HIGH
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var mem := OS.get_memory_info().get("physical", 0) as int
	if mem > 0 and mem < 3_000_000_000:
		return Quality.LOW
	for weak in ["mali-g52", "mali-g51", "mali-t", "adreno (tm) 5", "adreno (tm) 4", "powervr ge8"]:
		if adapter.contains(weak):
			return Quality.LOW
	for strong in ["adreno (tm) 7", "mali-g7", "mali-g6", "immortalis", "xclipse"]:
		if adapter.contains(strong):
			return Quality.HIGH
	return Quality.MEDIUM


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_first_run = false
	quality = cfg.get_value("graphics", "quality", quality)
	fps_limit = cfg.get_value("graphics", "fps_limit", fps_limit)
	show_fps = cfg.get_value("graphics", "show_fps", show_fps)
	look_sensitivity = cfg.get_value("controls", "look_sensitivity", look_sensitivity)
	aim_sensitivity = cfg.get_value("controls", "aim_sensitivity", aim_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	controls_opacity = cfg.get_value("controls", "opacity", controls_opacity)
	controls_scale = cfg.get_value("controls", "scale", controls_scale)
	hold_to_buy = cfg.get_value("controls", "hold_to_buy", hold_to_buy)
	vibration = cfg.get_value("controls", "vibration", vibration)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("controls", "look_sensitivity", look_sensitivity)
	cfg.set_value("controls", "aim_sensitivity", aim_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "opacity", controls_opacity)
	cfg.set_value("controls", "scale", controls_scale)
	cfg.set_value("controls", "hold_to_buy", hold_to_buy)
	cfg.set_value("controls", "vibration", vibration)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)


func apply_all() -> void:
	Engine.max_fps = fps_limit
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_viewport_quality()
	changed.emit()


func set_and_save(key: String, value: Variant) -> void:
	set(key, value)
	save_settings()
	apply_all()


func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_viewport_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match quality:
		Quality.LOW:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
		Quality.MEDIUM:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
		Quality.HIGH:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X


# ---- profile values queried by gameplay systems ---------------------------------

func max_active_zombies() -> int:
	return [14, 20, 24][quality]


func particle_scale() -> float:
	return [0.45, 0.75, 1.0][quality]


func shadows_enabled() -> bool:
	return quality >= Quality.MEDIUM


func shadow_distance() -> float:
	return [0.0, 22.0, 40.0][quality]


func view_distance() -> float:
	return [45.0, 65.0, 90.0][quality]


func dynamic_lights_budget() -> int:
	return [4, 8, 14][quality]


func zombie_anim_full_rate_distance() -> float:
	return [10.0, 16.0, 24.0][quality]


func quality_name(q: int = -1) -> String:
	if q < 0:
		q = quality
	return ["BAJO", "MEDIO", "ALTO"][q]
