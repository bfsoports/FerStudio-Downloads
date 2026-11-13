extends SceneTree
## Genera assets/materials/<nombre>.tres a partir de data/materials.json.
## Uso: godot --headless --path . -s tools/godot/build_materials.gd

const TEX := "res://assets/textures/"

func _initialize() -> void:
	var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json"))
	DirAccess.make_dir_recursive_absolute("res://assets/materials")
	var count := 0
	for mat_name: String in defs.keys():
		if mat_name.begins_with("_"):
			continue
		var d: Dictionary = defs[mat_name]
		var mat: Material = _build(d)
		if mat == null:
			push_error("Material no construido: " + mat_name)
			continue
		mat.resource_name = mat_name
		var err := ResourceSaver.save(mat, "res://assets/materials/%s.tres" % mat_name)
		if err != OK:
			push_error("No se pudo guardar %s (%d)" % [mat_name, err])
		count += 1
	print("materiales generados: ", count)
	quit()

func _uv(d: Dictionary) -> Vector3:
	if d.has("uv"):
		return Vector3(d.uv[0], d.uv[1], 1.0)
	var tile: float = d.get("tile", 1.0)
	return Vector3(1.0 / tile, 1.0 / tile, 1.0)

func _col(a: Array, alpha := 1.0) -> Color:
	return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else alpha)

func _build(d: Dictionary) -> Material:
	match String(d.type):
		"pbr":
			var m := ORMMaterial3D.new()
			var base: String = TEX + "pbr/" + String(d.set)
			var nbase: String = TEX + "pbr/" + String(d.get("normal_set", d.set))
			m.albedo_texture = load(base + "_albedo.jpg")
			m.orm_texture = load(TEX + "pbr/" + String(d.get("orm_set", d.set)) + "_orm.jpg")
			if ResourceLoader.exists(nbase + "_normal.png"):
				m.normal_enabled = true
				m.normal_texture = load(nbase + "_normal.png")
				m.normal_scale = d.get("normal", 1.0)
			if d.has("emission_set"):
				m.emission_enabled = true
				m.emission_texture = load(TEX + "pbr/" + String(d.emission_set) + "_emission.jpg")
				m.emission_energy_multiplier = d.get("emission_energy", 1.0)
			m.uv1_scale = _uv(d)
			m.vertex_color_use_as_albedo = true
			m.albedo_color = _col(d.get("tint", [1, 1, 1]))
			m.metallic_specular = d.get("specular", 0.35)
			if d.has("cull_off"):
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"albedo":
			var m := StandardMaterial3D.new()
			m.albedo_texture = load(TEX + String(d.tex))
			m.uv1_scale = _uv(d)
			m.roughness = d.get("rough", 0.8)
			m.metallic = d.get("metal", 0.0)
			m.vertex_color_use_as_albedo = true
			m.albedo_color = _col(d.get("tint", [1, 1, 1]))
			if d.has("alpha_cut"):
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = d.alpha_cut
			if d.has("cull_off"):
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if d.has("emission"):
				m.emission_enabled = true
				m.emission_texture = m.albedo_texture
				m.emission_energy_multiplier = d.emission
			return m
		"flat":
			var m := StandardMaterial3D.new()
			m.albedo_color = _col(d.color)
			m.roughness = d.get("rough", 0.7)
			m.metallic = d.get("metal", 0.0)
			m.vertex_color_use_as_albedo = true
			if d.has("emission"):
				m.emission_enabled = true
				m.emission = _col(d.emission)
				m.emission_energy_multiplier = d.get("emission_energy", 1.0)
			if d.has("cull_off"):
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"glass":
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = _col(d.get("color", [0.55, 0.68, 0.7, 0.32]))
			m.roughness = d.get("rough", 0.08)
			m.metallic = 0.2
			m.metallic_specular = 0.8
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"foliage":
			var m := ShaderMaterial.new()
			m.shader = load("res://assets/shaders/foliage.gdshader")
			m.set_shader_parameter("albedo_tex", load(TEX + "foliage/" + String(d.tex) + ".png"))
			m.set_shader_parameter("wind_scale", d.get("wind", 1.0))
			m.set_shader_parameter("alpha_cut", d.get("cut", 0.42))
			if d.has("tint"):
				m.set_shader_parameter("tint", _col(d.tint))
			return m
		"shader":
			var m := ShaderMaterial.new()
			m.shader = load("res://assets/shaders/" + String(d.shader) + ".gdshader")
			var params: Dictionary = d.get("params", {})
			for k: String in params.keys():
				var v: Variant = params[k]
				if v is String and (v as String).begins_with("tex:"):
					v = load(TEX + (v as String).substr(4))
				elif v is Array and (v as Array).size() == 3:
					v = Color(v[0], v[1], v[2])
				elif v is Array and (v as Array).size() == 4:
					v = Color(v[0], v[1], v[2], v[3])
				m.set_shader_parameter(k, v)
			return m
	return null
