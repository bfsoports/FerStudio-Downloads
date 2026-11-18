class_name Customer
extends Node3D
## Cliente NPC con modelo real animado (maniquí o esqueleto de KayKit, ver CharacterLib), movimiento por rutas, burbuja
## de pedido y reacciones. Si el modelo no se puede cargar usa el antiguo cuerpo procedural.

signal arrived

enum State { ENTERING, QUEUING, WAITING, RECEIVING, LEAVING }

var state: int = State.ENTERING
var order: Order = null
var service_point: ServicePoint = null
var speed: float = 2.3
var _path: Array = []
var _moving := false
var _anim_t := 0.0
var _body: Node3D
var _bar: Bar3D
var _icon: Node3D = null
var _msg: Label3D
var _spin := 0.0
var _anim: AnimationPlayer = null   # null = cuerpo procedural (se anima con balanceo por código)

func setup(look: Dictionary) -> void:
	var body := int(look.get("body", -1))
	if body >= 0:
		var shirt_col := Util.html_color(str(look.get("shirt", "#ffffff")))
		var made := CharacterLib.spawn(body, Color.WHITE.lerp(shirt_col, 0.55))
		if not made.is_empty():
			_body = made["root"]
			add_child(_body)
			_anim = made["player"]
			_play(CharacterLib.ANIM_IDLE)
	if _body == null:
		_build_procedural(look)
	_bar = Bar3D.new(0.62, true)
	_bar.position = Vector3(0, 2.05, 0)
	_bar.show_bar(false)
	add_child(_bar)
	_msg = Prims.label3d(self, "", Vector3(0, 2.3, 0), 0.006, 64, Palette.CREAM)
	_msg.visible = false

## Reproduce una animación del cuerpo real con una transición corta (no hace nada con el cuerpo procedural).
func _play(anim_name: String, then_idle: bool = false) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)
	_anim.clear_queue()
	if then_idle:
		_anim.queue(CharacterLib.ANIM_IDLE)

func _build_procedural(look: Dictionary) -> void:
	_body = Node3D.new()
	add_child(_body)
	var skin := Prims.mat(Util.html_color(str(look.get("skin", "#f5cfa0"))), 0.8)
	var shirt := Prims.mat(Util.html_color(str(look.get("shirt", "#d8392b"))), 0.8)
	var pants := Prims.mat(Util.html_color(str(look.get("pants", "#3b4a6b"))), 0.8)
	var hair := Prims.mat(Util.html_color(str(look.get("hair", "#2b1b12"))), 0.9)
	Prims.box(_body, Vector3(0.17, 0.5, 0.2), Vector3(-0.1, 0.25, 0), pants)
	Prims.box(_body, Vector3(0.17, 0.5, 0.2), Vector3(0.1, 0.25, 0), pants)
	Prims.capsule(_body, 0.25, 0.8, Vector3(0, 0.88, 0), shirt)
	var arm_l := Prims.capsule(_body, 0.07, 0.55, Vector3(-0.33, 0.9, 0), shirt)
	var arm_r := Prims.capsule(_body, 0.07, 0.55, Vector3(0.33, 0.9, 0), shirt)
	arm_l.rotation.z = 0.12
	arm_r.rotation.z = -0.12
	var head := Node3D.new()
	head.position = Vector3(0, 1.5, 0)
	_body.add_child(head)
	Prims.sphere(head, 0.21, Vector3.ZERO, skin, 1.0, false, 16)
	var eye := Prims.mat(Palette.BROWN)
	Prims.sphere(head, 0.026, Vector3(-0.075, 0.03, 0.19), eye, 1.0, false, 8)
	Prims.sphere(head, 0.026, Vector3(0.075, 0.03, 0.19), eye, 1.0, false, 8)
	Prims.box(head, Vector3(0.09, 0.016, 0.01), Vector3(0, -0.075, 0.2), eye)
	match str(look.get("hat", "none")):
		"cap":
			var hat := Prims.mat(Util.html_color(str(look.get("shirt", "#d8392b"))).darkened(0.15), 0.8)
			Prims.sphere(head, 0.225, Vector3(0, 0.04, 0), hat, 0.8, true, 16)
			Prims.box(head, Vector3(0.24, 0.015, 0.16), Vector3(0, 0.06, 0.2), hat)
		"beanie":
			Prims.sphere(head, 0.225, Vector3(0, 0.02, 0), Prims.mat(Palette.TEAL, 0.9), 0.95, true, 16)
		_:
			Prims.sphere(head, 0.215, Vector3(0, 0.03, -0.01), hair, 0.75, true, 16)

