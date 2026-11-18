class_name TouchButton
extends Control
## Visual for an on-screen button. Input is NOT handled here: TouchControls
## routes every finger centrally so multi-touch never conflicts.

@export var icon_name := ""
@export var radius := 52.0
@export var accent := UIStyle.TEXT
var pressed := false:
	set(v):
		pressed = v
		queue_redraw()
var progress := 0.0:
	set(v):
		progress = v
		queue_redraw()
var badge_text := ""
var _tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = UIStyle.icon(icon_name)
	custom_minimum_size = Vector2(radius, radius) * 2.0
	size = custom_minimum_size
	pivot_offset = size * 0.5


func center_global() -> Vector2:
	return global_position + size * 0.5 * scale


func hit(p: Vector2) -> bool:
	return visible and p.distance_to(center_global()) <= radius * scale.x * 1.18


func _draw() -> void:
	var c := size * 0.5
	var a := Settings.controls_opacity
	var bg := Color(0.06, 0.07, 0.06, 0.55 * a + 0.15)
	if pressed:
		bg = Color(accent.r * 0.45, accent.g * 0.35, accent.b * 0.2, 0.75)
	draw_circle(c, radius, bg)
	draw_arc(c, radius - 2.0, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.55 * a + 0.35), 3.0, true)
	if progress > 0.0:
		draw_arc(c, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UIStyle.ACCENT, 6.0, true)
	if _tex:
		var s := radius * 1.05
		var col := Color(1, 1, 1, 0.65 * a + 0.35)
		if pressed:
			col = Color(1, 0.92, 0.75, 1)
		draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)
	if badge_text != "":
		var f := UIStyle.title_font()
		draw_string(f, c + Vector2(radius * 0.35, radius * 0.95), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.GOLD)
