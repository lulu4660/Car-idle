// Poussière, grains de sable et gouttes d'eau, dessinés par la carte graphique (une instance
// de MultiMesh par particule). Chaque particule suit une trajectoire physique depuis son
// « départ » : vitesse freinée par l'air (traînée), pesanteur propre à son type (la
// poussière flotte et monte un peu, le sable et l'eau retombent et s'arrêtent au sol).
// Quand la voiture traverse un nuage, effects.gd relance les particules touchées depuis
// leur position du moment avec le souffle de la voiture (nouveau départ).
//   base : 1re colonne = vitesse au départ, 2e colonne = (moment du départ, type, sol, -)
//   INSTANCE_CUSTOM = (naissance, durée de vie, taille, graine)
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Horloge du jeu (secondes), donnée par effects.gd.
uniform float now = 0.0;
uniform vec3 sun_dir = vec3(0.0, 0.3, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.66);
uniform vec3 ambient : source_color = vec3(0.62, 0.62, 0.66);
// Par type (poussière, sable, eau) : traînée de l'air, pesanteur (m/s², négatif = monte).
uniform vec3 drag_k = vec3(1.6, 0.7, 0.5);
uniform vec3 gravity_k = vec3(-0.5, 7.0, 9.8);
// Vent léger qui emporte la poussière.
uniform vec3 wind = vec3(0.6, 0.0, 0.25);

varying float alpha_k;
varying float back;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec4 meta = MODEL_MATRIX[1];
	int kind = int(meta.y + 0.5);
	float t = max(now - meta.x, 0.0);
	float age = now - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.01);
	float k = clamp(age / life, 0.0, 1.0);
	float dr = kind == 0 ? drag_k.x : (kind == 1 ? drag_k.y : drag_k.z);
	float g = kind == 0 ? gravity_k.x : (kind == 1 ? gravity_k.y : gravity_k.z);
	float e = exp(-dr * t);
	vec3 pos = origin + v0 * (1.0 - e) / dr - vec3(0.0, g, 0.0) * (t / dr - (1.0 - e) / (dr * dr));
	if (kind == 0) {
		pos += wind * t * smoothstep(0.0, 1.5, t);
	} else {
		// Les grains et les gouttes s'arrêtent au sol (ou sur l'eau).
		pos.y = max(pos.y, meta.z);
	}
	float grow = kind == 0 ? (0.35 + 1.9 * sqrt(k)) : (1.0 - 0.5 * k);
	float size = INSTANCE_CUSTOM.z * grow;
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
