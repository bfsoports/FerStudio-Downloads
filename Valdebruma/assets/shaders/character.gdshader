shader_type spatial;
// Personaje con texturas PBR horneadas (modelos de Hyper3D Rodin).
// El canal R del mapa ORM no guarda oclusión sino la máscara de la prenda teñible (chaqueta):
// cada jugador elige color con un uniform de instancia, sin duplicar materiales.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float normal_strength = 1.0;
uniform float tint_gain = 2.6;          // compensa la luminancia media de la prenda original
instance uniform vec3 tint : source_color = vec3(0.0, 0.0, 0.0);
instance uniform float tint_on = 0.0;

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	float lum = dot(a, vec3(0.299, 0.587, 0.114));
	vec3 dyed = clamp(tint * lum * tint_gain, vec3(0.0), vec3(1.0));
	ALBEDO = mix(a, dyed, orm.r * tint_on);
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
