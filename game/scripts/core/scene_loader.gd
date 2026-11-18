extends CanvasLayer
## Threaded scene loading with a styled loading screen, progress bar and fades.

signal progress(value: float)

const TIPS := [
	"Repara las barricadas para ganar puntos y frenar a la horda.",
	"Los disparos a la cabeza otorgan más puntos.",
	"La Caja Misteriosa cambia de sitio... a veces.",
	"Mejora tus armas en la Forja para enfrentar rondas altas.",
	"Los Corredores aparecen desde la ronda 3. No te quedes quieto.",
	"El Blindado resiste el plomo: apunta a la cabeza.",
	"El Capataz aparece cada 5 rondas. Prepárate.",
	"Mantén pulsado el botón de compra para confirmar.",
]

var _root: Control
var _bar: ProgressBar
var _label: Label
var _tip: Label
var _fade: ColorRect
var _target := ""
var _loading := false
var _shown_progress := 0.0
var _min_time := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/backgrounds/screen_bg.jpg"):
		bg.texture = load("res://assets/ui/backgrounds/screen_bg.jpg")
	_root.add_child(bg)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo/logo.png") if ResourceLoader.exists("res://assets/ui/logo/logo.png") else null
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.25
	logo.anchor_right = 0.75
	logo.anchor_top = 0.12
	logo.anchor_bottom = 0.45
	_root.add_child(logo)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_left = 0.2
	_bar.anchor_right = 0.8
	_bar.anchor_top = 0.72
	_bar.anchor_bottom = 0.72
	_bar.offset_bottom = 18
	_bar.max_value = 1.0
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.09, 0.08, 0.9)
	sb_bg.border_color = Color(0.35, 0.38, 0.3)
	sb_bg.set_border_width_all(2)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = UIStyle.ACCENT
	_bar.add_theme_stylebox_override("background", sb_bg)
	_bar.add_theme_stylebox_override("fill", sb_fill)
	_root.add_child(_bar)
	_label = UIStyle.make_label("CARGANDO SECTOR...", 26, UIStyle.TEXT)
	_label.anchor_left = 0.2
	_label.anchor_right = 0.8
	_label.anchor_top = 0.64
	_label.anchor_bottom = 0.64
	_root.add_child(_label)
	_tip = UIStyle.make_label("", 20, UIStyle.TEXT_DIM)
	_tip.anchor_left = 0.1
	_tip.anchor_right = 0.9
	_tip.anchor_top = 0.82
	_tip.anchor_bottom = 0.82
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_tip)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func change_scene(path: String, show_loading: bool = true) -> void:
	if _loading:
		return
	_loading = true
	_target = path
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	if show_loading:
		_root.visible = true
		_tip.text = TIPS[randi() % TIPS.size()]
		_shown_progress = 0.0
		_bar.value = 0.0
		_min_time = 0.9
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.2)
	var err := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if err != OK:
		push_error("SceneLoader: cannot load %s" % path)
		_loading = false
		_root.visible = false
		return
	set_process(true)


func _process(delta: float) -> void:
	if not _loading:
		set_process(false)
		return
	_min_time -= delta
	var arr := []
	var status := ResourceLoader.load_threaded_get_status(_target, arr)
	var p: float = arr[0] if arr.size() > 0 else 0.0
	_shown_progress = move_toward(_shown_progress, p, delta * 1.5)
	_bar.value = _shown_progress
	progress.emit(_shown_progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED and _shown_progress >= 0.999 and _min_time <= 0.0:
		var scene: PackedScene = ResourceLoader.load_threaded_get(_target)
		_finish(scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("SceneLoader: failed loading %s" % _target)
		_loading = false
		_root.visible = false


func _finish(scene: PackedScene) -> void:
	_loading = false
	set_process(false)
	_fade.color.a = 1.0
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_root.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.45)


func is_loading() -> bool:
	return _loading
