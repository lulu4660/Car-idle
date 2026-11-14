// Imposteur d'arbre (vegetation.gd, impostors.gd) : deux triangles tournés vers la caméra
// qui montrent une photo du modèle prise au démarrage (couleur + normales, pour être éclairé
// comme le vrai modèle par le soleil et la lune). Le passage modèle ↔ imposteur est un fondu
// minuté (`lod_fade`, matériau propre à chaque case, en 0,25 s) : les deux ne sont dessinés ensemble que pendant ce
// fondu, jamais tant que la caméra reste à une certaine distance.
shader_type spatial;
render_mode specular_disabled, cull_disabled;

#include "res://shaders/far_fade.gdshaderinc"
global uniform float weather_wet;
global uniform float lod_debug;
// Les photos sont enregistrées telles quelles (valeurs linéaires, sans conversion sRGB).
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : filter_linear_mipmap, repeat_disable;
// Taille de l'image dans le monde (m, à l'échelle 1 du modèle) et hauteur de son centre.
uniform float quad_size = 10.0;
uniform float center_y = 5.0;
// Part de l'imposteur pendant le fondu (0 = modèle seul, 1 = imposteur seul).
uniform float lod_fade = 1.0;

varying float flip;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 center = (MODEL_MATRIX * vec4(0.0, center_y, 0.0, 1.0)).xyz;
	// Arbres en miroir une fois sur deux : moins de répétition.
	flip = fract(MODEL_MATRIX[3].x * 0.731 + MODEL_MATRIX[3].z * 0.419) < 0.5 ? -1.0 : 1.0;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = center + (right * VERTEX.x + up * VERTEX.y) * quad_size * s;
	v_far = far_amount(MODEL_MATRIX, INV_VIEW_MATRIX);
	v_far_seed = far_seed(MODEL_MATRIX);
	if (v_far >= 1.0) {
		w = center;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

float lod_bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	// Trame complémentaire de celle du modèle : chaque pixel est à l'un ou à l'autre.
	if (lod_fade <= lod_bayer(FRAGCOORD.xy) || v_far > far_bayer(FRAGCOORD.xy, v_far_seed)) {
		discard;
	}
	vec2 uv = vec2(flip > 0.0 ? UV.x : 1.0 - UV.x, UV.y);
	vec4 a = texture(albedo_tex, uv);
	if (a.a < 0.45) {
		discard;
	}
	vec3 n = texture(normal_tex, uv).rgb;
	n = n * 2.0 - 1.0;
	n.x *= flip;
	n = normalize(n + vec3(0.0, 0.0, 1e-4));
	NORMAL = n;   // déjà dans le repère de la caméra (photo prise face à elle)
	ALBEDO = mix(a.rgb * mix(1.0, 0.78, weather_wet), vec3(0.55, 0.25, 0.95), lod_debug);
	ROUGHNESS = 1.0;
}
