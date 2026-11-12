class_name Guard
extends RefCounted
## Guard — saneado de datos recibidos por red. Nada del cliente se usa sin pasar por aquí.

static func i(v: Variant, lo: int, hi: int, def: int) -> int:
	if v is int or v is float:
		var f := float(v)
		if is_finite(f):
			return clampi(int(f), lo, hi)
	return def

static func f(v: Variant, lo: float, hi: float, def: float) -> float:
	if v is int or v is float:
		var x := float(v)
		if is_finite(x):
			return clampf(x, lo, hi)
	return def

static func s(v: Variant, max_len: int) -> String:
	if v is String or v is StringName:
		var t := String(v)
		var out := ""
		for ch in t.left(max_len * 2):
			var code := ch.unicode_at(0)
			if code >= 32 and code != 127:
				out += ch
		return out.left(max_len)
	return ""

static func arr(v: Variant, min_size: int) -> Array:
	if v is Array and (v as Array).size() >= min_size:
		return v
	return []

static func dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

static func v3(a: Variant, b: Variant, c: Variant) -> Variant:
	if (a is int or a is float) and (b is int or b is float) and (c is int or c is float):
		var v := Vector3(float(a), float(b), float(c))
		if v.is_finite() and v.length() < 100000.0:
			return v
	return null
