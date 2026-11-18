extends RefCounted
## Medios del juego: el logotipo de la pantalla de carga se importa, las pistas de música se cargan y
## la música de las partidas es la pista larga y comprimida. Requiere que el editor haya importado ya los recursos.

func run(t) -> void:
	var logo := load(LoadingScreen.LOGO_PATH) as Texture2D
	t.ok(logo != null, "el logotipo de la pantalla de carga se importa")
	t.ok(AudioManager.has_music("menu"), "la música del menú se carga")
	t.ok(AudioManager.has_music("game"), "la música de las partidas se carga")
	var cafe := load("res://assets/audio/music_jazz.ogg") as AudioStreamOggVorbis
	t.ok(cafe != null, "la pista de las partidas se importa como OGG Vorbis")
	if cafe != null:
		t.ok(cafe.get_length() > 100.0, "la pista de las partidas dura más de 100 s")
