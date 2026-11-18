extends Control
## Splash — pantalla de arranque: logotipo, precarga de lo que el menú necesita y paso al menú.
## La precarga se reparte en varios fotogramas para que la barra avance y la app responda.

const PRELOAD := ["res://assets/ui/logo.png", "res://assets/textures/gen/world_map.png", "res://assets/models/characters/survivor.glb",
	"res://assets/models/characters/fp_arms.glb", "res://assets/models/structures/refugio.glb", "res://assets/models/structures/hoguera.glb",
	"res://assets/BinbunVFX_Vol2/FlameFX/effects/fire/vfx_basic_fire_01.tscn", "res://scripts/ui/hud.gd", "res://scripts/ui/inventory_screen.gd"]

func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.C_BG
	UiKit.full_rect(bg)
	add_child(bg)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	var v := UiKit.vbox(26)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(760, 228)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.modulate.a = 0.0
	v.add_child(logo)
	var bar := UiKit.bar(UiKit.C_ACCENT, 6.0)
	bar.custom_minimum_size = Vector2(420, 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(bar)
	var note := UiKit.label(tr("SPLASH_LOADING"), 16, UiKit.C_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	logo.create_tween().tween_property(logo, "modulate:a", 1.0, 0.8)
	await get_tree().process_frame
	for i in PRELOAD.size():
		if ResourceLoader.exists(PRELOAD[i]):
			load(PRELOAD[i])
		bar.value = float(i + 1) / float(PRELOAD.size()) * 100.0
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	Ui.goto_menu()
