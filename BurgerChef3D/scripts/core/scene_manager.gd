extends Node
## Cambio de escenas con pantalla de carga (LoadingScreen, estilo Brotato con el logotipo de FerStudio) o con un
## fundido breve, paso de parámetros entre escenas y gestión de eventos del sistema (botón Atrás de Android, app en
## segundo plano, cierre de ventana).

const MIN_LOADING_MS := 900   # la pantalla de carga se ve al menos este tiempo, aunque la escena cargue antes

var params: Dictionary = {}
var _overlay: ColorRect
var _loading: LoadingScreen
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Palette.BROWN
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	layer.add_child(_overlay)
	_loading = LoadingScreen.new()
	add_child(_loading)

## Cambia de escena. Con with_loading (por defecto) muestra la pantalla de carga mientras la escena se carga en
## segundo plano y se construye (al menos min_ms; instant = aparece sin fundido, al arrancar); sin ella, hace un
## fundido breve.
func change_scene(path: String, p: Dictionary = {}, with_loading: bool = true, min_ms: int = MIN_LOADING_MS, instant: bool = false) -> void:
	if _busy:
		return
	_busy = true
	params = p
	if with_loading:
		await _change_with_loading(path, min_ms, instant)
		_busy = false
		return
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.16)
	await tw.finished
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: no se pudo cargar %s (error %d)" % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_overlay, "modulate:a", 0.0, 0.2)
	await tw2.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _change_with_loading(path: String, min_ms: int, instant: bool) -> void:
	await _loading.show_screen(instant)
	get_tree().paused = false
	var started := Time.get_ticks_msec()
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	var err := get_tree().change_scene_to_packed(packed) if packed != null else get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: no se pudo cargar %s (error %d)" % [path, err])
	# la escena nueva se construye en su _ready (el restaurante entero), tapada por la pantalla de carga
	for _i in 3:
		await get_tree().process_frame
	while Time.get_ticks_msec() - started < min_ms:
		await get_tree().process_frame
	await _loading.hide_screen()

func quit_game() -> void:
	SaveManager.save_now()
	get_tree().quit()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			Events.back_requested.emit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			SaveManager.save_now()
			Events.app_backgrounded.emit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			SaveManager.save_now()
