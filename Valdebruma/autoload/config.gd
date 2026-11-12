extends Node
## Config — ajustes locales del juego (autoload).
##
## Datos: secciones control / audio / video / juego / accesibilidad con valores por defecto,
## rangos válidos y perfiles gráficos (bajo, medio, alto) que modifican opciones reales.
## Persistencia: user://settings.cfg (ConfigFile). Si falta o está dañado se usan los valores
## por defecto y el archivo dañado se aparta; nunca bloquea el arranque.
## Señales: changed(section, key) y applied(). Lo consultan jugador, mundo, audio e interfaz.

signal changed(section: String, key: String)
signal applied()

const PATH := "user://settings.cfg"
# sección -> clave -> [valor por defecto, mínimo, máximo]  (bool/String sin rango)
const SPEC := {
	"control": {"sens_h": [1.0, 0.2, 3.0], "sens_v": [0.85, 0.2, 3.0], "invert_y": [false], "touch_scale": [1.0, 0.7, 1.5], "touch_opacity": [0.75, 0.25, 1.0],
		"left_handed": [false], "auto_sprint": [false], "head_bob": [true]},
	"audio": {"master": [0.9, 0.0, 1.0], "music": [0.6, 0.0, 1.0], "ambient": [0.8, 0.0, 1.0], "sfx": [0.9, 0.0, 1.0], "mute_music": [false], "mute_sfx": [false]},
	"video": {"quality": [1, 0, 2], "render_scale": [0.85, 0.5, 1.0], "view_distance": [4, 2, 6], "shadows": [1, 0, 2], "grass": [0.5, 0.0, 1.0],
		"effects": [1, 0, 2], "fps_limit": [60, 30, 120], "normal_maps": [true]},
	"game": {"language": ["es"], "show_names": [true], "show_team": [true], "chat": [true], "hints": [true]},
	"access": {"text_scale": [1.0, 0.85, 1.4], "high_contrast": [false], "reduce_motion": [false], "night_boost": [0.0, 0.0, 1.0], "hold_to_interact": [false]},
}
const PROFILES := [
	{"render_scale": 0.7, "view_distance": 3, "shadows": 0, "grass": 0.0, "effects": 0, "fps_limit": 30, "normal_maps": false},
	{"render_scale": 0.85, "view_distance": 4, "shadows": 1, "grass": 0.5, "effects": 1, "fps_limit": 60, "normal_maps": true},
	{"render_scale": 1.0, "view_distance": 5, "shadows": 2, "grass": 1.0, "effects": 2, "fps_limit": 60, "normal_maps": true},
]

var values: Dictionary = {}

func _ready() -> void:
	reset_defaults(false)
	_load()
	apply_all()

func reset_defaults(save_now := true) -> void:
	for section: String in SPEC.keys():
		values[section] = {}
		for key: String in (SPEC[section] as Dictionary).keys():
			values[section][key] = SPEC[section][key][0]
	if OS.has_feature("mobile"):
		set_profile(1, false)
	if save_now:
		save()
		apply_all()

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		DirAccess.copy_absolute(PATH, PATH + ".corrupt")
		push_warning("settings.cfg dañado: se usan los valores por defecto")
		return
	for section: String in SPEC.keys():
		for key: String in (SPEC[section] as Dictionary).keys():
			if cf.has_section_key(section, key):
				values[section][key] = _valid(section, key, cf.get_value(section, key))

func _valid(section: String, key: String, v: Variant) -> Variant:
	var spec: Array = SPEC[section][key]
	var def: Variant = spec[0]
	if def is bool:
		return bool(v) if (v is bool or v is int) else def
	if def is String:
		return String(v) if v is String and (v as String).length() <= 8 else def
	if not (v is int or v is float) or not is_finite(float(v)):
		return def
	if def is int:
		return clampi(int(v), int(spec[1]), int(spec[2]))
	return clampf(float(v), float(spec[1]), float(spec[2]))

func save() -> void:
	var cf := ConfigFile.new()
	for section: String in values.keys():
		for key: String in (values[section] as Dictionary).keys():
			cf.set_value(section, key, values[section][key])
	if cf.save(PATH + ".tmp") == OK:
		DirAccess.rename_absolute(PATH + ".tmp", PATH)

func get_v(section: String, key: String) -> Variant:
	return values[section][key]

func f(section: String, key: String) -> float:
	return float(values[section][key])

func b(section: String, key: String) -> bool:
	return bool(values[section][key])

func set_v(section: String, key: String, v: Variant, save_now := true) -> void:
	var nv: Variant = _valid(section, key, v)
	if typeof(nv) == typeof(values[section][key]) and nv == values[section][key]:
		return
	values[section][key] = nv
	changed.emit(section, key)
	if save_now:
		save()
	_apply(section, key)

func set_profile(index: int, save_now := true) -> void:
	index = clampi(index, 0, 2)
	values["video"]["quality"] = index
	for key: String in (PROFILES[index] as Dictionary).keys():
		values["video"][key] = PROFILES[index][key]
	if save_now:
		save()
		apply_all()

func apply_all() -> void:
	for section: String in values.keys():
		for key: String in (values[section] as Dictionary).keys():
			_apply(section, key)
	applied.emit()

func _apply(section: String, key: String) -> void:
	match section + "/" + key:
		"video/fps_limit":
			Engine.max_fps = int(values.video.fps_limit)
		"video/render_scale":
			if get_tree() != null and get_tree().root != null:
				get_tree().root.scaling_3d_scale = float(values.video.render_scale)
		"video/normal_maps":
			for m: Variant in AssetLib.all_loaded_materials():
				if m is BaseMaterial3D and (m as BaseMaterial3D).normal_texture != null:
					(m as BaseMaterial3D).normal_enabled = bool(values.video.normal_maps)
		"game/language":
			TranslationServer.set_locale(String(values.game.language))
			GameData.lang = String(values.game.language)
		"access/text_scale":
			if get_tree() != null and get_tree().root != null:
				get_tree().root.content_scale_factor = float(values.access.text_scale)
