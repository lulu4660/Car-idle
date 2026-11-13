// Arbres, cactus, buissons, rochers (vegetation.gd) : couleur par sommet, mats ; la nuit,
// éclairés par les réverbères proches et par les phares de la voiture.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/night_light.gdshaderinc"
#include "res://shaders/see_through.gdshaderinc"
global uniform float weather_wet;
global uniform vec3 weather_wind;
uniform sampler2D night_light_tex : filter_linear, repeat_disable;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float world_size = 1024.0;

varying vec3 wpos;
// Hauteur du point au-dessus du pied de l'objet (pied plus sombre).
varying float vh;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Vent : les arbres se balancent, d'autant plus que le point est haut (le pied ne bouge
	// pas). Déplacement calculé dans le monde puis ramené dans le repère de l'objet (rotation
	// autour de la verticale et échelle uniforme : transposée divisée par l'échelle²).
	float h = wpos.y - MODEL_MATRIX[3].y;
	vh = h;
	if (h > 0.3) {
		float ph = MODEL_MATRIX[3].x * 0.13 + MODEL_MATRIX[3].z * 0.17;
		float sway = (0.55 + 0.45 * sin(TIME * (1.1 + weather_wind.z * 1.6) + ph)) * weather_wind.z + 0.04 * sin(TIME * 0.9 + ph);
		vec2 d = normalize(weather_wind.xy + vec2(1e-4)) * sway * h * h * 0.012;
		vec3 off = vec3(d.x, 0.0, d.y);
		float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
		VERTEX += vec3(dot(MODEL_MATRIX[0].xyz, off), dot(MODEL_MATRIX[1].xyz, off), dot(MODEL_MATRIX[2].xyz, off)) / s2;
	}
}

void fragment() {
	if (see_fade(wpos, INV_VIEW_MATRIX[3].xyz) > see_bayer(FRAGCOORD.xy)) {
		discard;
	}
	// Pastel : un peu moins saturé, plus clair, réchauffé (style « Art of Rally »).
	vec3 base = COLOR.rgb;
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	base = mix(vec3(lum), base, 0.8) * 1.12 + vec3(0.03, 0.02, 0.0);
	// Pied plus sombre (ombrage de contact), haut un peu plus clair.
	base *= mix(0.68, 1.06, smoothstep(0.0, 3.0, vh));
	ALBEDO = base * mix(1.0, 0.78, weather_wet);
	ROUGHNESS = 1.0;
	if (night > 0.01) {
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float lamp = texture(night_light_tex, (wpos.xz + vec2(world_size * 0.5)) / world_size).r;
		EMISSION = COLOR.rgb * (lamp_color * lamp * lamp * night * 1.2 + head_color * headlight(wpos, nw) * 1.6);
	}
}
