extends Control
## Escena de arranque: aplica los ajustes y entra en el menú principal a través de la pantalla de carga con el
## logotipo de FerStudio (LoadingScreen, estilo Brotato), que se queda visible mientras el menú se carga en segundo
## plano. No hay vídeo de presentación.

const MIN_BOOT_MS := 1800   # el logotipo se ve al menos este tiempo al abrir el juego

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SettingsManager.apply_graphics()
	var bg := ColorRect.new()
	bg.color = LoadingScreen.BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if not Catalog.load_errors.is_empty():
		var err := UIKit.label("Datos: %s" % "; ".join(Catalog.load_errors.slice(0, 3)), "LabelLight", 16)
		err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		err.custom_minimum_size = Vector2(700, 0)
		add_child(err)
		err.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ResourceLoader.load_threaded_request(Const.SCENE_MENU)
	SceneManager.change_scene(Const.SCENE_MENU, {}, true, MIN_BOOT_MS, true)
