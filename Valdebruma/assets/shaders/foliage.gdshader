// Follaje (hojas, hierba, juncos): recorte alfa, viento en vértice y normales suaves.
// COLOR.rgb = tinte/oclusión horneados; COLOR.a = peso de viento (0 rígido, 1 puntas).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.42;
uniform float wind_scale = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float hue_variation = 0.12;
global uniform vec4 vb_wind;        // xy dirección, z fuerza, w racha

varying float v_dist;
varying vec3 v_tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a * wind_scale;
	float phase = origin.x * 0.37 + origin.z * 0.29;
	float t = TIME * (0.9 + 0.5 * vb_wind.w);
	float sway = sin(t * 1.1 + phase) * 0.6 + sin(t * 2.3 + phase * 1.7 + wp.y * 0.4) * 0.4;
	float flutter = sin(t * 5.3 + wp.x * 2.1 + wp.z * 1.7 + wp.y * 2.9) * 0.035;
	float amp = vb_wind.z * (0.05 + 0.10 * vb_wind.w);
	vec3 offs = vec3(vb_wind.x, 0.0, vb_wind.y) * (sway * amp * w * w * 2.2) + vec3(flutter, flutter * 0.5, flutter) * w * vb_wind.z;
	VERTEX += (vec4(offs, 0.0) * MODEL_MATRIX).xyz;
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float h = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_tint = tint * mix(vec3(1.0 - hue_variation, 1.0 - hue_variation * 0.4, 1.0 - hue_variation),
		vec3(1.0 + hue_variation * 0.6, 1.0, 1.0 - hue_variation * 0.5), h);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * COLOR.rgb * v_tint;
	ALPHA = c.a * (1.0 + clamp(v_dist * 0.006, 0.0, 0.35));
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.9;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;   // deshace el volteo automático: normales "esféricas" coherentes
	}
	BACKLIGHT = vec3(0.18, 0.24, 0.08);
}
