extends SceneTree
## Visor de brazos en primera persona: los cuelga de una cámara como en el juego, reproduce un
## clip en un instante dado (con un objeto opcional en la mano) y guarda la captura.
## Uso: xvfb-run -a godot --path . -s tools/godot/fp_viewer.gd -- --out=/ruta.png --anim=fp_hold --at=0.5 [--item=linterna] [--tint=r,g,b]

var _frames := 0
var _out := "user://fp.png"

func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return def

func _initialize() -> void:
	_out = _arg("out", _out)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 150, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = AssetLib.material("t_grass")
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.06
	cam.position = Vector3(0, 1.62, 0)
	cam.rotation_degrees = Vector3(float(_arg("pitch", "-6")), 0, 0)
	world.add_child(cam)
	cam.current = true
	var arms := AssetLib.model("characters/fp_arms")
	cam.add_child(arms)
	var tint := _arg("tint", "")
	if tint != "":
		var c := tint.split(",")
		for mi: Node in arms.find_children("body", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).set_instance_shader_parameter("tint", Color(float(c[0]), float(c[1]), float(c[2])))
			(mi as MeshInstance3D).set_instance_shader_parameter("tint_on", 1.0)
	var ap: AnimationPlayer = arms.find_child("AnimationPlayer", true, false)
	var clip := _arg("anim", "fp_idle")
	if ap != null and ap.has_animation(clip):
		ap.play(clip)
		ap.seek(float(_arg("at", "0.5")), true)
		ap.pause()
	var item := _arg("item", "")
	if item != "":
		HeldItems.attach(arms.find_child("Skeleton3D", true, false), item)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 7:
		for att: Node in root.find_children("*", "BoneAttachment3D", true, false):
			var cam := root.get_camera_3d()
			var rel := cam.global_transform.affine_inverse() * (att as Node3D).global_transform
			print("item.R en cámara: pos=", rel.origin, " Y=", rel.basis.y.normalized(), " Z=", rel.basis.z.normalized())
	if _frames == 8:
		root.get_texture().get_image().save_png(_out)
		print("captura: ", _out)
		return true
	return false
