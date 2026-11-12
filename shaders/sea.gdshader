// Mer réaliste et légère (pensée pour iPhone et le web, rendu Compatibility) :
// - opaque, mais on « voit » le fond : le sable du fond est assombri et teinté par l'eau
//   selon le trajet de la lumière (absorption de Beer-Lambert, le rouge s'éteint d'abord :
//   turquoise sur le sable, bleu profond au large), avec des caustiques qui dansent ;
// - surface lisse : houle (les 4 vagues de waves.gd, mêmes que la flottaison), rides fines
//   (carte de normales qui défile, deux échelles), vagues simulées autour de la voiture ;
// - reflets du ciel et éclat du soleil donnés par le moteur (eau très lisse, Fresnel) ;
// - écume déchirée au bord et sur le sillage.
// Deux couches : grille fine (1,6 m) qui suit la voiture, mer plate et grossière au-delà
// qui ne se dessine pas sous la grille.
shader_type spatial;
render_mode cull_back;

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D ripple_tex : filter_linear_mipmap, repeat_enable;
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float sea_level = 10.0;
// Fond (sable mouillé) et eau : la couleur de l'eau profonde est celle de la lumière
// diffusée ; absorption par mètre pour le rouge, le vert, le bleu.
uniform vec3 bed_color : source_color = vec3(0.66, 0.53, 0.38);
uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.24);
uniform vec3 absorption = vec3(0.55, 0.11, 0.08);
uniform vec3 foam_color : source_color = vec3(0.95, 0.96, 0.94);
uniform float wave_height = 0.25;
uniform float ripple_strength = 0.35;
uniform float now = 0.0;
uniform bool is_near = false;
uniform vec4 near_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform vec4 hole_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform sampler2D sim_tex : filter_nearest, repeat_disable;
uniform vec4 sim_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform int sim_size = 128;
uniform float sim_range = 1.0;

varying vec3 wpos;
varying float relief;

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

// Houle (mêmes valeurs que waves.gd) : hauteur, pente x, pente z.
vec3 swell(vec2 p, float t) {
	vec2 dirs[4] = vec2[](vec2(-1.0, 0.15), vec2(-0.8, -0.55), vec2(-0.95, 0.35), vec2(-0.4, 0.9));
	float lens[4] = float[](38.0, 21.0, 11.0, 6.5);
	float amps[4] = float[](1.0, 0.5, 0.25, 0.12);
	vec3 r = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float k = 6.28318 / lens[i];
		float ph = k * (dot(d, p) - sqrt(9.8 / k) * t);
		float a = amps[i] * wave_height;
		r.x += a * sin(ph);
		r.yz += a * k * cos(ph) * d;
	}
	return r;
}

float sim_cell(ivec2 q) {
	q = clamp(q, ivec2(0), ivec2(sim_size - 1));
	vec2 v = texelFetch(sim_tex, q, 0).rg;
	return ((v.x * 255.0 * 256.0 + v.y * 255.0) / 65535.0 * 2.0 - 1.0) * sim_range;
}

float sim(vec2 p) {
	vec2 g = (p - sim_rect.xy) / sim_rect.zw * float(sim_size) - 0.5;
	if (sim_rect.z <= 0.0 || any(lessThan(g, vec2(0.0))) || any(greaterThan(g, vec2(float(sim_size) - 1.0)))) {
		return 0.0;
	}
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	return mix(mix(sim_cell(i), sim_cell(i + ivec2(1, 0)), f.x), mix(sim_cell(i + ivec2(0, 1)), sim_cell(i + ivec2(1, 1)), f.x), f.y);
}

bool inside(vec2 p, vec4 r) {
	return r.z > 0.0 && all(greaterThan(p, r.xy)) && all(lessThan(p, r.xy + r.zw));
}

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

