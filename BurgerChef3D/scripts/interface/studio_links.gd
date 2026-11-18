class_name StudioLinks
extends RefCounted
## Botones con los enlaces de FerStudio (web, privacidad, términos, soporte y correo). Se usan en Créditos y en Ajustes.
## Abren el navegador o la app de correo del dispositivo (OS.shell_open). Solo enlazan a la web del estudio, nunca a
## otra tienda de aplicaciones (requisito de la Amazon Appstore).

## Fila (o rejilla, si no cabe) de botones de enlace de ancho fijo.
static func build(avail_w: float) -> Control:
	var entries: Array = [
		["home", Loc.t("studio.web"), Const.WEBSITE_URL],
		["lock", Loc.t("studio.privacy"), Const.PRIVACY_URL],
		["book", Loc.t("studio.terms"), Const.TERMS_URL],
		["info", Loc.t("studio.support"), Const.SUPPORT_URL],
		["chat", Loc.t("studio.email"), "mailto:%s?subject=%s" % [Const.SUPPORT_EMAIL, (Const.GAME_NAME + " " + Const.GAME_VERSION).uri_encode()]],
	]
	var btn_w := 210.0
	var cols := UIKit.fit_columns(avail_w, btn_w, 8.0, 1, 3)
	var grid := UIKit.grid(cols, 8, 8)
	for e in entries:
		var b := UIKit.icon_text_button(str(e[0]), str(e[1]), "ButtonSecondary", UIKit.H_SMALL - 8.0, btn_w, 28)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(open_url.bind(str(e[2])))
		grid.add_child(b)
	return UIKit.centered(grid)

static func open_url(url: String) -> void:
	AudioManager.play_sfx("click")
	if OS.shell_open(url) != OK:
		Events.toast.emit(Loc.t("studio.open_failed", [url]), "warn")
