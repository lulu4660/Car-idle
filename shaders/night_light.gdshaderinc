// Lumières de nuit communes à tous les shaders qui les reçoivent (sol, herbe, arbres,
// bâtiments) : paramètres globaux (project.godot, [shader_globals]) mis à jour par le jeu.
global uniform float night;
global uniform vec3 head_pos;   // phares de la voiture du joueur
global uniform vec3 head_dir;
global uniform vec3 head_side;  // demi-écart entre les deux phares (vers la droite)
uniform vec3 head_color : source_color = vec3(1.0, 0.9, 0.72);

// Un phare : cône depuis `p`.
float _beam(vec3 wp, vec3 n, vec3 p) {
	vec3 v = wp - p;
	float d = length(v);
	vec3 l = v / max(d, 0.1);
	float cone = smoothstep(0.86, 0.97, dot(l, head_dir));
	float fall = pow(clamp(1.0 - d / 45.0, 0.0, 1.0), 1.4) * smoothstep(0.5, 3.0, d);
	float facing = clamp(dot(n, -l) * 1.2 + 0.15, 0.0, 1.0);
	return cone * fall * facing;
}

// Lumière des deux phares en ce point (0 le jour ou loin). `n` : normale (monde) de la
// surface ; un mur tourné vers la voiture est plus éclairé qu'un mur de biais.
float headlight(vec3 wp, vec3 n) {
	if (night < 0.01 || distance(wp, head_pos) > 46.0) {
		return 0.0;
	}
	return (_beam(wp, n, head_pos - head_side) + _beam(wp, n, head_pos + head_side)) * 0.62 * night;
}
