// Bâtiments Kenney (texture commune) : mats le jour ; la nuit, une partie des fenêtres
// s'allume (couleur chaude), au hasard par étage et par travée.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/night_light.gdshaderinc"
#include "res://shaders/see_through.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 window_light : source_color = vec3(1.0, 0.76, 0.42);

varying vec3 wpos;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (see_fade(wpos, INV_VIEW_MATRIX[3].xyz) > see_bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	if (night > 0.01) {
		// Vitres : les deux bleus de la palette Kenney réservés aux fenêtres (en linéaire).
		float g1 = 1.0 - smoothstep(0.04, 0.1, distance(c, vec3(0.63, 0.80, 1.0)));
		float g2 = 1.0 - smoothstep(0.04, 0.1, distance(c, vec3(0.136, 0.296, 0.69)));
		// (même test en sRGB : selon le rendu, la texture arrive décodée ou non)
		float g3 = 1.0 - smoothstep(0.04, 0.1, distance(c, vec3(0.816, 0.91, 1.0)));
		float g4 = 1.0 - smoothstep(0.04, 0.1, distance(c, vec3(0.404, 0.58, 0.851)));
		float glass = max(max(g1, g2), max(g3, g4));
		float lit = step(0.45, hash3(floor(wpos / vec3(3.0, 3.2, 3.0))));
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		EMISSION = window_light * glass * lit * night * 1.4 + c * head_color * headlight(wpos, nw) * 1.6;
		ALBEDO = mix(c, c * 0.4, glass * night);
	}
}
