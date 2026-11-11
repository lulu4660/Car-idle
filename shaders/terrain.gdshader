// Terrain de la balade : la grille est déformée par la carte des hauteurs (1 texel = 1 m,
// lue sans filtrage), les sols sont mélangés par la carte des sols, avec des textures
// photographiées (couleur + brillance dans l'alpha, normales). Une seconde échelle de
// texture, plus grande, casse la répétition au loin.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform float world_size = 1024.0;
uniform int res = 1025;
uniform float skirt = 2.0;

uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Taille d'une répétition (m) : bitume, terre, sable, sable mouillé.
uniform vec4 tile = vec4(4.0, 3.5, 4.0, 3.5);
uniform vec4 max_smoothness = vec4(0.25, 0.08, 0.05, 0.35);
uniform vec3 sand_tint : source_color = vec3(1.22, 1.02, 0.78);
// Rides du vent sur le sable : hauteur et longueur d'onde (m).
uniform float ripple_strength = 0.22;
uniform float ripple_length = 0.55;

varying vec3 wpos;

float hgt(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(res - 1));
	return texelFetch(height_tex, p, 0).r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

vec4 layer(sampler2D alb, sampler2D nor, float size, vec2 p, float far, out vec3 nm) {
	vec4 a = texture(alb, p / size);
	vec4 b = texture(alb, p / (size * 5.3) + vec2(0.37, 0.71));
	vec3 n1 = texture(nor, p / size).rgb;
	vec3 n2 = texture(nor, p / (size * 5.3) + vec2(0.37, 0.71)).rgb;
	nm = mix(n1, n2, far * 0.6);
	return mix(a, mix(a, b, 0.5), far);
}

void fragment() {
	vec4 w = texture(splat_tex, (wpos.xz + vec2(world_size * 0.5)) / world_size);
	w /= max(w.r + w.g + w.b + w.a, 0.001);
	float dist = length(VERTEX);
	float far = smoothstep(15.0, 90.0, dist);
	vec3 n0, n1, n2, n3;
	vec4 c0 = layer(asphalt_albedo, asphalt_normal, tile.x, wpos.xz, far, n0);
	vec4 c1 = layer(dirt_albedo, dirt_normal, tile.y, wpos.xz, far, n1);
	vec4 c2 = layer(sand_albedo, sand_normal, tile.z, wpos.xz, far, n2);
	vec4 c3 = layer(wet_albedo, wet_normal, tile.w, wpos.xz, far, n3);
	// Sable de dune : grain fin, moins de taches sombres que la photo d'origine.
	c2.rgb = mix(vec3(0.52, 0.43, 0.31), c2.rgb, 0.6) * sand_tint;
	// Rides du vent, perpendiculaires au vent d'ouest, ondulées ; elles s'effacent au loin.
	vec2 q = wpos.xz;
	float warp = sin(q.y * 0.21 + sin(q.x * 0.13) * 1.7) * 0.9 + sin(q.y * 0.53 + q.x * 0.07) * 0.35 + sin(q.y * 1.7 + q.x * 0.3) * 0.12;
	float ph = (q.x + warp) / ripple_length * 6.28318;
	float ripple = cos(ph) + 0.35 * cos(ph * 2.0 + 0.6);
	float near_k = 1.0 - smoothstep(6.0, 45.0, dist);
	vec3 rip = vec3(0.5 - ripple * ripple_strength * near_k * 0.5, 0.5, 1.0);
	n2 = mix(n2, rip, 0.55 * near_k);
	vec4 c = c0 * w.r + c1 * w.g + c2 * w.b + c3 * w.a;
	ALBEDO = c.rgb;
	NORMAL_MAP = n0 * w.r + n1 * w.g + n2 * w.b + n3 * w.a;
	// Au loin, reliefs fins atténués (pas de scintillement).
	NORMAL_MAP_DEPTH = mix(0.8, 0.3, far);
	float smooth_max = dot(w, max_smoothness);
	ROUGHNESS = 1.0 - clamp(c.a, 0.0, 1.0) * smooth_max * 4.0;
	SPECULAR = 0.3;
}
