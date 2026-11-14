// Fondu en distance du décor (scripts/balade/far_fade.gd) : au lieu d'apparaître d'un coup
// quand sa case de 96 à 120 m entre dans la distance d'affichage, chaque objet se dessine
// peu à peu par une trame régulière (la même que see_through) sur `fade_width` mètres,
// jusqu'à `fade_end` (distance à plat depuis la caméra jusqu'au pied de l'objet). Les cases
// restent affichées un peu au-delà ; leurs objets trop loin y sont repliés en un point (aucun
// pixel dessiné).
uniform float fade_end = 0.0;      // m ; 0 = pas de fondu
uniform float fade_width = 35.0;   // m
varying float v_far;
varying float v_far_seed;

// 0 = visible, 1 = effacé. Pied de l'objet : origine de l'instance (MODEL_MATRIX[3]).
float far_amount(mat4 model, mat4 inv_view) {
	if (fade_end <= 0.0) {
		return 0.0;
	}
	vec2 d = model[3].xz - inv_view[3].xz;
	return clamp((length(d) - (fade_end - fade_width)) / fade_width, 0.0, 1.0);
}

// À appeler à la fin de vertex() (après les déplacements du vent) : voir les shaders du décor.
float far_seed(mat4 model) {
	return floor(fract(model[3].x * 0.37 + model[3].z * 0.61) * 16.0);
}

// Trame 4 × 4 décalée par objet (pas le même motif partout).
float far_bayer(vec2 p, float seed) {
	int x = int(mod(p.x + seed, 4.0));
	int y = int(mod(p.y + floor(seed * 0.25), 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}
