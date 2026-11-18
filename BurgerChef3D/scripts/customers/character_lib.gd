class_name CharacterLib
extends RefCounted
## Cuerpos reales de los clientes (KayKit, CC0): el maniquí de KayKit Character Animations y tres esqueletos de
## KayKit Skeletons, todos sobre el esqueleto «Rig_Medium». Las animaciones salen de
## assets/characters/customer_anims.glb (lo genera tools/gen_characters.py con solo las 5 que se usan) y se copian
## al AnimationPlayer de cada cliente, reasignando cada pista al Skeleton3D de su cuerpo; las pistas de huesos que un
## cuerpo no tiene (el maniquí no tiene los huesos de las manos para armas) se quitan.

const ROOT := "res://assets/characters/"
const ANIM_FILE := "customer_anims.glb"
## file: GLB del cuerpo; tint: admite el color de ropa del cliente; weight: probabilidad relativa de aparecer.
const BODIES: Array = [
	{"file": "mannequin_medium.glb", "tint": true, "weight": 3},
	{"file": "skeleton_minion.glb", "tint": false, "weight": 1},
	{"file": "skeleton_rogue.glb", "tint": false, "weight": 1},
	{"file": "skeleton_mage.glb", "tint": false, "weight": 1},
]
const SCALE := 0.8   # los personajes de KayKit miden 2,2 m: a 0,8 quedan en 1,76 m (los ojos del jugador están a 1,62 m)
const ANIM_IDLE := "Idle_A"
const ANIM_WALK := "Walking_A"
const ANIM_WAVE := "Waving"
const ANIM_HAPPY := "Cheering"
const ANIM_ANGRY := "Hit_A"
const LOOPED: Array = ["Idle_A", "Walking_A"]

static var _source: Dictionary = {}   # nombre -> Animation tal como se importó
static var _libs: Dictionary = {}     # ruta al esqueleto + nº de huesos -> AnimationLibrary ya reasignada
static var _loaded := false

static func random_body() -> int:
	var total := 0
	for e in BODIES:
		total += int((e as Dictionary)["weight"])
	var r := randi() % maxi(1, total)
	for i in BODIES.size():
		r -= int((BODIES[i] as Dictionary)["weight"])
		if r < 0:
			return i
	return 0

## Instancia el cuerpo index escalado a tamaño humano (base en y=0, frente hacia +Z) con un AnimationPlayer que ya
## tiene las animaciones de cliente. Devuelve {"root": Node3D, "player": AnimationPlayer}, o {} si el cuerpo no se
## pudo cargar (el cliente usa entonces su modelo procedural).
static func spawn(index: int, tint: Color) -> Dictionary:
	var e: Dictionary = BODIES[clampi(index, 0, BODIES.size() - 1)]
	var path: String = ROOT + str(e["file"])
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("CharacterLib: no se pudo cargar %s (¿lo ha importado ya el editor de Godot?)" % path)
		return {}
	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("CharacterLib: %s no tiene un nodo 3D como raíz" % path)
		return {}
	var holder := Node3D.new()
	holder.name = "Body"
	holder.scale = Vector3.ONE * SCALE
	holder.add_child(model)
	if bool(e["tint"]) and tint != Color.WHITE:
		ModelLib.tint(model, tint)
	var player := AnimationPlayer.new()
	player.name = "CustomerAnims"
	model.add_child(player)   # root_node por defecto ("..") = model
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var lib := _library_for(model, skels[0] as Skeleton3D)
		if lib != null:
			player.add_animation_library("", lib)
	return {"root": holder, "player": player}

## Ruta relativa (texto) de un nodo descendiente; no necesita que estén en el árbol de escena.
static func _rel_path(from: Node, to: Node) -> String:
	var parts := PackedStringArray()
	var n := to
	while n != null and n != from:
		parts.insert(0, String(n.name))
		n = n.get_parent()
	return "/".join(parts)

static func _load_source() -> void:
	if _loaded:
		return
	_loaded = true
	var packed := load(ROOT + ANIM_FILE) as PackedScene
	if packed == null:
		push_error("CharacterLib: no se pudo cargar %s" % (ROOT + ANIM_FILE))
		return
	var inst := packed.instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("CharacterLib: %s no trae animaciones" % ANIM_FILE)
	else:
		var ap := players[0] as AnimationPlayer
		for nm in ap.get_animation_list():
			var key := String(nm)
			if key.contains("/"):
				key = key.get_slice("/", 1)
			_source[key] = ap.get_animation(nm)
	inst.free()

static func _library_for(model: Node, skel: Skeleton3D) -> AnimationLibrary:
	_load_source()
	if _source.is_empty():
		return null
	var sp := _rel_path(model, skel)
	var key := "%s#%d" % [sp, skel.get_bone_count()]
	if _libs.has(key):
		return _libs[key]
	var lib := AnimationLibrary.new()
	for nm in _source:
		var a := (_source[nm] as Animation).duplicate(true) as Animation
		for i in range(a.get_track_count() - 1, -1, -1):
			var tp := a.track_get_path(i)
			var bone := ""
			if tp.get_subname_count() > 0:
				bone = String(tp.get_subname(0))
			elif tp.get_name_count() > 0:
				bone = String(tp.get_name(tp.get_name_count() - 1))
			if bone == "" or skel.find_bone(bone) < 0:
				a.remove_track(i)
			else:
				a.track_set_path(i, NodePath("%s:%s" % [sp, bone]))
		a.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(nm) else Animation.LOOP_NONE
		lib.add_animation(StringName(nm), a)
	_libs[key] = lib
	return lib
