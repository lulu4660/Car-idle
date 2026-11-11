// Mer : houle qui arrive du large et s'écrase sur la plage, rides fines, eau claire et
// turquoise sur le sable près du bord, foncée au large, écume au bord. Reflets du ciel et
// du soleil donnés par le moteur (eau très lisse).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Profondeur lue dans la même carte des hauteurs que le terrain (1 texel = 1 m), interpolée
// à la main : le rivage suit exactement le sable.
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float sea_level = 10.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.55, 0.52);
uniform vec3 foam_color : source_color = vec3(0.86, 0.88, 0.86);
uniform float wave_height = 0.25;
// Horloge du jeu (waves.gd), la même que celle de la physique de la flottaison.
uniform float now = 0.0;

varying vec3 wpos;

// Sillage de la voiture (waves.gd) : ondes circulaires (x, z, départ, amplitude).
uniform vec4 wakes[32];
// Pièce fine autour de la voiture (0,4 m entre sommets) : elle seule porte le relief du
// sillage ; la mer normale ne se dessine pas dessous.
uniform bool is_patch = false;
uniform vec4 patch_rect = vec4(0.0, 0.0, -1.0, -1.0);
const float WAKE_SPEED = 3.2;
const float WAKE_LEN = 2.4;
const float WAKE_WIDTH = 2.2;
const float WAKE_DECAY = 0.55;
const float WAKE_LIFE = 6.0;

// Sillage : hauteur, pente x, pente z, écume (crêtes jeunes et hautes).
vec4 wake(vec2 p, float t) {
	vec4 r = vec4(0.0);
	float k = 6.28318 / WAKE_LEN;
	for (int i = 0; i < 32; i++) {
		vec4 w = wakes[i];
		float age = t - w.z;
		if (age <= 0.0 || age > WAKE_LIFE || w.w <= 0.0) {
			continue;
		}
		vec2 dp = p - w.xy;
		float rr = max(length(dp), 0.001);
		float front = WAKE_SPEED * age;
		float u = (rr - front) / WAKE_WIDTH;
		if (abs(u) > 2.5) {
			continue;
		}
		float env = w.w * exp(-age * WAKE_DECAY) * exp(-u * u) / sqrt(1.0 + rr * 0.4);
		float ph = k * (rr - front);
		r.x += env * cos(ph);
		// Pente : dérivée selon r (l'enveloppe varie peu devant l'onde), le long de dp.
		float dh = -env * k * sin(ph) - env * cos(ph) * 2.0 * u / WAKE_WIDTH;
		r.yz += dh * dp / rr;
		r.w += env * max(cos(ph), 0.0) * exp(-age * 1.2);
	}
	return r;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
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

// Houle : hauteur, pente x, pente z.
vec3 swell(vec2 p, float t) {
	vec3 r = vec3(0.0);
	vec2 dirs[4] = vec2[](vec2(-1.0, 0.15), vec2(-0.8, -0.55), vec2(-0.95, 0.35), vec2(-0.4, 0.9));
	float lens[4] = float[](38.0, 21.0, 11.0, 6.5);
	float amps[4] = float[](1.0, 0.5, 0.25, 0.12);
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float k = 6.28318 / lens[i];
		float c = sqrt(9.8 / k);
		float ph = k * (dot(d, p) - c * t);
		float a = amps[i] * wave_height;
		r.x += a * sin(ph);
		r.yz += a * k * cos(ph) * d;
	}
	return r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = water_depth(w.xz);
	// Houle en relief seulement au large : près du bord, la surface reste plane et le rivage
	// suit exactement le sable (pas de marches dues au maillage).
	VERTEX.y += swell(w.xz, now).x * smoothstep(3.0, 7.0, depth);
	if (is_patch) {
		vec2 q = (w.xz - patch_rect.xy) / patch_rect.zw;
		float edge = smoothstep(0.0, 0.1, min(min(q.x, 1.0 - q.x), min(q.y, 1.0 - q.y)));
		VERTEX.y += wake(w.xz, now).x * clamp(depth / 0.3, 0.0, 1.0) * edge;
	}
	wpos = w;
}

void fragment() {
	float t = now;
	vec2 p = wpos.xz;
	bool inside = all(greaterThan(p, patch_rect.xy)) && all(lessThan(p, patch_rect.xy + patch_rect.zw));
	if (inside != is_patch) {
		discard;
	}
	float d = water_depth(p);
	vec3 s = swell(p, t);
	vec2 ripple = vec2(sin(p.x * 1.7 + t * 2.1 + sin(p.y * 0.9)), sin(p.y * 1.9 - t * 1.7 + sin(p.x * 1.1))) * 0.06;
	ripple += vec2(sin(p.x * 4.3 - t * 3.3 + p.y * 2.0), sin(p.y * 3.7 + t * 2.9 - p.x * 1.6)) * 0.03;
	vec4 wk = is_patch ? wake(p, t) : vec4(0.0);
	float wet = clamp(d / 0.3, 0.0, 1.0);
	vec3 nw = normalize(vec3(-(s.y + ripple.x + wk.y * wet), 1.0, -(s.z + ripple.y + wk.z * wet)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	vec3 water = mix(shallow_color, deep_color, clamp(d / 6.0, 0.0, 1.0));
	// Bord : un liseré d'écume fin (quelques centimètres d'eau) qui monte et redescend.
	float swash = 0.08 + 0.06 * sin(t * 0.9 + p.y * 0.05);
	float shore = smoothstep(swash + 0.12, swash, d) * smoothstep(0.0, 0.03, d);
	float lace = smoothstep(0.35, 0.75, vnoise(p * vec2(0.6, 0.25) + vec2(t * 0.3, 0.0)));
	float foam = shore * (0.6 + 0.4 * lace);

	// Écume au large : traînées et paquets blancs qui dérivent avec la houle.
	vec2 fp = p * vec2(0.09, 0.05) + vec2(t * 0.03, 0.0);
	float patches = vnoise(fp) * 0.6 + vnoise(fp * 3.1 + 5.0) * 0.4;
	float specks = vnoise(p * 0.9 + vec2(t * 0.2, 0.0));
	float sea_foam = smoothstep(0.70, 0.82, patches) * smoothstep(0.45, 0.8, specks) * clamp(d / 1.5, 0.0, 1.0);
	foam = max(foam, sea_foam * 0.6);
	// Vagues qui déferlent : des lignes d'écume avancent vers la plage et se brisent au bord.
	float wave_phase = d * 0.55 + t * 0.12 + vnoise(p * 0.02) * 0.6;
	float crest = smoothstep(0.94, 0.985, fract(wave_phase)) * (1.0 - smoothstep(0.985, 1.0, fract(wave_phase)));
	float breakup = smoothstep(0.3, 0.7, vnoise(p * vec2(0.05, 0.3) + vec2(0.0, t * 0.1)));
	foam = max(foam, crest * breakup * 0.7 * clamp(1.0 - d / 4.5, 0.0, 1.0) * clamp(d / 0.4, 0.0, 1.0));
	// Écume sur les crêtes du sillage, découpée par un bruit fin.
	float wfoam = smoothstep(0.04, 0.16, wk.w * wet) * (0.55 + 0.45 * vnoise(p * 2.3 + t));
	foam = max(foam, wfoam * 0.85);
	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.14, 0.7, foam);
	METALLIC = 0.0;
	SPECULAR = 0.2;
	// Eau claire au bord : on voit le sable dessous sur les premiers mètres.
	ALPHA = clamp(0.08 + d * 0.22 + foam, 0.0, 1.0);
}
