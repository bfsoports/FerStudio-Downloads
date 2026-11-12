// Agua del río, el marjal y el lago: un único plano al nivel del agua. La profundidad se
// obtiene del mapa de alturas (sin textura de profundidad de pantalla: barato en móvil).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert;

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float world_size = 1280.0;
uniform float water_level = 10.0;
uniform vec3 shallow : source_color = vec3(0.22, 0.34, 0.30);
uniform vec3 deep : source_color = vec3(0.06, 0.13, 0.15);
global uniform vec4 vb_wind;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = texture(height_map, wpos.xz / world_size).r;
	float depth = water_level - h;
	if (depth < -0.02) {
		discard;
	}
	float t = TIME * (0.03 + 0.03 * vb_wind.z);
	vec2 flow = vb_wind.xy * t;
	vec3 n1 = texture(normal_tex, wpos.xz * 0.11 + flow).rgb;
	vec3 n2 = texture(normal_tex, wpos.xz * 0.047 - flow * 0.7 + vec2(0.37, 0.11)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 0.55 + 0.4 * vb_wind.z;
	float k = clamp(depth / 2.2, 0.0, 1.0);
	float foam = (1.0 - smoothstep(0.0, 0.16, depth)) * 0.35;
	ALBEDO = mix(shallow, deep, k) + foam;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(smoothstep(0.0, 0.5, depth) * 0.55 + k * 0.35 + fres * 0.3, 0.0, 0.96);
	ROUGHNESS = 0.08;
	METALLIC = 0.25;
	SPECULAR = 0.7;
}
