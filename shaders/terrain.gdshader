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
// Piste de rallye : distance à l'axe (octet, 0,05 m par unité ; 1 = 12,75 m).
uniform sampler2D road_tex : filter_linear, repeat_disable;
uniform float road_half = 5.0;
uniform vec3 road_color : source_color = vec3(0.50, 0.32, 0.25);
uniform vec4 rut_rect = vec4(0.0, 0.0, 0.0, 0.0);
#include "res://shaders/car_shadow.gdshaderinc"
varying float sun_vis;
uniform float rut_depth = 0.3;
uniform float rut_berm = 0.12;

// Couleurs unies du style low poly, par sol.
uniform vec3 sand_light : source_color = vec3(0.82, 0.62, 0.49);
uniform vec3 sand_dark : source_color = vec3(0.73, 0.53, 0.43);
uniform vec3 dirt_light : source_color = vec3(0.62, 0.42, 0.32);
uniform vec3 dirt_dark : source_color = vec3(0.52, 0.35, 0.27);
uniform vec3 asphalt_color : source_color = vec3(0.30, 0.30, 0.33);
uniform vec3 wet_color : source_color = vec3(0.70, 0.55, 0.39);

varying vec3 wpos;

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


float hgt(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(res - 1));
	return texelFetch(height_tex, p, 0).r;
}

// Hauteur et pente du triangle de la grille (1 m) qui contient p, découpé exactement comme
// le maillage du terrain (diagonale de (1,0) à (0,1)) : la pièce fine des ornières et le
// terrain normal tombent pile au même endroit, sans marche ni différence de lumière.
vec3 tri_height_grad(vec2 p) {
	vec2 g = clamp(p + vec2(world_size * 0.5), vec2(0.0), vec2(float(res) - 1.001));
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	float h00 = hgt(i);
	float h10 = hgt(i + ivec2(1, 0));
	float h01 = hgt(i + ivec2(0, 1));
	float h11 = hgt(i + ivec2(1, 1));
	if (f.x + f.y < 1.0) {
		vec2 grad = vec2(h10 - h00, h01 - h00);
		return vec3(h00 + dot(f, grad), grad);
	}
	vec2 grad = vec2(h11 - h01, h11 - h10);
	return vec3(h11 - dot(vec2(1.0) - f, grad), grad);
}

// Creux (négatif) ou bourrelet (positif) laissé par les roues, en mètres.
float rut(vec2 p) {
	vec2 uv = (p - rut_rect.xy) / rut_rect.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	vec4 r = textureLod(rut_tex, uv, 0.0);
	// Fondu sur les bords de la zone : les vieilles ornières s'effacent doucement.
	float edge = smoothstep(0.0, 0.12, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	return (r.g * rut_berm - r.r * rut_depth) * edge;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (is_patch) {
		float h0 = tri_height_grad(w.xz).x + rut(w.xz);
		VERTEX.y = h0;
		wpos = vec3(w.x, h0, w.z);
	} else {
		ivec2 g = ivec2(round(w.xz + vec2(world_size * 0.5)));
		// Jupe : les sommets du bord descendent un peu et cachent les fentes entre niveaux de détail.
		VERTEX.y = hgt(g) - UV2.x * skirt;
		wpos = vec3(w.x, VERTEX.y, w.z);
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
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
	// Ville : chaussée (avec tirets au milieu des rues) seulement dans les rues ; trottoirs
	// en béton clair dans le centre, pelouses dans la banlieue (même grille que town.gd).
	if (w.r > 0.01) {
		vec2 q = mod(wpos.xz, vec2(60.0));
		bool street = q.x < 16.0 || q.y < 16.0;
		if (street) {
			vec2 mid = abs(q - vec2(8.0));
			float dash = (q.x < 16.0 && mid.x < 0.18 && mod(wpos.z, 6.0) < 3.0) || (q.y < 16.0 && mid.y < 0.18 && mod(wpos.x, 6.0) < 3.0) ? 1.0 : 0.0;
			if (q.x < 16.0 && q.y < 16.0) dash = 0.0;
			asphalt = mix(asphalt, vec3(0.86, 0.80, 0.62), dash);
		} else {
			float curb = min(min(q.x - 16.0, 60.0 - q.x), min(q.y - 16.0, 60.0 - q.y));
			vec3 plot = wpos.x > -240.0 ? mix(vec3(0.42, 0.55, 0.30), vec3(0.47, 0.60, 0.33), macro) : vec3(0.58, 0.56, 0.54) * (0.95 + 0.08 * macro);
			asphalt = curb < 2.2 ? vec3(0.66, 0.64, 0.61) : plot;
		}
	}
	vec3 c = asphalt * w.r + dirt * w.g + sand * w.b + wet_color * w.a;
	// Piste : terre tassée plus sombre, bords usés, deux ornières creusées par les passages.
	float rd = texture(road_tex, (wpos.xz + vec2(world_size * 0.5)) / world_size).r * 12.75;
	float on_road = smoothstep(road_half + 0.6, road_half - 0.8, rd + (vnoise(wpos.xz * 0.7) - 0.5) * 1.2);
	if (on_road > 0.0) {
		vec3 rc = road_color * (0.94 + 0.12 * macro);
		float ruts = smoothstep(0.55, 0.15, abs(rd - 1.1)) + smoothstep(0.35, 0.1, abs(rd - 2.4)) * 0.4;
		rc *= 1.0 - 0.18 * clamp(ruts, 0.0, 1.0);
		c = mix(c, rc, on_road);
	}
	// Sable mouillé au bord de l'eau : plus sombre et un peu luisant.
	float wet_band = smoothstep(sea_level + 0.6, sea_level + 0.05, wpos.y);
	c *= mix(1.0, 0.72, wet_band);
	// Ornières : relief fin et fond tassé un peu plus sombre (pièce fine seulement).
	vec3 tg = tri_height_grad(wpos.xz);
	vec2 grad = tg.yz;
	if (is_patch) {
		float e = 0.05;
		float r0 = rut(wpos.xz);
		grad += vec2(rut(wpos.xz + vec2(e, 0.0)) - rut(wpos.xz - vec2(e, 0.0)), rut(wpos.xz + vec2(0.0, e)) - rut(wpos.xz - vec2(0.0, e))) / (2.0 * e);
		c *= mix(1.0, 0.86, clamp(-r0 / 0.08, 0.0, 1.0));
	}
	ALBEDO = c;
	sun_vis = sun_visibility(wpos, world_size);
	EMISSION = c * lamp_glow(wpos, world_size);
	// Facettes low poly : la normale est celle du triangle de 1 m (calculée, pas dérivée de
	// l'écran : identique sur le terrain, la pièce des ornières et les niveaux de détail).
	vec3 nw = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = mix(0.95, 0.5, wet_band);
	SPECULAR = 0.0;
}


// Éclairage : le soleil est masqué par les ombres (décor précalculé, voiture calculée) ;
// la lumière ambiante (lavande) reste : ombres teintées comme avant, bords lisses.
void light() {
	// Les ombres précalculées ne valent que pour le soleil (ou la lune) ; les phares, non.
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_vis : ATTENUATION);
}
