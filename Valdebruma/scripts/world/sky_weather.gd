class_name SkyWeather
extends Node3D
## SkyWeather — cielo, sol/luna, niebla, lluvia y viento según la hora y el clima del servidor.
##
## Responsabilidad: presentar de forma gradual el estado que llega en S.ENV (Session.env):
## colores del cielo y de la luz por hora, noche legible con luz de luna, niebla más densa con
## mal tiempo y dentro de la bruma, lluvia con partículas alrededor de la cámara y parámetros
## globales de viento y humedad para los sombreadores. No decide el clima: solo lo muestra.
## Ajustes: sombras y efectos según Config (video/shadows, video/effects).

const KEYS := [   # hora, cielo alto, horizonte, luz del sol, energía, ambiente
	[0.0, Color(0.02, 0.035, 0.07), Color(0.05, 0.07, 0.11), Color(0.55, 0.65, 0.9), 0.0, 0.34],
	[5.2, Color(0.03, 0.05, 0.1), Color(0.09, 0.1, 0.15), Color(0.55, 0.65, 0.9), 0.0, 0.36],
	[6.4, Color(0.2, 0.3, 0.5), Color(0.86, 0.56, 0.4), Color(1.0, 0.62, 0.42), 0.55, 0.6],
	[8.0, Color(0.26, 0.42, 0.68), Color(0.72, 0.78, 0.84), Color(1.0, 0.9, 0.78), 1.1, 0.95],
	[13.0, Color(0.25, 0.44, 0.74), Color(0.7, 0.8, 0.88), Color(1.0, 0.96, 0.9), 1.3, 1.05],
	[18.2, Color(0.26, 0.4, 0.64), Color(0.76, 0.74, 0.7), Color(1.0, 0.86, 0.68), 1.05, 0.9],
	[20.0, Color(0.16, 0.2, 0.4), Color(0.9, 0.46, 0.3), Color(1.0, 0.5, 0.3), 0.5, 0.55],
	[21.2, Color(0.03, 0.05, 0.1), Color(0.1, 0.1, 0.16), Color(0.55, 0.65, 0.9), 0.0, 0.36],
	[24.0, Color(0.02, 0.035, 0.07), Color(0.05, 0.07, 0.11), Color(0.55, 0.65, 0.9), 0.0, 0.34],
]

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var rain: GPUParticles3D
var cloud := 0.2
var fog := 0.05
var rain_amount := 0.0
var wind := 0.3
var wind_dir := 0.9
var mist := 0.0                  # bruma local (zona de riesgo) alrededor del jugador
var indoor := 0.0
var _we: WorldEnvironment

func _ready() -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.1
	sky_mat.sun_angle_max = 18.0
	sky_mat.sky_cover = load("res://assets/textures/fx/clouds.png")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.55
	# Nota: fog_aerial_perspective y fog_sun_scatter > 0 dejan en negro los materiales con
	# sombreador propio y recorte alfa en el renderer Mobile (comprobado con el visor), así que
	# se dejan a 0 y el color de la niebla se calcula aquí según la hora.
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.0
	_we = WorldEnvironment.new()
	_we.environment = env
	add_child(_we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.56, 0.68, 0.95)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(moon)
	_make_rain()
	apply_quality()
	Config.applied.connect(apply_quality)
	Config.changed.connect(func(_s: String, _k: String) -> void: apply_quality())
	cloud = float(Session.env.get("cloud", 0.2))
	fog = float(Session.env.get("fog", 0.05))
	rain_amount = float(Session.env.get("rain", 0.0))
	wind = float(Session.env.get("wind", 0.3))

func apply_quality() -> void:
	var sh := int(Config.get_v("video", "shadows"))
	sun.shadow_enabled = sh > 0
	sun.directional_shadow_max_distance = 55.0 if sh == 1 else 95.0
	RenderingServer.directional_shadow_atlas_set_size(1024 if sh <= 1 else 2048, true)
	env.glow_enabled = int(Config.get_v("video", "effects")) >= 2
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	rain.amount = [140, 420, 900][int(Config.get_v("video", "effects"))]

