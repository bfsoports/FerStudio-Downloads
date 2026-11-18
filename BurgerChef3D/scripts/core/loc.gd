extends Node
## Localización: carga resources/i18n/strings.json y registra una Translation por idioma (es / en).
## Uso: Loc.t("clave", [args]) para textos de interfaz y Loc.pick(dict) para nombres de contenido ({"es":..,"en":..}).

const STRINGS_PATH := "res://resources/i18n/strings.json"
const LANGS: Array = ["es", "en"]

var current: String = "es"

func _ready() -> void:
	var data: Variant = Util.load_json(STRINGS_PATH)
	if not (data is Dictionary):
		push_error("Loc: no se pudo cargar %s" % STRINGS_PATH)
		return
	for lang in LANGS:
		var tl := Translation.new()
		tl.locale = lang
		for key in data:
			var entry: Variant = data[key]
			if entry is Dictionary and entry.has(lang):
				tl.add_message(key, str(entry[lang]))
		TranslationServer.add_translation(tl)
	set_language(current)

func set_language(lang: String) -> void:
	if not LANGS.has(lang):
		lang = "es"
	current = lang
	TranslationServer.set_locale(lang)
	Events.language_changed.emit(lang)

func t(key: String, args: Array = []) -> String:
	var s := String(TranslationServer.translate(key))
	if args.is_empty():
		return s
	return s % args

func pick(value: Variant) -> String:
	if value is Dictionary:
		if value.has(current):
			return str(value[current])
		if value.has("es"):
			return str(value["es"])
		return ""
	return "" if value == null else str(value)
