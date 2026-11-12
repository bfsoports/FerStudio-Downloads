extends SceneTree
## Visor de arte: coloca modelos en rejilla con la iluminación del juego y guarda una captura.
## Uso: xvfb-run -a godot --path . -s tools/godot/viewer.gd -- --out=/ruta.png --models=a,b --cols=4 \
##      --spacing=6 --cam=0,3,10 --look=0,1,0 [--hour=10] [--ground=t_grass] [--fov=50]

var _frames := 0
var _out := "user://viewer.png"

func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return def

func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _initialize() -> void:
	_out = _arg("out", _out)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.46, 0.66)
	sm.sky_horizon_color = Color(0.72, 0.78, 0.82)
	sm.ground_horizon_color = Color(0.6, 0.64, 0.62)
	sm.ground_bottom_color = Color(0.25, 0.27, 0.24)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.76, 0.8)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	world.add_child(sun)
	var ge := _arg("game_env", "")
	if "sky" in ge:
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		sky.radiance_size = Sky.RADIANCE_SIZE_64
	if "refl" in ge:
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if "fogsky" in ge:
		env.fog_sky_affect = 0.55
	if "aerial" in ge:
		env.fog_aerial_perspective = 0.35
	if "scatter" in ge:
		env.fog_sun_scatter = 0.1
	if "sun" in ge:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.shadow_bias = 0.06
		sun.shadow_normal_bias = 1.6
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
	if "scale" in ge:
		root.scaling_3d_scale = 0.85
	if "glob" in ge:
		RenderingServer.global_shader_parameter_set(&"vb_wind", Vector4(cos(0.9), sin(0.9), 0.35 + 0.3 * 1.4, 0.3))
		RenderingServer.global_shader_parameter_set(&"vb_wetness", 0.0)
	if "moon" in ge:
		var moon := DirectionalLight3D.new()
		moon.light_color = Color(0.56, 0.68, 0.95)
		moon.shadow_enabled = false
		moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
		moon.light_energy = 0.0
		moon.visible = false
		world.add_child(moon)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var gname := _arg("ground", "t_grass")
	gm.albedo_texture = load("res://assets/textures/pbr/%s_albedo.jpg" % gname)
	gm.uv1_scale = Vector3(100, 100, 1)
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)
	var models := _arg("models", "").split(",", false)
	var cols := int(_arg("cols", "4"))
	var spacing := float(_arg("spacing", "6"))
	for i in models.size():
		var inst: Node3D
		if _arg("mm", "") != "":
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = AssetLib.mesh(models[i])
			mm.instance_count = 2
			mm.set_instance_transform(0, Transform3D.IDENTITY)
			mm.set_instance_transform(1, Transform3D(Basis(), Vector3(0, 0, -5)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			inst = mmi
		else:
			inst = AssetLib.model(models[i])
		var cx: float = float(i % cols) - float(mini(cols, models.size()) - 1) * 0.5
		inst.position = Vector3(cx * spacing, 0, -(i / cols) * spacing)
		inst.rotation.y = float(_arg("yaw", "0")) * PI / 180.0
		world.add_child(inst)
		var anims := _arg("anim", "").split(",", false)
		if not anims.is_empty():
			var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
			if ap != null:
				var an: String = anims[i % anims.size()]
				if ap.has_animation(an):
					ap.play(an)
					ap.seek(float(_arg("at", "0.3")) * ap.get_animation(an).length, true)
					ap.pause()
				else:
					print("ANIMACIONES: ", ap.get_animation_list())
	var bname := _arg("building", "")
	if bname != "":
		var b := BuildingFactory.create(bname, false, true)
		world.add_child(b)
		var meta := DataFiles.building(bname)
		for c: Dictionary in meta.get("containers", []):
			b.add_child(BuildingFactory.place_prop(String(c.model), DataFiles.v3(c.pos) + Vector3(0, float(DataFiles.prop(String(c.model)).get("wall", 0.0)), 0), float(c.yaw)))
		for d: Dictionary in meta.get("doors", []):
			var leaf := BuildingFactory.door_leaf(d)
			leaf.rotation_degrees.y += float(_arg("door_open", "70")) * float(d.get("swing", -1))
			b.add_child(leaf)
		if _arg("cut", "") != "":
			# corte: oculta el tejado/techo con un plano de recorte para ver la planta
			pass
	var cam := Camera3D.new()
	cam.fov = float(_arg("fov", "50"))
	world.add_child(cam)
	cam.look_at_from_position(_v3(_arg("cam", "0,3,12")), _v3(_arg("look", "0,1.5,0")))
	cam.current = true
	if not AssetLib.missing_materials.is_empty():
		print("MATERIALES SIN DEFINIR: ", AssetLib.missing_materials.keys())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_texture().get_image().save_png(_out)
		print("captura: ", _out)
		return true
	return false
