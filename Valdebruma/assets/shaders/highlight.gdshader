// Realce del objeto apuntado (capa aditiva sobre el material original).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec3 color : source_color = vec3(1.0, 0.84, 0.5);

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color * (0.10 + 0.55 * f) * (0.75 + 0.25 * sin(TIME * 4.5));
}
