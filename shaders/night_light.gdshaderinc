// Lumières de nuit communes à tous les shaders qui les reçoivent (sol, herbe, arbres,
// bâtiments) : paramètres globaux (project.godot, [shader_globals]) mis à jour par le jeu.
global uniform float night;
global uniform vec3 head_pos;   // phares de la voiture du joueur
global uniform vec3 head_dir;
uniform vec3 head_color : source_color = vec3(1.0, 0.9, 0.72);

// Lumière des phares en ce point (0 le jour ou hors du cône). `n` : normale (monde) de la
// surface ; un mur tourné vers la voiture est plus éclairé qu'un mur de biais.
float headlight(vec3 wp, vec3 n) {
	if (night < 0.01) {
		return 0.0;
	}
	vec3 v = wp - head_pos;
	float d = length(v);
	if (d > 45.0 || d < 0.1) {
		return 0.0;
	}
	vec3 l = v / d;
	float cone = smoothstep(0.85, 0.97, dot(l, head_dir));
	float fall = pow(clamp(1.0 - d / 45.0, 0.0, 1.0), 1.4) * smoothstep(0.5, 3.0, d);
	float facing = clamp(dot(n, -l) * 1.2 + 0.15, 0.0, 1.0);
	return cone * fall * facing * night;
}
