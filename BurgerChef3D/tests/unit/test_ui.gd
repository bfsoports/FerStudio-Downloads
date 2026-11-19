extends RefCounted
## Interfaz: los iconos 3D propios se cargan a varios tamaños, el marco de ancho limitado nunca estira el
## contenido y las pantallas del menú, la pausa, los resultados y el HUD se construyen sin errores.
## Requiere que el editor de Godot haya importado ya los recursos del proyecto (abrir el proyecto una vez).

func run(t) -> void:
	for n in UIKit.ICON_NAMES:
		for px in [24.0, 64.0, 120.0]:
			t.ok(UIKit.icon(str(n), px) != null, "el icono %s se carga a %d px" % [str(n), int(px)])
	t.eq(UIKit.icon_path("rocket"), UIKit.icon_path("play"), "el nombre antiguo «rocket» lleva al icono de jugar")
	t.eq(UIKit.icon_path("wheel"), UIKit.icon_path("palette"), "el nombre antiguo «wheel» lleva a la paleta")
	# iconos de ingredientes y hamburguesa apilada
	for id in Catalog.ingredient_order:
		t.ok(UIKit.ingredient_icon(str(id)) != "", "el ingrediente %s tiene icono" % str(id))
	var stack := UIKit.burger_stack(["bun_bottom", "patty", "cheese", "bun_top"], 100.0, 0.4)
	t.eq(stack.get_child_count(), 4, "la hamburguesa apilada dibuja una capa por ingrediente")
	t.ok(stack.custom_minimum_size.y > 100.0, "la hamburguesa despiezada es más alta que ancha")
	stack.free()
	t.eq(UIKit.fill_columns(1237.0, 450.0, 14.0, 3)[0], 2, "las tarjetas de mejoras se reparten en 2 columnas en un móvil 20:9")
	t.eq(UIKit.fill_columns(300.0, 450.0, 14.0, 3)[0], 1, "y en 1 si no caben")
	# rendimiento: en escritorio la escena 3D va a resolución nativa salvo que el regulador haya bajado la calidad
	var prev_step := SettingsManager.perf_step
	SettingsManager.perf_step = 0
	t.eq(SettingsManager.render_scale(), 1.0, "resolución 3D nativa sin ahorro")
	SettingsManager.perf_step = 2
	t.ok(SettingsManager.render_scale() < 1.0, "con el escalón 2 de ahorro baja la resolución 3D")
	SettingsManager.perf_step = prev_step
	var old_pack := "res://assets/icons/" + "pack"   # carpeta del pack antiguo (ya eliminada)
	t.ok(not DirAccess.dir_exists_absolute(old_pack), "no quedan iconos del pack antiguo")
	# el marco limita el ancho del contenido y lo centra
	var tree0 := Engine.get_main_loop() as SceneTree
	var frame := ContentFrame.new()
	frame.max_width = 1280.0
	tree0.root.add_child(frame)
	var child := Control.new()
	frame.add_child(child)
	frame.size = Vector2(2000, 700)
	frame.notification(Container.NOTIFICATION_SORT_CHILDREN)
	t.eq(int(child.size.x), 1280, "el contenido no pasa del ancho máximo en una pantalla muy ancha")
	t.eq(int(child.position.x), 360, "el contenido queda centrado")
	frame.size = Vector2(1000, 700)
	frame.notification(Container.NOTIFICATION_SORT_CHILDREN)
	t.eq(int(child.size.x), 1000, "en una pantalla más estrecha ocupa el ancho completo")
	frame.free()
	# reparto responsive: columnas y anchos según el ancho disponible
	t.eq(UIKit.fit_columns(958.0, 138.0, 12.0, 3, 6), 6, "caben 6 casillas de nivel en una ventana ancha")
	t.eq(UIKit.fit_columns(500.0, 138.0, 12.0, 3, 6), 3, "en una ventana estrecha se reducen a 3 columnas")
	t.eq(UIKit.fit_columns(100.0, 138.0, 12.0, 3, 6), 3, "nunca baja del mínimo de columnas")
	t.eq(UIKit.fit_width(958.0, 2, 14, 470.0), 470.0, "las tarjetas no pasan de su ancho máximo")
	t.eq(UIKit.fit_width(700.0, 2, 14, 470.0), 343.0, "las tarjetas se reparten el ancho si no cabe el máximo")
	# las pantallas se construyen dentro del árbol
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	host.theme = UITheme.get_theme()
	tree.root.add_child(host)
	for cls in [LevelSelectScreen, RestaurantScreen, UpgradesScreen, RecipesScreen, MissionsScreen, CustomizationScreen, SettingsScreen, CreditsScreen]:
		var scr: MenuScreen = cls.new()
		host.add_child(scr)
		t.ok(scr.get_child_count() > 0, "la pantalla %s se construye" % scr.title_key)
		scr.queue_free()
	var pause := PauseMenu.new(true)
	host.add_child(pause)
	t.ok(pause.get_child_count() > 0, "el menú de pausa se construye")
	pause.queue_free()
	var tpause := PauseMenu.new(false, true)
	host.add_child(tpause)
	t.ok(tpause.get_child_count() > 0, "el menú de pausa del tutorial (con «Saltar tutorial») se construye")
	tpause.queue_free()
	var pointer := TutorialPointer.new()
	host.add_child(pointer)
	pointer.point_at_world(Vector3(0, 1, -3))
	t.ok(pointer.target_world.is_finite(), "el indicador del tutorial acepta un objetivo 3D")
	pointer.clear()
	t.ok(not pointer.target_world.is_finite(), "y se puede limpiar")
	pointer.queue_free()
	var res := ResultScreen.new({"mode": Const.MODE_FREE, "won": true})
	host.add_child(res)
	t.ok(res.get_child_count() > 0, "la pantalla de resultados se construye")
	res.queue_free()
	var hud := (load("res://scenes/interface/hud.tscn") as PackedScene).instantiate()
	host.add_child(hud)
	t.ok(hud.get_child_count() > 0, "el HUD se construye")
	hud.queue_free()
	t.ok(SettingsManager.UI_SCALES.size() == 3, "hay tres tamaños de interfaz")
	host.queue_free()
