class_name Vfx
extends RefCounted
## Vfx — efectos visuales puntuales del mundo.
##
## Envuelve los efectos CC0 de Binbun3D (assets/BinbunVFX_Vol2, adaptados a móvil) con una
## interfaz mínima: llama permanente de hoguera, destellos de un solo uso que se liberan solos
## (golpe de herramienta, impacto, rayo, nube de esporas) y auras temporales sobre un nodo.
## El nivel de «efectos» de los ajustes gráficos (0–2) recorta luces y efectos secundarios.

const BASE := "res://assets/BinbunVFX_Vol2/"
const SCENES := {
	"fire": BASE + "FlameFX/effects/fire/vfx_basic_fire_01.tscn",
	"hit": BASE + "StylizedHitFX/effects/hit/vfx_hit_01.tscn",
	"spark": BASE + "StylizedHitFX/effects/hit/vfx_hit_02.tscn",
	"impact": BASE + "StylizedHitFX/effects/impact/vfx_impact_01.tscn",
	"zap": BASE + "ElectricFX/effects/zap/vfx_zap_lightning_01.tscn",
	"area": BASE + "DarkMagicFX/effects/area/vfx_evil_area_01.tscn",
	"aura": BASE + "StatusFX/effects/status/vfx_status_shatter.tscn",
}
static var _cache: Dictionary = {}

static func _make(kind: String) -> Node3D:
	if not _cache.has(kind):
		var path := String(SCENES.get(kind, ""))
		_cache[kind] = load(path) if path != "" and ResourceLoader.exists(path) else null
	var ps: PackedScene = _cache[kind]
	return ps.instantiate() as Node3D if ps != null else null

static func quality() -> int:
	return int(Config.get_v("video", "effects"))

static func _no_light(n: Node) -> void:
	for l: Node in n.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).visible = false

## Llama de hoguera con su luz (sin sombras). Permanece mientras exista el nodo.
static func fire(size := 1.0, light_range := 9.0, light_energy := 2.2) -> Node3D:
	var n := _make("fire")
	if n == null:
		return Node3D.new()
	n.scale = Vector3.ONE * size
	n.set("primary_color", Color(1.0, 0.78, 0.32))
	n.set("secondary_color", Color(0.95, 0.3, 0.06))
	n.set("light_color", Color(1.0, 0.62, 0.3))
	n.set("light_energy", light_energy)
	n.set("particles_amount", 12 if quality() == 0 else 24)
	var l: OmniLight3D = n.get_node_or_null("OmniLight3D")
	if l != null:
		l.omni_range = light_range
		l.shadow_enabled = false
		l.position.y = 0.6 / maxf(size, 0.1)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 45.0
		l.distance_fade_length = 15.0
	n.set("emitting", true)
	return n

## Destello de un solo uso en una posición del mundo. kind: hit, spark, impact.
static func burst(kind: String, pos: Vector3, size := 1.0, color: Variant = null) -> void:
	var wr := WorldRoot.current
	if wr == null or (quality() == 0 and kind == "spark"):
		return
	if wr.player != null and wr.player.global_position.distance_to(pos) > 60.0:
		return
	var n := _make(kind)
	if n == null:
		return
	wr.dynamic.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * size
	if color is Color:
		n.set("primary_color", color)
	if quality() < 2:
		_no_light(n)
	n.set("one_shot", true)
	n.call("play")
	wr.get_tree().create_timer(2.2).timeout.connect(n.queue_free)

## Rayo lejano de tormenta (solo visual): columna de luz escalada, sin luz propia.
static func lightning(pos: Vector3, height := 170.0) -> void:
	var wr := WorldRoot.current
	var n := _make("zap")
	if wr == null or n == null:
		return
	wr.dynamic.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * (height / 4.5)
	_no_light(n)
	n.set("emission", 6.0)
	n.set("one_shot", true)
	n.call("play")
	wr.get_tree().create_timer(2.0).timeout.connect(n.queue_free)

## Nube que se abre y se cierra en el suelo (esporas del Farol).
static func cloud(pos: Vector3, radius: float, seconds: float, primary: Color, secondary: Color) -> void:
	var wr := WorldRoot.current
	var n := _make("area")
	if wr == null or n == null:
		return
	wr.dynamic.add_child(n)
	n.global_position = pos
	n.set("primary_color", primary)
	n.set("secondary_color", secondary)
	n.set("light_color", primary)
	n.set("area_radius", radius)
	if quality() < 2:
		_no_light(n)
	n.set("emitting", true)
	var tree := wr.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.set("emitting", false))
	tree.create_timer(seconds + 1.2).timeout.connect(n.queue_free)

## Aura temporal alrededor de un nodo (reaparecer, subir de nivel).
static func aura(parent: Node3D, seconds: float, primary: Color, secondary: Color) -> void:
	if parent == null or not parent.is_inside_tree() or quality() == 0:
		return
	var n := _make("aura")
	if n == null:
		return
	parent.add_child(n)
	n.position = Vector3(0, 0.1, 0)
	n.set("primary_color", primary)
	n.set("secondary_color", secondary)
	n.set("tertiary_color", Color.WHITE)
	n.set("emitting", true)
	var tree := parent.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.set("emitting", false))
	tree.create_timer(seconds + 2.2).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())
