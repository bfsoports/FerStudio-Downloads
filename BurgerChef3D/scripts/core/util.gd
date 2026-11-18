class_name Util
extends RefCounted
## Utilidades estáticas: conversiones seguras de datos JSON, formato de tiempo y lectura de JSON.

static func to_int(v: Variant, d: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v)
			if s.is_valid_int():
				return s.to_int()
			if s.is_valid_float():
				return int(s.to_float())
	return d

static func to_float(v: Variant, d: float = 0.0) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v)
			if s.is_valid_float():
				return s.to_float()
	return d

static func to_str(v: Variant, d: String = "") -> String:
	if v == null:
		return d
	return str(v)

static func to_bool(v: Variant, d: bool = false) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v).to_lower()
			if s == "true" or s == "1":
				return true
			if s == "false" or s == "0":
				return false
	return d

static func clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)

static func fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	var m := int(floor(s / 60.0))
	return "%d:%02d" % [m, s - m * 60]

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)

static func html_color(hex: String, fallback: Color = Color.WHITE) -> Color:
	if hex.is_valid_html_color():
		return Color.html(hex)
	return fallback
