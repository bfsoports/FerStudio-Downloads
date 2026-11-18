extends UiScreen
## MapScreen — mapa del valle.
##
## Muestra el mapa dibujado por el generador del mundo con: tu posición y rumbo, los lugares
## que has descubierto (los demás aparecen como «?»), compañeros de grupo, señales recientes,
## tu punto de reaparición y tus estructuras. Se arrastra y se amplía; en «modo señal» un
## toque envía una marca a tu grupo (el servidor valida la distancia).

class MapView:
	extends Control
	var tex: Texture2D
	var zoom := 1.0
	var center := Vector2(640, 640)      # punto del mundo en el centro de la vista
	var mark_mode := false
	var _drag := false
	var _moved := 0.0

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func scale_px() -> float:
		return minf(size.x, size.y) / WorldMap.SIZE * zoom

	func to_screen(wx: float, wz: float) -> Vector2:
		return size * 0.5 + (Vector2(wx, wz) - center) * scale_px()

	func to_world(p: Vector2) -> Vector2:
		return center + (p - size * 0.5) / scale_px()

	func clamp_center() -> void:
		center.x = clampf(center.x, 0.0, WorldMap.SIZE)
		center.y = clampf(center.y, 0.0, WorldMap.SIZE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				zoom = minf(6.0, zoom * 1.15)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				zoom = maxf(1.0, zoom / 1.15)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_drag = true
					_moved = 0.0
				else:
					_drag = false
					if _moved < 8.0 and mark_mode:
						var w := to_world(mb.position)
						Net.send(Protocol.C.MARK, [w.x, GameData.world.ground(w.x, w.y), w.y])
						AudioDirector.play_ui("ping")
			queue_redraw()
		elif event is InputEventMouseMotion and _drag:
			var mm := event as InputEventMouseMotion
			_moved += mm.relative.length()
			center -= mm.relative / scale_px()
			clamp_center()
			queue_redraw()
		elif event is InputEventMagnifyGesture:
			zoom = clampf(zoom * (event as InputEventMagnifyGesture).factor, 1.0, 6.0)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b1210"))
		var s := scale_px()
		var origin := to_screen(0, 0)
		if tex != null:
			draw_texture_rect(tex, Rect2(origin, Vector2(WorldMap.SIZE, WorldMap.SIZE) * s), false)
		var font := UiKit.f_semi
		var found: Array = Session.progress.get("places", [])
		for p: Dictionary in GameData.world.places:
			var sp := to_screen(float(p.pos[0]), float(p.pos[1]))
			if not Rect2(Vector2.ZERO, size).grow(40).has_point(sp):
				continue
			var known := found.has(String(p.id))
			if bool(p.get("secret", false)) and not known:
				continue
			draw_circle(sp, 5.0, Color(0, 0, 0, 0.55))
			draw_circle(sp, 3.5, UiKit.C_ACCENT if known else Color(UiKit.C_DIM, 0.8))
			var text := String(p.name) if known else "?"
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string_outline(font, sp + Vector2(-w * 0.5, -9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
			draw_string(font, sp + Vector2(-w * 0.5, -9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.C_TEXT if known else UiKit.C_DIM)
		# estructuras propias
		for id: int in Session.structs.keys():
			var st: Dictionary = Session.structs[id]
			if Session.is_mine(st) and String(st.type) in ["refugio", "hoguera", "arcon", "banco", "saco_dormir"]:
				var sp := to_screen(st.pos.x, st.pos.z)
				draw_rect(Rect2(sp - Vector2(4, 4), Vector2(8, 8)), UiKit.C_WATER)
		# punto de reaparición
		var rs: Variant = Session.progress.get("respawn")
		if rs is Array:
			var sp := to_screen(float(rs[0]), float(rs[2]))
			draw_texture_rect(UiKit.icon("rest"), Rect2(sp - Vector2(11, 11), Vector2(22, 22)), false, UiKit.C_WATER)
		# señales
		for m: Dictionary in Session.marks:
			if Time.get_ticks_msec() - int(m.ms) > 90000:
				continue
			var sp := to_screen(m.pos.x, m.pos.z)
			draw_texture_rect(UiKit.icon("mark"), Rect2(sp - Vector2(12, 24), Vector2(24, 24)), false, UiKit.C_GOOD)
		# compañeros
		for gp: Array in Session.group_pos:
			if int(gp[0]) == Session.my_id:
				continue
			var sp := to_screen(float(gp[1]), float(gp[3]))
			draw_circle(sp, 6.0, Color(0, 0, 0, 0.6))
			draw_circle(sp, 4.5, UiKit.C_GOOD)
			var r: Dictionary = Session.roster.get(int(gp[0]), {})
			draw_string(font, sp + Vector2(8, 5), String(r.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.C_GOOD)
		# jugador: flecha con el rumbo
		if WorldRoot.current != null:
			var pl := WorldRoot.current.player
			var sp := to_screen(pl.global_position.x, pl.global_position.z)
			var fwd := Vector2(-sin(pl.yaw), -cos(pl.yaw))
			var side := Vector2(-fwd.y, fwd.x)
			var pts := PackedVector2Array([sp + fwd * 13.0, sp - fwd * 8.0 + side * 8.0, sp - fwd * 4.0, sp - fwd * 8.0 - side * 8.0])
			draw_colored_polygon(pts, Color(0, 0, 0, 0.7))
			var inner := PackedVector2Array([sp + fwd * 10.0, sp - fwd * 6.0 + side * 6.0, sp - fwd * 3.0, sp - fwd * 6.0 - side * 6.0])
			draw_colored_polygon(inner, Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.C_LINE, false, 1.0)

var _view: MapView
var _info: Label
var _mark_btn: Button

func setup() -> void:
	frame(tr("MAP_TITLE"), 0.55, 1220.0, "map")
	var h := UiKit.hbox(12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	_view = MapView.new()
	_view.tex = load("res://assets/textures/gen/world_map.png")
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(520, 460)
	h.add_child(_view)
	var side := UiKit.vbox(8)
	side.custom_minimum_size = Vector2(250, 0)
	h.add_child(side)
	_info = UiKit.wrap_label("", 16, UiKit.C_TEXT)
	side.add_child(_info)
	side.add_child(UiKit.line())
	for def: Array in [["mark", UiKit.C_ACCENT, "MAP_LEG_PLACE"], ["profile", UiKit.C_GOOD, "MAP_LEG_GROUP"], ["mark", UiKit.C_GOOD, "MAP_LEG_MARK"], ["rest", UiKit.C_WATER, "MAP_LEG_RESPAWN"]]:
		var row := UiKit.hbox(8)
		row.add_child(UiKit.icon_rect(String(def[0]), 18, def[1]))
		row.add_child(UiKit.label(tr(String(def[2])), 15, UiKit.C_DIM))
		side.add_child(row)
	side.add_child(UiKit.spacer(true))
	var zoom := UiKit.hbox(8)
	zoom.add_child(UiKit.icon_button("minus", func() -> void:
		_view.zoom = maxf(1.0, _view.zoom / 1.4)
		_view.queue_redraw()))
	zoom.add_child(UiKit.icon_button("plus", func() -> void:
		_view.zoom = minf(6.0, _view.zoom * 1.4)
		_view.queue_redraw()))
	zoom.add_child(UiKit.icon_button("compass", func() -> void: _center_on_player()))
	side.add_child(zoom)
	_mark_btn = UiKit.button(tr("MAP_MARK"), "mark", func() -> void:
		_view.mark_mode = not _view.mark_mode
		_style_mark())
	side.add_child(_mark_btn)
	side.add_child(UiKit.wrap_label(tr("MAP_MARK_HINT"), 14, UiKit.C_DIM))
	_view.zoom = 2.2
	_center_on_player()
	Session.progress_changed.connect(refresh)
	Session.mark_received.connect(func(_p: int, _n: String, _pos: Vector3) -> void: _view.queue_redraw())

func _style_mark() -> void:
	_mark_btn.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.C_GOOD, 0.3) if _view.mark_mode else Color(UiKit.C_PANEL2, 0.96), 10,
		UiKit.C_GOOD if _view.mark_mode else UiKit.C_LINE, 1, 12))

func _center_on_player() -> void:
	if WorldRoot.current != null:
		var p := WorldRoot.current.player.global_position
		_view.center = Vector2(p.x, p.z)
		_view.queue_redraw()

func refresh() -> void:
	var found: Array = Session.progress.get("places", [])
	var total := 0
	for p: Dictionary in GameData.world.places:
		total += 1
	var where := ""
	if WorldRoot.current != null:
		var pos := WorldRoot.current.player.global_position
		where = tr("REGION_" + GameData.world.region_name(pos.x, pos.z).to_upper())
	_info.text = tr("MAP_INFO") % [where, found.size(), total]
	_view.queue_redraw()

func _process(_delta: float) -> void:
	if Engine.get_frames_drawn() % 20 == 0:
		_view.queue_redraw()
