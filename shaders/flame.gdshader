// Retour de flamme : cône (cœur blanc-jaune, bords orange puis rouge, bout qui
// s'effiloche) ou halo doux face à la caméra (`glow`). `power` (0 à 1) est animé par
// exhaust.gd : rien n'est dessiné à 0.
shader_type spatial;
// Mélange normal (et non additif) : la flamme reste visible le jour sur le sable clair ;
// le halo, lui, s'ajoute.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float power = 0.0;
uniform bool glow = false;
uniform float seed = 0.0;

varying float along;

void vertex() {
	if (glow) {
		vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float size = length(MODEL_MATRIX[0].xyz);
		vec3 view_c = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
		view_c.xy += VERTEX.xy * size;
		// Un peu vers la caméra : le halo n'est pas coupé par la carrosserie.
		view_c.z += 0.3;
		POSITION = PROJECTION_MATRIX * vec4(view_c, 1.0);
	} else {
		// Cône le long de -Z (0 à la sortie du pot, 1 au bout) : les flammes ondulent.
		along = clamp(-VERTEX.z, 0.0, 1.0);
		float w = sin(TIME * 61.0 + seed * 7.0 + along * 9.0) * 0.18 + sin(TIME * 37.0 + seed * 3.0) * 0.1;
		VERTEX.xy *= 1.0 + w * along;
		VERTEX.x += sin(TIME * 23.0 + seed) * 0.04 * along;
		// POSITION est écrite pour le halo : il faut alors l'écrire aussi ici.
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	if (power <= 0.001) {
		discard;
	}
	if (glow) {
		float r = length(UV * 2.0 - 1.0);
		float a = pow(clamp(1.0 - r, 0.0, 1.0), 2.0);
		ALBEDO = vec3(1.0, 0.62, 0.25);
		ALPHA = a * power * 0.55;
	} else {
		// Cœur au centre du cône (face vue de profil : NORMAL vers la caméra).
		float facing = abs(dot(NORMAL, VIEW));
		float core = pow(facing, 1.5) * (1.0 - along);
		vec3 hot = vec3(1.0, 0.95, 0.7);
		vec3 mid = vec3(1.0, 0.55, 0.12);
		vec3 tip = vec3(0.85, 0.16, 0.05);
		vec3 c = mix(mid, hot, clamp(core * 1.6, 0.0, 1.0));
		c = mix(c, tip, smoothstep(0.45, 1.0, along));
		float flick = 0.75 + 0.25 * sin(TIME * 90.0 + seed * 11.0 + along * 20.0);
		float fade = (1.0 - smoothstep(0.55, 1.0, along)) * (0.35 + 0.65 * facing);
		ALBEDO = c * 1.25;
		ALPHA = clamp(fade * flick * power * 1.5, 0.0, 1.0);
	}
}
