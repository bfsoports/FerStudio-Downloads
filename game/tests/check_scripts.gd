extends SceneTree
## Loads every GDScript in the project and reports parse/compile failures.

func _initialize() -> void:
	var bad := 0
	var files := _collect("res://scripts")
	files.append_array(_collect("res://tests"))
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate():
			print("FAIL ", f)
			bad += 1
	print("CHECKED %d scripts, %d failed" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_collect(dir + "/" + sub))
	return out
