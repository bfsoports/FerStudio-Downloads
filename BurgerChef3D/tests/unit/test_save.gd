extends RefCounted
## Guardado y carga: ida y vuelta por JSON, datos corruptos o con tipos inesperados, archivos y ajustes.

func run(t) -> void:
	GameState.reset_to_defaults()
	GameState.coins = 123
	GameState.xp = 20
	GameState.level = 3
	GameState.complete_level(1, 3)
	GameState.upgrades["cook_speed"] = 2
	GameState.owned_items.append("wall_mint")
	GameState.equipped["wall"] = "wall_mint"
	GameState.stats["burgers_made"] = 7
	GameState.missions["m_burgers_10"] = {"claimed": true, "notified": true}
	GameState.tutorial_done = true
	var text := JSON.stringify(GameState.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	GameState.reset_to_defaults()
	GameState.from_dict(parsed)
	t.eq(GameState.coins, 123, "las monedas se restauran")
	t.eq(GameState.level, 3, "el nivel se restaura")
	t.eq(GameState.xp, 20, "la experiencia se restaura")
	t.eq(GameState.stars_for(1), 3, "las estrellas se restauran")
	t.eq(GameState.highest_unlocked, 2, "los niveles desbloqueados se restauran")
	t.eq(int(GameState.upgrades.get("cook_speed", 0)), 2, "las mejoras se restauran")
	t.eq(str(GameState.equipped["wall"]), "wall_mint", "la personalización se restaura")
	t.eq(GameState.stat("burgers_made"), 7, "las estadísticas se restauran")
	t.ok(bool(GameState.missions["m_burgers_10"]["claimed"]), "las misiones se restauran")
	t.ok(GameState.tutorial_done, "el estado del tutorial se restaura")
	# datos con tipos inesperados o fuera de rango
	GameState.from_dict({"coins": "abc", "level": 9999, "upgrades": {"cook_speed": 99}, "level_stars": {"1": 7, "999": 2},
		"equipped": {"wall": "no_existe"}, "stats": {"x": "5"}, "xp": -4})
	t.eq(GameState.coins, 0, "texto inválido en las monedas = 0")
	t.eq(GameState.level, Const.MAX_PLAYER_LEVEL, "nivel limitado al máximo")
	t.eq(int(GameState.upgrades.get("cook_speed", 0)), 3, "mejora limitada a su nivel máximo")
	t.eq(GameState.stars_for(1), 3, "estrellas limitadas a 3")
	t.ok(not GameState.level_stars.has("999"), "se ignoran niveles inexistentes")
	t.eq(str(GameState.equipped["wall"]), "wall_cream", "artículo inexistente = el de por defecto")
	t.eq(GameState.stat("x"), 5, "un número en texto se convierte")
	t.eq(GameState.xp, 0, "experiencia negativa = 0")
	GameState.from_dict({})
	t.ok(GameState.initialized, "un diccionario vacío deja un estado válido")
	t.eq(GameState.coins, 0, "valores por defecto seguros")
	# archivos
	var path := "user://test_roundtrip.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var back: Variant = SaveManager._read_json(path)
	t.ok(back is Dictionary and int(back["coins"]) == 123, "lectura de un archivo válido")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	t.ok(SaveManager._read_json(path) == null, "un archivo corrupto se detecta")
	t.ok(SaveManager._read_json("user://no_existe_xyz.json") == null, "un archivo inexistente devuelve null")
	DirAccess.remove_absolute(path)
	t.ok(SaveManager._is_valid({"version": 1, "coins": 5}), "formato válido")
	t.ok(not SaveManager._is_valid({"version": 99, "coins": 5}), "versión futura rechazada")
	t.ok(not SaveManager._is_valid({}), "diccionario vacío rechazado")
	# ajustes persistentes (se restauran al terminar)
	var s := SettingsManager
	var old_music := s.music_volume
	var old_inv := s.invert_y
	var old_q := s.quality
	s.music_volume = 0.25
	s.invert_y = not old_inv
	s.quality = 0
	s.save_settings()
	s.music_volume = 0.9
	s.invert_y = old_inv
	s.quality = 2
	s.load_settings()
	t.ok(is_equal_approx(s.music_volume, 0.25), "el volumen de música persiste")
	t.eq(s.invert_y, not old_inv, "la inversión del eje persiste")
	t.eq(s.quality, 0, "la calidad gráfica persiste")
	s.music_volume = old_music
	s.invert_y = old_inv
	s.quality = old_q
	s.save_settings()
	GameState.reset_to_defaults()