func walk(path: Array) -> void:
	_path = path.duplicate()
	_moving = not _path.is_empty()
	if _moving:
		_play(CharacterLib.ANIM_WALK)
	else:
		arrived.emit()

func face_counter() -> void:
	rotation.y = 0.0

## Muestra la burbuja con el nombre del pedido y un icono 3D de la hamburguesa pedida.
func show_order(o: Order) -> void:
	_play(CharacterLib.ANIM_WAVE, true)
	_bar.show_bar(true)
	_bar.set_text(o.recipe_name())
	if _icon != null:
		_icon.queue_free()
	_icon = Node3D.new()
	_icon.position = Vector3(0, 2.42, 0)
	add_child(_icon)
	var y := 0.0
	var i := 0
	for id in Catalog.recipe_layers(o.recipe_id):
		FoodModels.add_layer(_icon, str(id), y, FoodModels.progress_for_state(str(id), FoodItem.State.COOKED), i)
		y += FoodModels.layer_height(str(id))
		i += 1
	_icon.scale = Vector3.ONE * 0.5
	if str(Catalog.recipe(o.recipe_id).get("kind", "")) == "combo":
		var fx := Prims.mat(Palette.MUSTARD)
		Prims.box(_icon, Vector3(0.12, 0.1, 0.06), Vector3(0.35, 0.05, 0), fx)

func update_patience(ratio: float) -> void:
	var col := Palette.LETTUCE
	if ratio < 0.3:
		col = Palette.KETCHUP
	elif ratio < 0.6:
		col = Palette.MUSTARD
	_bar.set_ratio(ratio, col)

func react(satisfaction: float, outcome: String) -> void:
	_bar.show_bar(false)
	if _icon != null:
		_icon.visible = false
	state = State.RECEIVING
	var key := "react.great"
	if outcome == "expired":
		key = "react.expired"
	elif outcome == "wrong" or satisfaction < 0.4:
		key = "react.bad"
	elif satisfaction < 0.75:
		key = "react.ok"
	_msg.text = Loc.t(key)
	_msg.visible = true
	if outcome == "ok" and satisfaction >= 0.6:
		AudioManager.play_sfx("happy", -5.0)
		if _anim != null:
			_play(CharacterLib.ANIM_HAPPY, true)
			return
		var tw := create_tween()
		tw.tween_property(_body, "position:y", 0.25, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		AudioManager.play_sfx("impatient", -6.0)
		if _anim != null:
			_play(CharacterLib.ANIM_ANGRY, true)
			return
		var tw2 := create_tween()
		for _k in 3:
			tw2.tween_property(_body, "rotation:z", 0.12, 0.07)
			tw2.tween_property(_body, "rotation:z", -0.12, 0.07)
		tw2.tween_property(_body, "rotation:z", 0.0, 0.07)

func _process(delta: float) -> void:
	if _icon != null and _icon.visible:
		_spin += delta
		_icon.rotation.y = _spin
	if order != null and order.is_open() and state == State.WAITING:
		update_patience(order.patience_ratio())
	if _moving and not _path.is_empty():
		var target: Vector3 = _path[0]
		var to := target - position
		to.y = 0.0
		var dist := to.length()
		var step := speed * delta
		if dist <= step:
			position = Vector3(target.x, 0.0, target.z)
			_path.pop_front()
			if _path.is_empty():
				_moving = false
				_body.position.y = 0.0
				_body.rotation.z = 0.0
				_play(CharacterLib.ANIM_IDLE)
				arrived.emit()
		else:
			var dir := to / dist
			position += dir * step
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0.0, 1.0))
			if _anim == null:
				_anim_t += delta * 9.0
				_body.position.y = absf(sin(_anim_t)) * 0.05
				_body.rotation.z = sin(_anim_t) * 0.04