func _make_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 420
	rain.lifetime = 0.75
	rain.emitting = false
	rain.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))
	rain.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11, 0.5, 11)
	pm.direction = Vector3(0.1, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 19.0
	pm.gravity = Vector3(0, -6, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.84, 0.9, 0.3)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	rain.draw_pass_1 = q
	add_child(rain)

func _sample(hour: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			var t := (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t), (a[3] as Color).lerp(b[3], t), lerpf(a[4], b[4], t), lerpf(a[5], b[5], t)]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], 0.0, 0.34]

func update(delta: float, cam_pos: Vector3, in_building: bool) -> void:
	var e: Dictionary = Session.env
	var k := clampf(delta / 6.0, 0.0, 1.0)
	cloud = lerpf(cloud, float(e.get("cloud", 0.2)), k)
	fog = lerpf(fog, float(e.get("fog", 0.05)), k)
	rain_amount = lerpf(rain_amount, float(e.get("rain", 0.0)), k)
	wind = lerpf(wind, float(e.get("wind", 0.3)), k)
	wind_dir = lerp_angle(wind_dir, float(e.get("dir", 0.9)), k)
	mist = lerpf(mist, GameData.world.hazard_at(cam_pos.x, cam_pos.z), clampf(delta * 0.6, 0.0, 1.0))
	indoor = lerpf(indoor, 1.0 if in_building else 0.0, clampf(delta * 2.5, 0.0, 1.0))
	var hour := Session.hour_now()
	var s := _sample(hour)
	var overcast := clampf(cloud * 0.75 + rain_amount * 0.25, 0.0, 1.0)
	var grey := Color(0.5, 0.53, 0.56)
	var top: Color = (s[0] as Color).lerp(grey * (0.25 + float(s[4]) * 0.7), overcast * 0.8)
	var hor: Color = (s[1] as Color).lerp(grey * (0.3 + float(s[4]) * 0.75), overcast * 0.85)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor * 0.9
	sky_mat.ground_bottom_color = hor * 0.45
	sky_mat.sky_cover_modulate = Color(1, 1, 1, clampf(cloud * 1.2, 0.0, 1.0)) * (0.25 + float(s[4]) * 0.8)
	# sol: sale por el este (+X), culmina al sur y se pone por el oeste
	var day_t := (hour - 6.2) / 14.4
	var elev := sin(clampf(day_t, 0.0, 1.0) * PI) * 62.0
	var azim := lerpf(-100.0, 100.0, clampf(day_t, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-maxf(elev, 2.0), 180.0 - azim, 0)
	sun.light_color = s[2]
	sun.light_energy = float(s[3]) * (1.0 - overcast * 0.72)
	sun.visible = sun.light_energy > 0.02
	var night := clampf(1.0 - float(s[3]) * 2.2, 0.0, 1.0)
	moon.rotation_degrees = Vector3(-48.0, -40.0 + hour * 6.0, 0)
	moon.light_energy = (0.3 + 0.25 * Config.f("access", "night_boost")) * night * (1.0 - overcast * 0.45)
	moon.visible = night > 0.02
	env.ambient_light_energy = (float(s[4]) + 0.3 * Config.f("access", "night_boost") * night) * (1.0 - 0.26 * indoor)
	# niebla: clima + bruma local; color según la luz del momento
	var dens := 0.0016 + fog * 0.021 + rain_amount * 0.004 + mist * 0.045
	env.fog_density = dens * (1.0 - 0.5 * indoor)
	var mist_col := Color(0.52, 0.66, 0.62)
	env.fog_light_color = hor.lerp(mist_col * (0.35 + float(s[4]) * 0.6), clampf(mist * 1.2, 0.0, 1.0))
	env.fog_light_energy = 0.9
	# viento y humedad para los sombreadores
	RenderingServer.global_shader_parameter_set(&"vb_wind", Vector4(cos(wind_dir), sin(wind_dir), 0.35 + wind * 1.4, wind))
	RenderingServer.global_shader_parameter_set(&"vb_wetness", clampf(rain_amount * 1.4, 0.0, 1.0))
	rain.emitting = rain_amount > 0.08 and indoor < 0.6
	rain.amount_ratio = clampf(rain_amount, 0.15, 1.0)
	rain.global_position = cam_pos + Vector3(0, 9.0, 0)
