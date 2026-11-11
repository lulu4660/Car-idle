// Terrain de la balade, style low poly : la grille est déformée par la carte des hauteurs
// (1 texel = 1 m, lue sans filtrage), les sols mélangés par la carte des sols sont en
// couleurs unies avec de légères variations, et le relief est légèrement facetté.
// Aucune texture photo : très léger pour l'iPhone.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float skirt = 2.0;
uniform float sea_level = 10.0;

// Ornières : autour de la voiture, une pièce de terrain fine (20 cm entre sommets) se creuse
// sous les roues. rut_tex : R = profondeur (× rut_depth), G = bourrelet (× rut_berm), sur la
// zone rut_rect (x, z, largeur, profondeur en m). Le terrain normal s'efface sous la pièce.
uniform bool is_patch = false;
// iPhone et web : une seule échelle de texture par sol (deux fois moins de lectures).
uniform bool low_quality = false; // gardé pour compatibilité, plus utilisé
uniform sampler2D rut_tex : filter_linear, repeat_disable;
uniform vec4 rut_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float rut_depth = 0.3;
uniform float rut_berm = 0.12;

// Couleurs unies du style low poly, par sol.
uniform vec3 sand_light : source_color = vec3(0.88, 0.72, 0.50);
uniform vec3 sand_dark : source_color = vec3(0.81, 0.63, 0.43);
uniform vec3 dirt_light : source_color = vec3(0.64, 0.46, 0.31);
uniform vec3 dirt_dark : source_color = vec3(0.54, 0.38, 0.26);
uniform vec3 asphalt_color : source_color = vec3(0.30, 0.30, 0.33);
uniform vec3 wet_color : source_color = vec3(0.70, 0.55, 0.39);
uniform float facet_strength = 0.55;

varying vec3 wpos;
varying float rut_k;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}


float hgt(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(res - 1));
	return texelFetch(height_tex, p, 0).r;
}

// Hauteur interpolée (pour la pièce fine : ses sommets tombent entre les texels).
float hgt_smooth(vec2 p) {
	vec2 g = clamp(p + vec2(world_size * 0.5), vec2(0.0), vec2(float(res) - 1.001));
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	return mix(mix(hgt(i), hgt(i + ivec2(1, 0)), f.x), mix(hgt(i + ivec2(0, 1)), hgt(i + ivec2(1, 1)), f.x), f.y);
}

// Creux (négatif) ou bourrelet (positif) laissé par les roues, en mètres.
float rut(vec2 p) {
	vec2 uv = (p - rut_rect.xy) / rut_rect.zw;
	vec4 r = textureLod(rut_tex, uv, 0.0);
	return r.g * rut_berm - r.r * rut_depth;
}

float patch_height(vec2 p) {
	return hgt_smooth(p) + rut(p);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rut_k = 0.0;
	if (is_patch) {
		float e = 0.2;
		float h0 = patch_height(w.xz);
		float hx = patch_height(w.xz + vec2(-e, 0.0)) - patch_height(w.xz + vec2(e, 0.0));
		float hz = patch_height(w.xz + vec2(0.0, -e)) - patch_height(w.xz + vec2(0.0, e));
		vec3 pn = normalize(vec3(hx, 2.0 * e, hz));
		VERTEX.y = h0;
		NORMAL = pn;
		TANGENT = normalize(cross(vec3(0.0, 0.0, 1.0), pn));
		BINORMAL = normalize(cross(pn, TANGENT));
		wpos = vec3(w.x, h0, w.z);
		rut_k = clamp(-rut(w.xz) / 0.08, 0.0, 1.0);
	} else {
		ivec2 g = ivec2(round(w.xz + vec2(world_size * 0.5)));
		float h = hgt(g);
		float hl = hgt(g + ivec2(-1, 0));
		float hr = hgt(g + ivec2(1, 0));
		float hd = hgt(g + ivec2(0, -1));
		float hu = hgt(g + ivec2(0, 1));
		vec3 n = normalize(vec3(hl - hr, 2.0, hd - hu));
		// Jupe : les sommets du bord descendent un peu et cachent les fentes entre niveaux de détail.
		VERTEX.y = h - UV2.x * skirt;
		NORMAL = n;
		TANGENT = normalize(cross(vec3(0.0, 0.0, 1.0), n));
		BINORMAL = normalize(cross(n, TANGENT));
		wpos = vec3(w.x, VERTEX.y, w.z);
	}
}

void fragment() {
	// Sous la pièce fine des ornières, c'est elle qui dessine le sol.
	if (!is_patch && rut_rect.z > 0.0) {
		vec2 inner = (wpos.xz - rut_rect.xy - vec2(0.3)) / (rut_rect.zw - vec2(0.6));
		if (all(greaterThan(inner, vec2(0.0))) && all(lessThan(inner, vec2(1.0)))) {
			discard;
		}
	}
	vec4 w = texture(splat_tex, (wpos.xz + vec2(world_size * 0.5)) / world_size);
	w /= max(w.r + w.g + w.b + w.a, 0.001);
	// Style low poly : couleurs unies par sol, légères variations à grande échelle.
	float macro = vnoise(wpos.xz / 60.0) * 0.6 + vnoise(wpos.xz / 17.0) * 0.4;
	vec3 sand = mix(sand_dark, sand_light, smoothstep(0.2, 0.85, macro));
	vec3 dirt = mix(dirt_dark, dirt_light, macro);
	vec3 asphalt = asphalt_color * (0.92 + 0.08 * macro);
	vec3 c = asphalt * w.r + dirt * w.g + sand * w.b + wet_color * w.a;
	// Sable mouillé au bord de l'eau : plus sombre et un peu luisant.
	float wet_band = smoothstep(sea_level + 0.6, sea_level + 0.05, wpos.y);
	c *= mix(1.0, 0.72, wet_band);
	// Fond des ornières : sable tassé, un peu plus sombre.
	c *= mix(1.0, 0.86, rut_k);
	ALBEDO = c;
	// Facettes : la normale du triangle se mêle à la normale lissée (relief taillé au couteau).
	vec3 facet = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	// Le sens des dérivées change selon le rendu (web ou PC) : on garde la face tournée comme le sol.
	facet *= sign(dot(facet, NORMAL) + 1e-4);
	NORMAL = normalize(mix(NORMAL, facet, facet_strength));
	ROUGHNESS = mix(0.95, 0.5, wet_band);
	SPECULAR = 0.25;
}
