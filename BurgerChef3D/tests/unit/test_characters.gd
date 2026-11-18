extends RefCounted
## Clientes con modelos reales (KayKit): cada cuerpo se instancia, tiene esqueleto y recibe las animaciones de cliente
## reasignadas a su esqueleto. Requiere que el editor haya importado assets/characters/.

func run(t) -> void:
	for i in CharacterLib.BODIES.size():
		var made := CharacterLib.spawn(i, Color(0.8, 0.9, 1.0))
		var file := str((CharacterLib.BODIES[i] as Dictionary)["file"])
		t.ok(not made.is_empty(), "el cuerpo %s se instancia" % file)
		if made.is_empty():
			continue
		var root := made["root"] as Node3D
		var player := made["player"] as AnimationPlayer
		t.ok(not root.find_children("*", "Skeleton3D", true, false).is_empty(), "%s tiene Skeleton3D" % file)
		for a in [CharacterLib.ANIM_IDLE, CharacterLib.ANIM_WALK, CharacterLib.ANIM_WAVE, CharacterLib.ANIM_HAPPY, CharacterLib.ANIM_ANGRY]:
			t.ok(player.has_animation(a), "%s tiene la animación %s" % [file, a])
		if player.has_animation(CharacterLib.ANIM_WALK):
			var anim := player.get_animation(CharacterLib.ANIM_WALK)
			t.ok(anim.get_track_count() > 10, "%s: la animación de andar conserva sus pistas (%d)" % [file, anim.get_track_count()])
			t.eq(anim.loop_mode, Animation.LOOP_LINEAR, "%s: andar se repite en bucle" % file)
		root.free()
	var c := Customer.new()
	c.setup({"body": 0, "shirt": "#4a90d9"})
	t.ok(c.get_child_count() > 0, "un cliente con cuerpo real se construye")
	c.free()
	var c2 := Customer.new()
	c2.setup({})
	t.ok(c2.get_child_count() > 0, "un cliente sin cuerpo real usa el modelo procedural")
	c2.free()
