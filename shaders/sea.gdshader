// Mer low poly, dans le style des voitures : grandes facettes à plat, couleurs unies selon
// la profondeur, écume en bandes. Opaque (moins cher qu'une eau transparente, surtout sur le
// web) : le sable du bord est imité par la couleur.
// Deux couches : une grille fine (1,6 m) qui suit la voiture, avec la houle en relief (les
// mêmes vagues que la flottaison, waves.gd) et les vagues simulées autour de la voiture
// (water_sim.gd) ; au-delà, une mer plate et grossière qui ne se dessine pas sous la grille.
shader_type spatial;
render_mode cull_back;

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float sea_level = 10.0;
uniform vec3 shore_color : source_color = vec3(0.30, 0.56, 0.50);
uniform vec3 shallow_color : source_color = vec3(0.03, 0.34, 0.40);
uniform vec3 deep_color : source_color = vec3(0.01, 0.13, 0.23);
uniform vec3 foam_color : source_color = vec3(0.93, 0.95, 0.92);
uniform float wave_height = 0.25;
uniform float now = 0.0;
// Grille fine : sa zone (relief qui s'éteint sur les bords) ; mer grossière : trou à sa place.
uniform bool is_near = false;
uniform vec4 near_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform vec4 hole_rect = vec4(0.0, 0.0, -1.0, -1.0);
// Vagues simulées : hauteurs codées sur 16 bits (R, G), zone sim_rect (x, z, l, p) en m.
uniform sampler2D sim_tex : filter_nearest, repeat_disable;
uniform vec4 sim_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform int sim_size = 128;
uniform float sim_range = 1.0;

varying vec3 wpos;
varying float depth;

float hgt(ivec2 q) {
	q = clamp(q, ivec2(0), ivec2(res - 1));
	return texelFetch(height_tex, q, 0).r;
}

float water_depth(vec2 p) {
	vec2 g = clamp(p + vec2(world_size * 0.5), vec2(0.0), vec2(float(res) - 1.001));
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	float h = mix(mix(hgt(i), hgt(i + ivec2(1, 0)), f.x), mix(hgt(i + ivec2(0, 1)), hgt(i + ivec2(1, 1)), f.x), f.y);
	return clamp(sea_level - h, 0.0, 40.0);
}

// Houle (mêmes valeurs que waves.gd) : quatre vagues venues du large.
float swell(vec2 p, float t) {
	vec2 dirs[4] = vec2[](vec2(-1.0, 0.15), vec2(-0.8, -0.55), vec2(-0.95, 0.35), vec2(-0.4, 0.9));
	float lens[4] = float[](38.0, 21.0, 11.0, 6.5);
	float amps[4] = float[](1.0, 0.5, 0.25, 0.12);
	float h = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float k = 6.28318 / lens[i];
		h += amps[i] * wave_height * sin(k * (dot(d, p) - sqrt(9.8 / k) * t));
	}
	return h;
}

float sim_cell(ivec2 q) {
	q = clamp(q, ivec2(0), ivec2(sim_size - 1));
	vec2 v = texelFetch(sim_tex, q, 0).rg;
	return ((v.x * 255.0 * 256.0 + v.y * 255.0) / 65535.0 * 2.0 - 1.0) * sim_range;
}

float sim(vec2 p) {
	if (sim_rect.z <= 0.0) {
		return 0.0;
	}
	vec2 g = (p - sim_rect.xy) / sim_rect.zw * float(sim_size) - 0.5;
	if (any(lessThan(g, vec2(0.0))) || any(greaterThan(g, vec2(float(sim_size) - 1.0)))) {
		return 0.0;
	}
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	return mix(mix(sim_cell(i), sim_cell(i + ivec2(1, 0)), f.x), mix(sim_cell(i + ivec2(0, 1)), sim_cell(i + ivec2(1, 1)), f.x), f.y);
}

bool inside(vec2 p, vec4 r) {
	return r.z > 0.0 && all(greaterThan(p, r.xy)) && all(lessThan(p, r.xy + r.zw));
}

// Hasard sans sinus (moins cher et stable sur les GPU mobiles).
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = water_depth(w.xz);
	if (is_near) {
		// Relief seulement au large (près du bord la surface reste à plat : le rivage suit
		// le sable) et éteint sur le bord de la grille, où commence la mer plate.
		vec2 q = (w.xz - near_rect.xy) / near_rect.zw;
		float edge = smoothstep(0.0, 0.2, min(min(q.x, 1.0 - q.x), min(q.y, 1.0 - q.y)));
		VERTEX.y += swell(w.xz, now) * smoothstep(3.0, 7.0, depth) * edge;
		VERTEX.y += sim(w.xz) * clamp(depth / 0.3, 0.0, 1.0);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	if (inside(p, hole_rect)) {
		discard;
	}
	float t = now;
	float d = water_depth(p);
	// Facettes : la normale vient du triangle lui-même (comme les voitures low poly).
	vec3 nw = vec3(0.0, 1.0, 0.0);
	if (is_near) {
		nw = normalize(cross(dFdy(wpos), dFdx(wpos)));
		if (nw.y < 0.0) {
			nw = -nw;
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// Couleurs unies par profondeur : bord clair (on croit voir le sable), turquoise, bleu-vert.
	vec3 water = mix(shore_color, shallow_color, smoothstep(0.0, 0.9, d));
	water = mix(water, deep_color, smoothstep(1.5, 9.0, d));
	// Bord : liseré d'écume qui monte et redescend.
	float swash = 0.08 + 0.06 * sin(t * 0.9 + p.y * 0.05);
	float foam = smoothstep(swash * 0.5 + 0.03, swash * 0.5, d);
	// Vagues qui déferlent : bandes d'écume qui avancent vers la plage.
	float wave_phase = d * 0.55 + t * 0.12 + vnoise(p * 0.02) * 0.6;
	float crest = smoothstep(0.93, 0.97, fract(wave_phase)) * (1.0 - smoothstep(0.985, 1.0, fract(wave_phase)));
	float breakup = step(0.45, vnoise(p * vec2(0.05, 0.3) + vec2(0.0, t * 0.1)));
	foam = max(foam, crest * breakup * clamp(1.0 - d / 4.5, 0.0, 1.0) * clamp(d / 0.4, 0.0, 1.0));
	// Écume du sillage : là où la voiture a soulevé l'eau.
	if (is_near) {
		float h = sim(p);
		foam = max(foam, smoothstep(0.06, 0.16, h) * step(0.35, vnoise(p * 1.7 + t)));
	}
	ALBEDO = mix(water, foam_color, step(0.5, foam));
	ROUGHNESS = mix(0.35, 0.85, step(0.5, foam));
	SPECULAR = 0.2;
	METALLIC = 0.0;
}
