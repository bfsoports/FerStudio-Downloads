class_name Interactables
extends RefCounted
## Interactables — objetos interactivos concretos del mundo (clases internas).
## Door, Box (contenedor), Pickup, Harvest, Structure, Station, Doc.
## Cada uno refleja el estado que guarda Session y pide acciones al servidor.

static func find_lid(n: Node) -> Node3D:
	if n is Node3D and String(n.name).ends_with("_lid"):
		return n
	for c in n.get_children():
		var r := find_lid(c)
		if r != null:
			return r
	return null


# ------------------------------------------------------------------------------- puerta de edificio
class Door extends Interactable:
	var pivot: Node3D
	var swing := -1.0
	var is_open := false
	var _tw: Tween

	func setup(bi: int, d: Dictionary) -> void:
		kind = Protocol.I.DOOR
		oid = Protocol.door_key(bi, int(d.id))
		priority = 2
		position = DataFiles.v3(d.pos)
		rotation_degrees.y = float(d.yaw)
		swing = float(d.get("swing", -1))
		focus = Vector3(float(d.w) * 0.5, 1.05, 0)
		pivot = Node3D.new()
		add_child(pivot)
		pivot.add_child(AssetLib.model("doors/" + String(d.type)))
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(d.w), float(d.h), 0.07)
		cs.shape = box
		cs.position = Vector3(float(d.w) * 0.5, float(d.h) * 0.5, 0)
		body.add_child(cs)
		pivot.add_child(body)
		set_open(Session.open_doors.has(oid), false)

	func set_open(open: bool, animate := true) -> void:
		if open == is_open and animate:
			return
		is_open = open
		var target := deg_to_rad(96.0 * swing) if open else 0.0
		if _tw != null:
			_tw.kill()
		if animate and is_inside_tree():
			_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tw.tween_property(pivot, "rotation:y", target, 0.55)
			AudioDirector.play_at("door_open" if open else "door_close", global_position)
		else:
			pivot.rotation.y = target

	func prompt() -> String:
		return tr("ACT_CLOSE_DOOR") if is_open else tr("ACT_OPEN_DOOR")


# ------------------------------------------------------------------------------- contenedor (mueble, caja, arcón)
class Box extends Interactable:
	var lid: Node3D
	var lid_def: Dictionary = {}
	var lid_rest := Transform3D.IDENTITY
	var is_open := false
	var title := ""
	var _tw: Tween

	func setup(key: int, model_rel: String, def: Dictionary, shown: String) -> void:
		kind = Protocol.I.CONTAINER
		oid = key
		priority = 1
		title = shown
		var size: Array = def.get("size", [0.6, 0.6, 0.6])
		focus = Vector3(0, float(size[1]) * 0.6, 0)
		var m := AssetLib.model(model_rel)
		add_child(m)
		lid = Interactables.find_lid(m)
		lid_def = (def.get("container", {}) as Dictionary).get("lid", {})
		if lid != null:
			lid_rest = lid.transform
		set_open(Session.open_containers.has(oid), false)

	func set_open(open: bool, animate := true) -> void:
		if lid == null or (open == is_open and animate):
			is_open = open
			return
		is_open = open
		var t := lid_rest
		if open:
			match String(lid_def.get("type", "none")):
				"door": t = lid_rest * Transform3D(Basis(Vector3.UP, deg_to_rad(float(lid_def.get("angle", -100.0)))), Vector3.ZERO)
				"lid": t = lid_rest * Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(float(lid_def.get("angle", 70.0)))), Vector3.ZERO)
				"drawer": t = lid_rest.translated_local(Vector3(0, 0, float(lid_def.get("slide", 0.3))))
		if _tw != null:
			_tw.kill()
		if animate and is_inside_tree():
			_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tw.tween_property(lid, "transform", t, 0.45)
			AudioDirector.play_at("container_open" if open else "container_close", global_position)
		else:
			lid.transform = t

	func prompt() -> String:
		return tr("ACT_SEARCH") % title


# ------------------------------------------------------------------------------- objeto en el suelo
class Pickup extends Interactable:
	var item := ""
	var amount := 1

	func setup(id: int, d: Dictionary) -> void:
		kind = Protocol.I.PICKUP
		oid = id
		priority = 3
		item = String(d.item)
		amount = int(d.n)
		position = d.pos
		rotation.y = float(id % 628) * 0.01
		focus = Vector3(0, 0.08, 0)
		var m := AssetLib.model("items/" + item)
		add_child(m)

	func prompt() -> String:
		var n := GameData.item_name(item)
		return tr("ACT_PICKUP") % (n if amount <= 1 else "%s ×%d" % [n, amount])


