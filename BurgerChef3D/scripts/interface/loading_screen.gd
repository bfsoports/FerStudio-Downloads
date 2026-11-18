class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga al estilo de Brotato: fondo oscuro liso, el logotipo de FerStudio en el centro (se ajusta a
## cualquier proporción de pantalla sin deformarse ni recortarse, y sus bordes se funden con el fondo), el texto
## «Cargando» grande con puntos animados y la versión del juego abajo a la derecha. Entra y sale con un fundido.
## La usa SceneManager al arrancar el juego y al pasar del menú a la partida y de vuelta.

const LOGO_PATH := "res://assets/branding/ferstudio_logo.png"
const BG_COLOR := Color8(14, 18, 28)        # el mismo color que los bordes del logotipo
const FADE := 0.22

var _root: Control
var _label: Label
var _logo: TextureRect
var _t := 0.0
var _shown := false

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# logotipo: ocupa como mucho el 70 % del ancho y el 58 % del alto, centrado en la parte superior
	_logo = TextureRect.new()
	_logo.texture = load(LOGO_PATH) as Texture2D
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.anchor_left = 0.15
	_logo.anchor_right = 0.85
	_logo.anchor_top = 0.08
	_logo.anchor_bottom = 0.66
	_logo.pivot_offset = Vector2.ZERO
	_root.add_child(_logo)
	# «Cargando...» grande y centrado
	_label = UIKit.label("", "LabelTitle", 54)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.7
	_label.anchor_bottom = 0.86
	_root.add_child(_label)
	# versión abajo a la derecha
	var ver := UIKit.label("v_%s" % Const.GAME_VERSION, "LabelLight", 22)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -260.0
	ver.offset_top = -48.0
	ver.offset_right = -28.0
	ver.offset_bottom = -16.0
	_root.add_child(ver)
	_root.modulate.a = 0.0
	_root.visible = false
	_update_text()

func _process(delta: float) -> void:
	if not _shown:
		return
	_t += delta
	_update_text()
	# el logotipo «respira» un poco mientras carga
	var s := 1.0 + 0.02 * sin(_t * 2.6)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2(s, s)

func _update_text() -> void:
	var dots := int(_t * 3.0) % 4
	# los puntos que faltan se dibujan transparentes para que el texto no salte de sitio
	_label.text = Loc.t("loading.text") + ".".repeat(dots) + " ".repeat(3 - dots)

## Muestra la pantalla con un fundido. instant = sin fundido (al arrancar el juego).
func show_screen(instant: bool = false) -> void:
	_shown = true
	_t = 0.0
	_root.visible = true
	if instant:
		_root.modulate.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE)
	await tw.finished

func hide_screen() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE)
	await tw.finished
	_root.visible = false
	_shown = false
