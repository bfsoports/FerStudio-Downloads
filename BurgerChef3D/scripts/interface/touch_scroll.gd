class_name TouchScroll
extends ScrollContainer
## Lista desplazable que se arrastra con el dedo desde cualquier punto, también empezando encima de un botón o una
## tarjeta. En Godot los botones paran los eventos táctiles (MOUSE_FILTER_STOP) y el ScrollContainer no se enteraba
## del arrastre: aquí todos los controles que tiene dentro pasan a MOUSE_FILTER_PASS (siguen recibiendo sus toques)
## y, en cuanto el arrastre supera la zona muerta, Godot cancela la pulsación del botón (NOTIFICATION_SCROLL_BEGIN),
## así que desplazar la lista no pulsa nada por error. Deslizadores y campos de texto conservan su filtro.

const DEADZONE := 14   # px que hay que arrastrar antes de que empiece el desplazamiento (un toque normal no desplaza)

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # barra visible cuando hay más contenido abajo
	scroll_deadzone = DEADZONE
	follow_focus = false

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _ready() -> void:
	_let_through(self)

func _on_node_added(n: Node) -> void:
	var c := n as Control
	if c != null and is_ancestor_of(c):
		_set_pass(c)

func _let_through(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			_set_pass(ch as Control)
		_let_through(ch)

static func _set_pass(c: Control) -> void:
	if c is Range or c is LineEdit or c is TextEdit or c is ScrollContainer:
		return
	if c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