# ------------------------------------------------------------------------------- punto de recolección
class Harvest extends Interactable:
	var def: Dictionary = {}
	var full: Node3D
	var empty: Node3D
	var has_yield := true

	func setup(node: Dictionary) -> void:
		kind = Protocol.I.HARVEST
		oid = int(node.id)
		def = GameData.harvest.get(String(node.type), {})
		position = node.pos
		rotation_degrees.y = float(node.yaw)
		reach = Protocol.REACH + float(def.get("radius", 1.0)) * 0.6
		focus = Vector3(0, minf(1.2, 0.3 + float(def.get("radius", 1.0)) * 0.4), 0)
		full = AssetLib.model(String(def.model))
		add_child(full)
		if String(def.get("empty", "")) != "":
			empty = AssetLib.model(String(def.empty))
			add_child(empty)
		set_ready(not Session.depleted.has(oid))

	func set_ready(on: bool) -> void:
		has_yield = on
		if empty != null:
			full.visible = on
			empty.visible = not on
		elif not bool(def.get("keep", false)):
			full.visible = on

	func available() -> bool:
		return has_yield

	func prompt() -> String:
		return GameData.text(def.get("verb", ""))


# ------------------------------------------------------------------------------- estructura construida por jugadores
class Structure extends Interactable:
	var data: Dictionary = {}
	var def: Dictionary = {}
	var model: Node3D
	var body: StaticBody3D
	var fx: Node3D
	var leaf: Node3D
	var shown_stage := -1

	func setup(s: Dictionary) -> void:
		oid = int(s.id)
		priority = 1
		position = s.pos
		rotation_degrees.y = float(s.yaw)
		apply(s)

	func apply(s: Dictionary) -> void:
		data = s
		def = GameData.structures.get(String(s.type), {})
		if int(s.stage) != shown_stage:
			shown_stage = int(s.stage)
			_rebuild()
		_update_fx()
		if leaf != null:
			var target := deg_to_rad(-95.0) if bool(s.open) else 0.0
			if absf(leaf.rotation.y - target) > 0.01:
				create_tween().tween_property(leaf, "rotation:y", target, 0.5)
				AudioDirector.play_at("door_open" if bool(s.open) else "door_close", global_position)

	func _rebuild() -> void:
		for c in get_children():
			c.queue_free()
		leaf = null
		fx = null
		var type := String(data.type)
		var rel := "items/mochila_grande" if type == "bulto" else "structures/%s%s" % [type, "" if shown_stage >= 1 else "_frame"]
		if not AssetLib.has_model(rel):
			rel = "structures/" + type
		model = AssetLib.model(rel)
		add_child(model)
		var info: Dictionary = DataFiles.dict("res://data/models/structures.json").get(rel.get_file(), {})
		var size: Array = info.get("size", [1, 1, 1])
		focus = Vector3(0, clampf(float(size[1]) * 0.5, 0.25, 1.3), 0)
		reach = Protocol.REACH + float(def.get("radius", 0.8)) * 0.6
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		if info.has("colliders"):
			for c: Array in info.colliders:
				_box(Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5]))
		elif info.has("collider"):
			var cs: Array = info.collider
			var off: Array = info.get("collider_off", [0, 0, 0])
			_box(Vector3(off[0], float(cs[1]) * 0.5 + float(off[1]), off[2]), Vector3(cs[0], cs[1], cs[2]))
		elif bool(info.get("solid", false)) and shown_stage >= 1:
			_box(DataFiles.v3(info.get("center", [0, 0.5, 0])), DataFiles.v3(size))
		if type == "puerta" and shown_stage >= 1:
			leaf = Node3D.new()
			leaf.position = Vector3(-0.48, 0.02, 0)
			var lm := AssetLib.model("structures/puerta_hoja")
			leaf.add_child(lm)
			var lb := StaticBody3D.new()
			lb.collision_layer = 1
			lb.collision_mask = 0
			var cs2 := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(0.96, 2.0, 0.06)
			cs2.shape = bx
			cs2.position = Vector3(0.48, 1.0, 0)
			lb.add_child(cs2)
			leaf.add_child(lb)
			add_child(leaf)
			leaf.rotation.y = deg_to_rad(-95.0) if bool(data.open) else 0.0

	func _box(center: Vector3, size: Vector3) -> void:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = center
		body.add_child(cs)

	func _update_fx() -> void:
		var want_fire := String(data.type) == "hoguera" and bool(data.lit)
		var want_lamp := String(data.type) == "poste_farol" and shown_stage >= 1
		if (want_fire or want_lamp) and fx == null:
			fx = WorldFx.campfire() if want_fire else WorldFx.lamp(Vector3(0.36, 1.9, 0), Color(1.0, 0.82, 0.55), 7.0)
			add_child(fx)
		elif not (want_fire or want_lamp) and fx != null:
			fx.queue_free()
			fx = null

	func is_mine() -> bool:
		return Session.is_mine(data)

	func prompt() -> String:
		var type := String(data.type)
		if shown_stage < 1:
			var parts: PackedStringArray = []
			for id: String in (def.get("cost", {}) as Dictionary).keys():
				parts.append("%s %d/%d" % [GameData.item_name(id), Session.inv.count(id), int(def.cost[id])])
			return tr("ACT_BUILD") % [GameData.text(def.get("name", type)), ", ".join(parts)]
		if type == "bulto":
			return tr("ACT_SEARCH") % tr("NAME_BUNDLE")
		if def.has("container"):
			return tr("ACT_SEARCH") % GameData.text(def.name)
		if bool(def.get("rest", false)):
			return tr("ACT_REST")
		if def.has("fuel"):
			return tr("ACT_FUEL") if bool(data.lit) else tr("ACT_LIGHT_FIRE")
		if bool(def.get("door", false)):
			return tr("ACT_CLOSE_DOOR") if bool(data.open) else tr("ACT_OPEN_DOOR")
		if def.has("collector"):
			return tr("ACT_FILL_N") % int(data.water) if int(data.water) > 0 else tr("ACT_COLLECTOR_EMPTY")
		if String(def.get("station", "")) == "workbench":
			return tr("ACT_WORKBENCH")
		return ""

	func prompt2() -> String:
		if String(data.type) == "bulto":
			return ""
		if is_mine():
			return tr("ACT_DISMANTLE")
		return ""

	func interact() -> void:
		var type := String(data.type)
		if shown_stage < 1:
			Net.send(Protocol.C.BUILD_ADVANCE, oid)
		elif type == "bulto" or def.has("container"):
			Session.request_interact(Protocol.I.CONTAINER, ServerWorld.STRUCT_CONTAINER + oid)
		elif bool(def.get("rest", false)):
			Session.request_interact(Protocol.I.REST, oid)
		elif def.has("fuel"):
			Session.request_interact(Protocol.I.STRUCT_USE, oid, "fuel")
		elif bool(def.get("door", false)):
			Session.request_interact(Protocol.I.STRUCT_USE, oid, "toggle")
		elif def.has("collector"):
			Session.request_interact(Protocol.I.WATER_FILL, 0)
		elif String(def.get("station", "")) == "workbench":
			WorldRoot.request_ui("craft")

	func interact2() -> void:
		if is_mine():
			Net.send(Protocol.C.BUILD_DISMANTLE, oid)


