class_name DataFiles
extends RefCounted
## Lectura con caché de los JSON de datos del proyecto (res://data/...).
##
## Responsabilidad: un único punto de carga/validación sintáctica de datos estáticos.
## Lo usan cliente y servidor (el servidor no necesita mallas, solo estos datos).

static var _cache: Dictionary = {}

static func json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var value: Variant = null
	if FileAccess.file_exists(path):
		var parser := JSON.new()
		var err := parser.parse(FileAccess.get_file_as_string(path))
		if err == OK:
			value = parser.data
		else:
			push_error("JSON inválido en %s línea %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
	else:
		push_error("Archivo de datos inexistente: " + path)
	_cache[path] = value
	return value

static func dict(path: String) -> Dictionary:
	var v: Variant = json(path)
	return v if v is Dictionary else {}

static func building(kind_name: String) -> Dictionary:
	return dict("res://data/buildings/%s.json" % kind_name)

static func props() -> Dictionary:
	return dict("res://data/models/props.json")

static func prop(model_name: String) -> Dictionary:
	return props().get(model_name, {})

static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
