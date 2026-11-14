// Ombre des arbres lointains (vegetation.gd), d'après une vidéo montrée par l'auteur : les
// ombres précalculées ne couvrent qu'une fenêtre de 256 m autour de la voiture
// (sun_shadows.gd) ; au-delà, chaque imposteur projette au sol sa propre photo, couchée
// dans l'axe du soleil (ou de la lune), allongée quand l'astre est bas, posée sur le relief.
// Elle n'apparaît que hors de la fenêtre des vraies ombres (pas d'ombre en double), avec
// l'imposteur (`lod_fade`), et pâlit sous les nuages (`sun_glint`).
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/far_fade.gdshaderinc"
global uniform vec3 sun_dir;
global uniform vec3 sun_glint;
global uniform vec4 shadow_rect;
global uniform float lod_debug;
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D height_tex : filter_nearest;
uniform float world_size = 1024.0;
// Photo de l'imposteur : taille (m à l'échelle 1), hauteur de son centre et du pied du modèle.
uniform float quad_size = 10.0;
uniform float center_y = 5.0;
uniform float foot_y = 0.0;
uniform float lod_fade = 1.0;
// Teinte de l'ombre au plus fort : celle des vraies ombres sur le sable (mesurée). Les
// ombres qui se chevauchent se multiplient : teinte claire pour rester juste en forêt.
uniform vec3 shade : source_color = vec3(0.86, 0.81, 0.92);

varying float k;
varying vec2 img_uv;

float ground(vec2 xz) {
	ivec2 g = ivec2(clamp(xz + vec2(world_size * 0.5), vec2(0.0), vec2(world_size)));
	return texelFetch(height_tex, g, 0).r;
}

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 foot = (MODEL_MATRIX * vec4(0.0, foot_y, 0.0, 1.0)).xyz;
	vec3 l = normalize(sun_dir + vec3(0.0, 1e-4, 0.0));
	float el = clamp(l.y, 0.14, 1.0);
	vec2 away = -normalize(l.xz + vec2(1e-4));
	vec2 side = vec2(-away.y, away.x);
	// Dans la photo, le pied est à `v_foot` (0 = haut de l'image) : l'ombre va du pied
	// (a = 0) au sommet de l'arbre (a = 1), longueur = hauteur / tan(élévation).
	float v_foot = clamp(0.5 + (center_y - foot_y) / quad_size, 0.0, 1.0);
	float h = quad_size * v_foot * s;
	float len = min(h * sqrt(1.0 - el * el) / el, h * 4.0);
	float a = 0.5 - VERTEX.z;
	img_uv = vec2(VERTEX.x + 0.5, v_foot * (1.0 - a));
	vec2 xz = foot.xz + away * (a * len) + side * (VERTEX.x * quad_size * s * 0.9);
	vec3 w = vec3(xz.x, ground(xz) + 0.25, xz.y);
	// Seulement hors de la fenêtre des ombres précalculées.
	vec2 su = (foot.xz - shadow_rect.xy) / max(shadow_rect.z, 1.0);
	float inside = smoothstep(0.0, 0.08, min(min(su.x, su.y), min(1.0 - su.x, 1.0 - su.y)));
	float light = clamp(length(sun_glint) * 0.8, 0.0, 1.0);
	k = (1.0 - inside) * light * lod_fade;
	v_far = far_amount(MODEL_MATRIX, INV_VIEW_MATRIX);
	v_far_seed = far_seed(MODEL_MATRIX);
	if (k <= 0.001 || v_far >= 1.0) {
		w = foot;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

void fragment() {
	float m = smoothstep(0.3, 0.75, texture(albedo_tex, img_uv).a) * k * (1.0 - v_far);
	// Au loin, la brume blanchit le sol : l'ombre aussi (le mélange ignore la brume).
	float d = length(VERTEX);
	m *= 1.0 - 0.5 * smoothstep(150.0, 450.0, d);
	vec3 tint = mix(shade, vec3(0.55, 0.25, 0.95), lod_debug);
	ALBEDO = mix(vec3(1.0), tint, m);
}
