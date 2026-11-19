class_name SettingsScreen
extends MenuScreen
## Pantalla de ajustes del menú principal (comparte el panel con el menú de pausa).

func _init() -> void:
	title_key = "menu.settings"
	icon_name = "settings"

func _build(body: VBoxContainer) -> void:
	body.add_child(UIKit.scroll(UIKit.centered(SettingsPanel.new(_inner_w, true))))
