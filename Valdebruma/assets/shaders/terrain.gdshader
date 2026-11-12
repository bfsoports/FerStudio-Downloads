// Terreno: mezcla de 4 capas (hierba, hojarasca, tierra, roca) según un mapa de cubierta
// global, tinte macro del valle y oscurecimiento por humedad (lluvia).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D splat_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D tint_map : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_forest : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float world_size = 1280.0;
uniform float tile = 0.22;
uniform float normal_strength = 0.6;
global uniform float vb_wetness;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 guv = wpos.xz / world_size;
	vec3 sp = texture(splat_map, guv).rgb;
	float wg = clamp(1.0 - sp.r - sp.g - sp.b, 0.0, 1.0);
	vec2 uv = wpos.xz * tile;
	vec3 grass = texture(tex_grass, uv).rgb;
	vec3 col = grass * wg + texture(tex_forest, uv).rgb * sp.r + texture(tex_dirt, uv * 0.8).rgb * sp.g + texture(tex_rock, uv * 0.6).rgb * sp.b;
	// variación a gran escala para romper la repetición
	float macro = dot(texture(tex_grass, uv * 0.071).rgb, vec3(0.5, 0.8, 0.2));
	col *= mix(0.78, 1.22, clamp(macro * 1.6, 0.0, 1.0));
	col *= texture(tint_map, guv).rgb * 2.0;
	col *= mix(1.0, 0.72, vb_wetness * (0.5 + 0.5 * sp.g));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.55, vb_wetness * (0.3 + 0.7 * sp.g));
	NORMAL_MAP = texture(detail_normal, uv * 1.7).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (0.5 + sp.b + sp.g * 0.5);
}
