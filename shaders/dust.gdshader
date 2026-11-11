// Poussière, sable et éclaboussures, animés entièrement par la carte graphique : chaque
// grain est une instance de MultiMesh. Origine = point d'émission ; 1re colonne de la base =
// vitesse de départ ; INSTANCE_CUSTOM = (moment, durée, taille, graine). Panneau face caméra,
// ralenti par l'air, grossit en vieillissant, éclairé à contre-jour par le soleil.
shader_type spatial;
// Horloge du jeu (secondes), donnée par effects.gd : la même que celle des poses.
uniform float now = 0.0;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.3, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.66);
uniform vec3 ambient : source_color = vec3(0.62, 0.62, 0.66);
uniform float drag = 1.6;
uniform float rise = 0.25;

varying float alpha_k;
varying float back;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float age = now - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.01);
	float k = clamp(age / life, 0.0, 1.0);
	// Position : vitesse amortie par l'air, la poussière monte un peu.
	float travel = (1.0 - exp(-drag * age)) / drag;
	vec3 pos = origin + v0 * travel + vec3(0.0, rise * age * age, 0.0);
	float size = INSTANCE_CUSTOM.z * (0.35 + 1.9 * sqrt(k));
	if (age < 0.0 || age > life) {
		size = 0.0;
	}
	vec3 view_pos = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	view_pos.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	alpha_k = smoothstep(0.0, 0.08, k) * (1.0 - k);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - pos);
	back = pow(clamp(dot(-to_cam, normalize(sun_dir)), 0.0, 1.0), 4.0);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = clamp(1.0 - length(c), 0.0, 1.0);
	float a = r * r;
	ALBEDO = COLOR.rgb * (ambient * 0.9 + sun_color * (0.55 + back * 1.6));
	ALPHA = COLOR.a * a * alpha_k;
}