// Caustiques : réseau de lignes claires qui ondule sur le fond.
float caustics(vec2 p, float t) {
	vec2 q = p * 0.9;
	float a = sin(q.x + sin(q.y * 1.3 + t * 0.9)) + sin(q.y * 1.1 + sin(q.x * 0.8 - t * 0.7));
	float b = sin(q.x * 1.7 - t * 0.6 + sin(q.y * 0.6)) + sin(q.y * 1.9 + t * 0.5 + sin(q.x * 1.2));
	return pow(clamp(1.0 - abs(a) * 0.55, 0.0, 1.0), 5.0) + pow(clamp(1.0 - abs(b) * 0.6, 0.0, 1.0), 6.0) * 0.6;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	relief = 0.0;
	if (is_near) {
		// Houle seulement au large (près du bord la surface reste à plat : le rivage suit le
		// sable), éteinte sur le bord de la grille, où commence la mer plate.
		vec2 q = (w.xz - near_rect.xy) / near_rect.zw;
		float edge = smoothstep(0.0, 0.2, min(min(q.x, 1.0 - q.x), min(q.y, 1.0 - q.y)));
		relief = smoothstep(3.0, 7.0, water_depth(w.xz)) * edge;
		VERTEX.y += swell(w.xz, now).x * relief + sim(w.xz);
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
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = length(cam - wpos);

	// Normale : houle + vagues simulées + rides (deux échelles qui défilent, atténuées au
	// loin pour ne pas scintiller ; plus calmes en eau très peu profonde).
	vec2 slope = vec2(0.0);
	if (is_near) {
		slope += swell(p, t).yz * relief;
		if (sim_rect.z > 0.0) {
			float e = sim_rect.z / float(sim_size);
			slope += vec2(sim(p + vec2(e, 0.0)) - sim(p - vec2(e, 0.0)), sim(p + vec2(0.0, e)) - sim(p - vec2(0.0, e))) / (2.0 * e);
		}
	}
	vec2 r1 = texture(ripple_tex, p / 7.0 + vec2(t * 0.035, t * 0.02)).rg * 2.0 - 1.0;
	vec2 r2 = texture(ripple_tex, p / 19.0 - vec2(t * 0.012, -t * 0.025)).rg * 2.0 - 1.0;
	float calm = smoothstep(0.0, 0.6, d) / (1.0 + dist / 80.0);
	slope += (r1 * 0.6 + r2) * ripple_strength * calm;
	vec3 nw = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// Ce qu'on voit à travers l'eau : le fond, sur un trajet d'autant plus long que l'on
	// regarde à l'oblique, légèrement déplacé par les rides (réfraction).
	vec3 v = normalize(cam - wpos);
	float path = d / max(v.y, 0.2) * 2.0;
	vec2 bed_p = p + slope * d * 0.6;
	float c = caustics(bed_p, t) * exp(-d * 0.7);
	vec3 bed = bed_color * (0.8 + 0.4 * c);
	vec3 keep = exp(-absorption * path);
	vec3 water = bed * keep + deep_color * (1.0 - keep);

	// Écume : liseré qui monte et redescend sur le sable, bandes de vagues qui se brisent,
	// sillage de la voiture ; déchirée par du bruit.
	float lace = vnoise(p * 1.3 + vec2(t * 0.4, 0.0)) * 0.6 + vnoise(p * 3.1 - vec2(0.0, t * 0.3)) * 0.4;
	// Liseré : quelques centimètres d'eau seulement, qui avancent et reculent.
	float swash = 0.025 + 0.025 * sin(t * 0.9 + p.y * 0.05);
	float foam = smoothstep(swash + 0.03, swash, d) * smoothstep(0.0, 0.01, d);
	// Vagues qui se brisent : lignes ondulées, plus faibles, découpées en paquets.
	float wave_phase = d * 0.55 + t * 0.12 + vnoise(p * 0.02) * 0.6 + vnoise(p * 0.15) * 0.08;
	float crest = smoothstep(0.93, 0.975, fract(wave_phase)) * (1.0 - smoothstep(0.975, 1.0, fract(wave_phase)));
	foam = max(foam, crest * 0.75 * smoothstep(0.25, 0.6, vnoise(p * 0.35 + t * 0.05)) * clamp(1.0 - d / 4.0, 0.0, 1.0) * clamp(d / 0.3, 0.0, 1.0));
	if (is_near && sim_rect.z > 0.0) {
		foam = max(foam, smoothstep(0.05, 0.18, sim(p)));
	}
	foam = smoothstep(0.35, 0.75, foam * (0.55 + lace * 0.9));

	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.03, 0.8, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
