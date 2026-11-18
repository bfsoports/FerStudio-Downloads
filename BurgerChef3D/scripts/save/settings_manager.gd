extends Node
## Ajustes del jugador. Se guardan en user://settings.cfg (ConfigFile) y se validan al cargar.
## Cambia las propiedades y llama a commit() para guardar, aplicar y avisar al resto de sistemas.

const PATH := "user://settings.cfg"
const SECTION := "settings"

var music_volume: float = 0.7
var sfx_volume: float = 0.9
var sensitivity: float = 1.0        # multiplicador de la sensibilidad de cámara
var invert_y: bool = false
var control_scale: float = 1.0      # tamaño de los controles táctiles
var quality: int = 2                # 0 baja, 1 media, 2 alta
var shadows: bool = true
var language: String = "es"
var show_fps: bool = false
var force_touch_ui: bool = false    # mostrar controles táctiles en escritorio (pruebas)
var ui_scale: int = 1               # tamaño de la interfaz: 0 pequeña, 1 normal, 2 grande
var vibration: bool = true          # vibración del móvil en las acciones (ver Haptics)

## Factor de escala de contenido de cada tamaño de interfaz (mayor = interfaz más grande).
const UI_SCALES: Array = [0.9, 1.0, 1.15]
var _applied_ui_scale := -1

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music_volume = clampf(Util.to_float(cfg.get_value(SECTION, "music_volume", music_volume), 0.7), 0.0, 1.0)
		sfx_volume = clampf(Util.to_float(cfg.get_value(SECTION, "sfx_volume", sfx_volume), 0.9), 0.0, 1.0)
		sensitivity = clampf(Util.to_float(cfg.get_value(SECTION, "sensitivity", sensitivity), 1.0), 0.3, 2.5)
		invert_y = Util.to_bool(cfg.get_value(SECTION, "invert_y", invert_y))
		control_scale = clampf(Util.to_float(cfg.get_value(SECTION, "control_scale", control_scale), 1.0), 0.7, 1.5)
		quality = clampi(Util.to_int(cfg.get_value(SECTION, "quality", quality), 2), 0, 2)
		shadows = Util.to_bool(cfg.get_value(SECTION, "shadows", shadows), true)
		language = Util.to_str(cfg.get_value(SECTION, "language", language), "es")
		show_fps = Util.to_bool(cfg.get_value(SECTION, "show_fps", show_fps))
		force_touch_ui = Util.to_bool(cfg.get_value(SECTION, "force_touch_ui", force_touch_ui))
		ui_scale = clampi(Util.to_int(cfg.get_value(SECTION, "ui_scale", ui_scale), 1), 0, UI_SCALES.size() - 1)
		vibration = Util.to_bool(cfg.get_value(SECTION, "vibration", vibration), true)
	if not Loc.LANGS.has(language):
		language = "es"
	Loc.set_language(language)

func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "sensitivity", sensitivity)
	cfg.set_value(SECTION, "invert_y", invert_y)
	cfg.set_value(SECTION, "control_scale", control_scale)
	cfg.set_value(SECTION, "quality", quality)
	cfg.set_value(SECTION, "shadows", shadows)
	cfg.set_value(SECTION, "language", language)
	cfg.set_value(SECTION, "show_fps", show_fps)
	cfg.set_value(SECTION, "force_touch_ui", force_touch_ui)
	cfg.set_value(SECTION, "ui_scale", ui_scale)
	cfg.set_value(SECTION, "vibration", vibration)
	return cfg.save(PATH) == OK

## Guarda, aplica y notifica. Llamar tras modificar cualquier propiedad.
func commit() -> void:
	save_settings()
	if Loc.current != language:
		Loc.set_language(language)
	apply_graphics()
	Events.settings_changed.emit()

func is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func use_touch_ui() -> bool:
	return is_touch_device() or force_touch_ui

## Aplica la calidad gráfica a la escena actual (luces con sombras y luces extra) y al viewport.
func apply_graphics() -> void:
	var tree := get_tree()
	if tree == null:
		return
	apply_ui_scale()
	get_viewport().msaa_3d = Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
	var shadow_on := shadows and quality >= 1
	for n in tree.get_nodes_in_group(Const.GROUP_SHADOW_LIGHTS):
		var l := n as Light3D
		if l != null:
			l.shadow_enabled = shadow_on
	for n in tree.get_nodes_in_group(Const.GROUP_EXTRA_LIGHTS):
		var n3 := n as Node3D
		if n3 != null:
			n3.visible = quality >= 1

## Aplica el tamaño de la interfaz a la ventana y avisa a las pantallas abiertas para que se recoloquen.
func apply_ui_scale() -> void:
	if get_window() == null:
		return
	get_window().content_scale_factor = float(UI_SCALES[clampi(ui_scale, 0, UI_SCALES.size() - 1)])
	if _applied_ui_scale != ui_scale:
		var first := _applied_ui_scale < 0
		_applied_ui_scale = ui_scale
		if not first:
			Events.ui_scale_changed.emit()
