class_name DirtyTray
extends Carryable
## Bandeja sucia que deja un pedido entregado cuando el turno tiene las bandejas sucias activadas (nivel 6 en adelante).
## Usa el mismo modelo de la bandeja de servicio, oscurecido y con restos de comida. Hay que llevarla al fregadero
## (SinkStation): al terminar de lavarse vuelve sola, limpia, a su puesto (home). No se puede tirar a la basura.

const SIZE := Vector3(0.9, 0.06, 0.5)
const DIRTY_TINT := Color(0.62, 0.5, 0.4)
const HAND_SCALE := 0.42      # en la mano se ve más pequeña que la comida para no tapar la vista

var home: ServicePoint = null

func setup(point: ServicePoint) -> DirtyTray:
	home = point
	add_box_collider(Vector3(SIZE.x, 0.1, SIZE.z), Vector3(0, 0.05, 0))
	var ts := ModelLib.size_of("tray")
	var visual := Node3D.new()
	add_child(visual)
	if ts.x > 0.0 and ModelLib.has("tray"):
		var m := ModelLib.spawn("tray", Vector3(SIZE.x / ts.x, SIZE.y / ts.y, SIZE.z / ts.z))
		ModelLib.tint(m, DIRTY_TINT)
		visual.add_child(m)
	else:
		Prims.box(visual, SIZE, Vector3(0, SIZE.y * 0.5, 0), Prims.mat(DIRTY_TINT))
	# restos: migas de pan, una mancha de kétchup y una de mostaza
	var crumb := Prims.mat(Color.html("#c98f4e"), 0.9)
	for p in [Vector3(-0.22, 0.0, 0.08), Vector3(0.05, 0.0, -0.1), Vector3(0.25, 0.0, 0.12), Vector3(-0.05, 0.0, 0.15)]:
		Prims.sphere(visual, 0.025, Vector3(p.x, SIZE.y + 0.01, p.z), crumb, 0.6, false, 6)
	Prims.cyl(visual, 0.09, 0.09, 0.006, Vector3(0.18, SIZE.y + 0.004, -0.05), Prims.mat(Palette.KETCHUP, 0.4), 12)
	Prims.cyl(visual, 0.06, 0.06, 0.006, Vector3(-0.2, SIZE.y + 0.004, -0.08), Prims.mat(Palette.MUSTARD, 0.4), 10)
	return self

func carry_scale() -> float:
	return HAND_SCALE

func display_name() -> String:
	return Loc.t("item.dirty_tray")

func get_prompt(player: Node) -> Dictionary:
	var p := player as PlayerController
	if p == null:
		return {}
	if p.held == null:
		return {"icon": "grab", "text": "prompt.take", "args": [display_name()]}
	if station != null:
		return station.get_prompt(player)
	return {}

func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null:
		return
	if p.held != null:
		if station != null:
			station.interact(player)
		return
	if station != null:
		station.release(self)
	p.hold(self)
	AudioManager.play_sfx("pickup", -3.0, 0.8)
	Events.item_picked.emit("dirty_tray")
