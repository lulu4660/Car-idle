// Prise de vue d'un modèle de végétation pour son imposteur (impostors.gd) : `mode` 0 =
// couleur (mêmes retouches pastel et pied plus sombre que vegetation.gdshader), 1 = normale
// vue de la caméra de prise de vue (rangée en 0..1) : l'imposteur, toujours face à la caméra
// du jeu, la reprend telle quelle. Sans éclairage : l'imposteur est éclairé en jeu.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform int mode = 0;
// Échelle moyenne du modèle en jeu : la hauteur du pied plus sombre se compte en mètres.
uniform float unit = 1.0;

varying float vh;

void vertex() {
	vh = VERTEX.y * unit;
}

void fragment() {
	if (mode == 0) {
		vec3 base = COLOR.rgb;
		float lum = dot(base, vec3(0.3, 0.55, 0.15));
		base = mix(vec3(lum), base, 0.8) * 1.12 + vec3(0.03, 0.02, 0.0);
		base *= mix(0.68, 1.06, smoothstep(0.0, 3.0, vh));
		ALBEDO = base;
	} else {
		vec3 n = normalize(FRONT_FACING ? NORMAL : -NORMAL);
		ALBEDO = n * 0.5 + 0.5;
	}
}
