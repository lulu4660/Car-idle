// Effet maquette (« tilt-shift », comme Art of Rally) : l'image est nette dans une bande
// autour de la voiture et se floute doucement vers le haut et le bas de l'écran, ce qui
// donne l'impression d'une miniature. Passe 2D après toute la 3D (fumée, halos et objets
// transparents compris) ; l'affichage (boutons, compteur) est dessiné après, net.
// Coût : une lecture dans la bande nette ; ailleurs 5 (croix tournée). Réglage « Effet
// maquette » (coupé en Très bas).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// Centre de la bande nette (0 = haut de l'écran) et sa demi-hauteur.
uniform float focus_center = 0.52;
uniform float focus_half = 0.14;
// Rayon du flou au plus fort, en fraction de la hauteur de l'écran.
uniform float radius = 0.006;
uniform float strength = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - focus_center);
	float k = smoothstep(focus_half, focus_half + 0.32, d) * strength;
	vec3 c = texture(screen_tex, uv).rgb;
	if (k > 0.02) {
		vec2 r = vec2(radius * k * SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, radius * k);
		// Croix tournée de 4 lectures entre deux texels (le filtrage linéaire moyenne
		// déjà chaque fois 4 texels) : flou doux pour peu de lectures.
		vec3 acc = c * 0.6;
		acc += texture(screen_tex, uv + r * vec2(1.3, 0.55)).rgb;
		acc += texture(screen_tex, uv + r * vec2(-1.3, -0.55)).rgb;
		acc += texture(screen_tex, uv + r * vec2(-0.55, 1.3)).rgb;
		acc += texture(screen_tex, uv + r * vec2(0.55, -1.3)).rgb;
		c = acc / 4.6;
		// Un soupçon de saturation en plus dans le flou (couleurs de maquette).
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(vec3(l), c, 1.0 + 0.08 * k);
	}
	COLOR = vec4(c, 1.0);
}
