// Ombre de la voiture calculée directement (sans carte d'ombre) : le rayon qui part du sol
// vers le soleil traverse-t-il la caisse (deux boîtes : bas de caisse et habitacle) ?
// Le bord s'adoucit avec la longueur de traversée : ombre lisse à toute résolution.
// + ombres du décor fixe précalculées (tools/bake_shadows.gd).
uniform sampler2D static_shadow_tex : filter_linear, repeat_disable;
global uniform vec4 shadow_mix;
// Nuit : lumière des réverbères au sol, précalculée (tools/bake_shadows.gd -> lights.png).
uniform sampler2D night_light_tex : filter_linear, repeat_disable;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.72, 0.42);
#include "res://shaders/night_light.gdshaderinc"
uniform mat4 car_inv = mat4(0.0);          // monde -> repère de la voiture
uniform vec3 car_sun = vec3(0.0, 1.0, 0.0); // direction du soleil dans ce repère
uniform vec3 car_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 box1_min = vec3(0.0);
uniform vec3 box1_max = vec3(0.0);
uniform vec3 box2_min = vec3(0.0);
uniform vec3 box2_max = vec3(0.0);
uniform float shadow_strength = 0.92;

float box_through(vec3 p, vec3 l, vec3 bmin, vec3 bmax) {
	vec3 inv = 1.0 / l;
	vec3 t1 = (bmin - p) * inv;
	vec3 t2 = (bmax - p) * inv;
	vec3 lo = min(t1, t2);
	vec3 hi = max(t1, t2);
	float tin = max(max(lo.x, lo.y), max(lo.z, 0.0));
	float tout = min(min(hi.x, hi.y), hi.z);
	return smoothstep(0.0, 0.35, tout - tin);
}

// 1 = plein soleil, 0 = ombre complète.
float sun_visibility(vec3 wp, float ws) {
	// Carte d'ombres à 50 cm par pixel : la valeur interpolée est resserrée en un contour
	// net mais lisse (pas d'escalier, pas de flou), comme une ombre de soleil.
	// Quatre cartes (une par canal, 4 positions du soleil) mélangées selon l'heure.
	float m = smoothstep(0.18, 0.62, dot(texture(static_shadow_tex, (wp.xz + vec2(ws * 0.5)) / ws), shadow_mix));
	float car = 0.0;
	if (distance(wp, car_pos) < 22.0) {
		vec3 p = (car_inv * vec4(wp, 1.0)).xyz;
		vec3 l = car_sun + vec3(1e-4);
		car = max(box_through(p, l, box1_min, box1_max), box_through(p, l, box2_min, box2_max));
	}
	return 1.0 - max(m, car) * shadow_strength;
}


// Lumière des réverbères au sol (0 le jour).
vec3 lamp_glow(vec3 wp, float ws) {
	if (night < 0.01) {
		return vec3(0.0);
	}
	float l = texture(night_light_tex, (wp.xz + vec2(ws * 0.5)) / ws).r;
	return lamp_color * l * l * night * 1.6;
}
