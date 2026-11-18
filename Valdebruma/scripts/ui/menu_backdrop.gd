extends Node3D
## MenuBackdrop — escena 3D de fondo del menú principal.
##
## Un campamento del valle al anochecer, montado con los mismos modelos del juego: refugio,
## hoguera encendida, el superviviente sentado, árboles y bruma. La cámara deriva despacio.
## No carga el mundo ni usa red: es solo ambientación.

var _cam: Camera3D
var _t := 0.0

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.07, 0.12, 0.17)
	sm.sky_horizon_color = Color(0.72, 0.46, 0.3)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.4, 0.3, 0.24)
	sm.ground_bottom_color = Color(0.05, 0.07, 0.07)
	sm.sun_angle_max = 12.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.45, 0.42)
	env.fog_density = 0.022
	env.fog_aerial_perspective = 0.0      # > 0 ennegrece el follaje con recorte en el renderizador móvil
	env.fog_sun_scatter = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-9.0, 118.0, 0)
	sun.light_color = Color(1.0, 0.62, 0.38)
	sun.light_energy = 1.1
	sun.shadow_enabled = int(Config.get_v("video", "shadows")) > 0
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	ground.mesh = pm
	var gm: Material = AssetLib.material("t_forest")
	if gm is BaseMaterial3D:
		gm = gm.duplicate()
		(gm as BaseMaterial3D).uv1_scale = Vector3(48, 48, 1)
	ground.material_override = gm
	add_child(ground)
	_put("structures/refugio", Vector3(-2.6, 0, -1.4), 28.0)
	_put("structures/hoguera", Vector3(0.2, 0, 0.6), 0.0)
	_put("structures/arcon", Vector3(-4.3, 0, 0.9), 70.0)
	_put("vegetation/fallen_log", Vector3(1.5, 0, -0.9), -24.0)
	_put("vegetation/stump", Vector3(2.4, 0, 1.4), 0.0)
	_put("items/mochila_grande", Vector3(1.2, 0, 1.5), 40.0)
	var fire := WorldFx.campfire()
	fire.position = Vector3(0.2, 0.05, 0.6)
	add_child(fire)
	var who := AssetLib.model("characters/survivor")
	who.position = Vector3(1.25, 0.0, -0.35)
	who.rotation_degrees.y = -118.0
	add_child(who)
	CharacterLook.equipment(who, {"hat": true, "pack": 0, "mask": false})
	CharacterLook.tint(who, Profile.cosmetics, false)
	var ap: AnimationPlayer = who.find_child("AnimationPlayer", true, false)
	CharacterLook.fix_loops(ap, "res://data/models/survivor.json")
	if ap != null and ap.has_animation("sit"):
		ap.play("sit")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261
	var trees := ["tree_oak_a_lod0", "tree_pine_a_lod0", "tree_fir_a_lod0", "tree_birch_a_lod0", "tree_oak_b_lod0", "tree_pine_b_lod0", "tree_fir_b_lod1", "tree_oak_autumn_a_lod1"]
	for i in 34:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(7.5, 46.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist - 6.0)
		if _in_view_line(p, 4.0):
			continue          # despeja la línea de visión de la cámara
		var t := _put("vegetation/" + String(trees[rng.randi() % trees.size()]), p, rng.randf() * 360.0)
		if t != null:
			t.scale = Vector3.ONE * rng.randf_range(0.85, 1.3)
	for i in 46:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(2.6, 18.0)
		var kind: String = ["grass_a", "grass_b", "fern", "bush_a", "grass_flowers", "rock_b", "bush_b", "grass_a"][rng.randi() % 8]
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if _in_view_line(p, 3.2) or Vector2(p.x - 4.6, p.z - 6.4).length() < 6.5:
			continue          # nada alto entre la cámara y el campamento
		_put("vegetation/" + kind, p, rng.randf() * 360.0)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	add_child(_cam)
	_cam.current = true
	_place_cam()

## ¿Está p cerca del tramo entre la cámara y el campamento (o detrás de la cámara, en su campo)?
func _in_view_line(p: Vector3, margin: float) -> bool:
	var a := Vector2(5.2, 7.2)
	var b := Vector2(-2.6, -1.0)
	var q := Vector2(p.x, p.z)
	var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), -0.4, 1.0)
	return q.distance_to(a + (b - a) * t) < margin

func _put(rel: String, pos: Vector3, yaw: float) -> Node3D:
	if not AssetLib.has_model(rel):
		return null
	var n := AssetLib.model(rel)
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	return n

func _place_cam() -> void:
	var sway := 0.0 if Config.b("access", "reduce_motion") else sin(_t * 0.07)
	var eye := Vector3(4.6 + sway * 0.7, 1.55 + 0.08 * sin(_t * 0.11), 6.4)
	_cam.look_at_from_position(eye, Vector3(-1.9, 0.95, -0.4))

func _process(delta: float) -> void:
	_t += delta
	_place_cam()