# ------------------------------------------------------------------------------- estación del mundo (agua, tablón, banco)
class Station extends Interactable:
	var station := ""

	func setup(kind_name: String, focus_h: float) -> void:
		station = kind_name
		focus = Vector3(0, focus_h, 0)
		reach = Protocol.REACH + 0.8

	func prompt() -> String:
		match station:
			"water": return tr("ACT_DRINK")
			"contracts": return tr("ACT_BOARD")
			"workbench": return tr("ACT_WORKBENCH")
		return ""

	func prompt2() -> String:
		match station:
			"water": return tr("ACT_FILL")
			"contracts": return tr("ACT_READ_NOTICE")
		return ""

	func interact() -> void:
		match station:
			"water": Session.request_interact(Protocol.I.WATER_DRINK, 0)
			"contracts": Session.request_interact(Protocol.I.CONTRACT_BOARD, 0)
			"workbench": WorldRoot.request_ui("craft")

	func interact2() -> void:
		match station:
			"water": Session.request_interact(Protocol.I.WATER_FILL, 0)
			"contracts": Session.request_interact(Protocol.I.DOC, -1)


# ------------------------------------------------------------------------------- documento legible
class Doc extends Interactable:
	var doc_id := ""

	func setup(bi: int, id: String) -> void:
		kind = Protocol.I.DOC
		oid = bi
		doc_id = id
		priority = 2
		focus = Vector3(0, 0.05, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.21, 0.006, 0.3)
		mi.mesh = bm
		mi.material_override = AssetLib.material("cloth_white")
		mi.position.y = 0.004
		add_child(mi)
		var m2 := MeshInstance3D.new()
		m2.mesh = bm
		m2.material_override = AssetLib.material("cloth_white")
		m2.position = Vector3(0.03, 0.011, 0.02)
		m2.rotation.y = 0.3
		add_child(m2)

	func prompt() -> String:
		return tr("ACT_READ") % GameData.text((GameData.documents.get(doc_id, {}) as Dictionary).get("title", ""))
