extends SceneTree
## Visor de efectos: instancia escenas de efecto en fila, las dispara y captura tras unos fotogramas.
## Uso: xvfb-run -a godot --path . -s tools/godot/vfx_viewer.gd -- --out=/ruta.png --frames=20 [--night=1]

const FX := [
	"res://assets/BinbunVFX_Vol2/FlameFX/effects/fire/vfx_basic_fire_01.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn",
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_01.tscn",
	"res://assets/BinbunVFX_Vol2/ElectricFX/effects/zap/vfx_zap_lightning_01.tscn",
	"res://assets/BinbunVFX_Vol2/DarkMagicFX/effects/area/vfx_evil_area_01.tscn",
	"res://assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn",
]
var _frames := 0
var _out := "user://vfx.png"
var _at := 20
var _nodes: Array = []

func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return def

func _initialize() -> void:
	_out = _arg("out", _out)
	_at = int(_arg("frames", "20"))
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.08) if _arg("night", "1") == "1" else Color(0.55, 0.65, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.45)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.24, 0.2)
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.4, 11.5), Vector3(0, 1.0, 0))
	cam.current = true
	var x := -float(FX.size() - 1) * 1.4
	for path: String in FX:
		var ps: PackedScene = load(path)
		if ps == null:
			print("no carga: ", path)
			continue
		var n: Node3D = ps.instantiate()
		n.position = Vector3(x, 0.05, 0)
		world.add_child(n)
		_nodes.append(n)
		x += 2.8

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		for n: Node3D in _nodes:
			if n.has_method("play"):
				n.set("one_shot", true)
				n.call("play")
			else:
				n.set("emitting", true)
	if _frames == 3 + _at:
		root.get_texture().get_image().save_png(_out)
		print("captura: ", _out)
		return true
	return false
