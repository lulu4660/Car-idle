// Simulation de la surface de l'eau autour de la voiture : équation des ondes en eau peu
// profonde sur une grille (une case = CELL m), un pas par image, calculée par la carte
// graphique dans un SubViewport (scripts/balade/water_sim.gd). Les vagues partent de la
// caisse et des roues qui poussent l'eau, ralentissent et se cassent sur le sable (vitesse
// √(g·profondeur)), se reflètent et s'amortissent.
// Chaque case garde sa hauteur et celle de l'image d'avant, codées sur 16 bits dans RGBA8
// (R,G = hauteur ; B,A = hauteur précédente), lisible partout (WebGL 2 compris).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D state : filter_nearest, repeat_disable;
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform int size = 256;
uniform float cell = 0.25;
uniform vec2 origin = vec2(0.0);      // coin de la zone (x, z) en m
uniform ivec2 shift = ivec2(0);       // décalage de la zone depuis l'image d'avant (cases)
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float sea_level = 10.0;
uniform float dt = 0.016666;
uniform float range = 1.0;            // hauteur codée : ±range m
// Caisse : centre (x, z), axe avant (x, z), demi-largeur, demi-longueur.
uniform vec4 hull = vec4(0.0);
uniform vec4 hull_axis = vec4(0.0, 1.0, 0.9, 2.0);
uniform float hull_dip = 0.0;         // enfoncement de la caisse sous la surface (m)
// Roues dans l'eau : (x, z, rayon, enfoncement).
uniform vec4 stirs[4];

float dec(vec2 v) {
	return ((v.x * 255.0 * 256.0 + v.y * 255.0) / 65535.0 * 2.0 - 1.0) * range;
}

vec2 enc(float h) {
	float x = clamp(h / range * 0.5 + 0.5, 0.0, 1.0) * 65535.0;
	float hi = floor(x / 256.0);
	return vec2(hi, floor(x - hi * 256.0)) / 255.0;
}

vec4 cell_at(ivec2 q) {
	q += shift;
	if (q.x < 0 || q.y < 0 || q.x >= size || q.y >= size) {
		return vec4(enc(0.0), enc(0.0));
	}
	return texelFetch(state, q, 0);
}

float ground(vec2 p) {
	vec2 g = clamp(p + vec2(world_size * 0.5), vec2(0.0), vec2(float(res) - 1.001));
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	float h00 = texelFetch(height_tex, i, 0).r;
	float h10 = texelFetch(height_tex, i + ivec2(1, 0), 0).r;
	float h01 = texelFetch(height_tex, i + ivec2(0, 1), 0).r;
	float h11 = texelFetch(height_tex, i + ivec2(1, 1), 0).r;
	return mix(mix(h00, h10, f.x), mix(h01, h11, f.x), f.y);
}

void fragment() {
	ivec2 q = ivec2(FRAGCOORD.xy);
	vec2 p = origin + (vec2(q) + 0.5) * cell;
	float depth = sea_level - ground(p);
	vec4 c = cell_at(q);
	float h = dec(c.rg);
	float hp = dec(c.ba);
	float hn = 0.0;
	if (depth > 0.02) {
		float l = dec(cell_at(q + ivec2(-1, 0)).rg);
		float r = dec(cell_at(q + ivec2(1, 0)).rg);
		float d = dec(cell_at(q + ivec2(0, -1)).rg);
		float u = dec(cell_at(q + ivec2(0, 1)).rg);
		float speed = min(sqrt(9.8 * max(depth, 0.02)), 5.0);
		float k = speed * dt / cell;
		// Marge de stabilité (limite du schéma : 0,5) même quand l'image ralentit.
		k = min(k * k, 0.2);
		hn = (2.0 * h - hp + k * (l + r + d + u - 4.0 * h));
		// Viscosité légère : gomme le bruit à l'échelle d'une case (damier) sans freiner les vagues.
		hn = mix(hn, (l + r + d + u) * 0.25, 0.025);
		// Frottement (plus fort en eau très peu profonde) et bords de zone absorbants.
		float edge = min(min(float(q.x), float(size - 1 - q.x)), min(float(q.y), float(size - 1 - q.y)));
		float damp = 0.996 - 0.02 * smoothstep(0.6, 0.05, depth) - 0.06 * smoothstep(12.0, 0.0, edge);
		hn *= damp;
		// La caisse pousse l'eau : sous elle, la surface est enfoncée de la profondeur de la
		// caisse ; l'eau chassée part en vagues tout autour (sillage, vague d'étrave).
		vec2 rel = p - hull.xy;
		vec2 fwd = hull_axis.xy;
		vec2 lc = vec2(dot(rel, vec2(fwd.y, -fwd.x)), dot(rel, fwd));
		vec2 o = abs(lc) - hull_axis.zw;
		// Bords arrondis (coins de caisse) et doux, sinon l'eau poussée part en petites rides
		// à l'échelle de la grille.
		float sd = length(max(o + 0.5, 0.0)) + min(max(o.x + 0.5, o.y + 0.5), 0.0) - 0.5;
		float inside = 1.0 - smoothstep(-0.5, 0.6, sd);
		if (hull_dip > 0.0 && inside > 0.0) {
			hn = mix(hn, -min(min(hull_dip, depth), 0.45) * 0.8, inside * 0.2);
		}
		for (int i = 0; i < 4; i++) {
			vec4 s = stirs[i];
			if (s.w > 0.0) {
				float w = 1.0 - smoothstep(s.z * 0.5, s.z, distance(p, s.xy));
				hn = mix(hn, -min(min(s.w, depth), 0.3) * 0.5, w * 0.15);
			}
		}
		hn = clamp(hn, -range * 0.98, range * 0.98);
	}
	COLOR = vec4(enc(hn), enc(h));
}
