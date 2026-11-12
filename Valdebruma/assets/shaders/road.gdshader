// Carreteras y caminos: cinta sobre el terreno con bordes desvanecidos (COLOR.a) y, en
// asfalto, líneas pintadas gastadas. UV.x = 0..1 a lo ancho, UV.y = metros a lo largo.
shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float width = 6.4;
uniform float lines = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
global uniform float vb_wetness;

void fragment() {
	vec2 uv = vec2(UV.x * width, UV.y) * 0.25;
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	float n = texture(noise_tex, uv * 0.35).r;
	if (lines > 0.5) {
		float x = (UV.x - 0.5) * width;
		float center = (1.0 - smoothstep(0.06, 0.1, abs(x))) * step(0.5, fract(UV.y / 6.0));
		float edge = 1.0 - smoothstep(0.05, 0.09, abs(abs(x) - (width * 0.5 - 0.35)));
		float paint = max(center, edge) * smoothstep(0.35, 0.6, n);
		col = mix(col, vec3(0.78, 0.76, 0.68), paint * 0.75);
	}
	col *= mix(0.8, 1.1, n);
	ALBEDO = col * mix(1.0, 0.7, vb_wetness);
	ROUGHNESS = mix(0.9, 0.35, vb_wetness);
	ALPHA = COLOR.a * smoothstep(0.0, 0.5, n + COLOR.a * 0.8);
}
