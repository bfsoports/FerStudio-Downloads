// Campana translúcida del Farol: brillo en los bordes (fresnel) y pulso lento.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.45, 0.85, 0.9, 0.42);
uniform float glow = 1.2;
instance uniform float pulse = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float p = 0.75 + 0.25 * sin(TIME * 1.7);
	ALBEDO = base_color.rgb * COLOR.rgb;
	EMISSION = base_color.rgb * glow * (0.35 + fres) * p * pulse;
	ALPHA = clamp(base_color.a + fres * 0.5, 0.0, 1.0);
}
