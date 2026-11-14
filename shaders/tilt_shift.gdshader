// Effet maquette (« tilt-shift », comme Art of Rally) : l'image est nette dans une bande
// autour de la voiture et se floute doucement vers le haut et le bas de l'écran, ce qui
// donne l'impression d'une miniature. Passe 2D après toute la 3D (fumée, halos et objets
// transparents compris) ; l'affichage (boutons, compteur) est dessiné après, net.
// Coût : une lecture dans la bande nette ; ailleurs 5 (croix tournée). Réglage « Effet
// maquette » (coupé en Très bas).
// La même passe fait l'étalonnage final (façon Art of Rally : contraste doux en S, couleurs
// ternes ravivées, ombres lavande, lumières pêche) et le vignettage : quelques calculs sur un
// pixel déjà lu, au lieu d'un calque plein écran de plus (lighting.gd).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// Centre de la bande nette (0 = haut de l'écran) et sa demi-hauteur.
uniform float focus_center = 0.52;
uniform float focus_half = 0.2;
// Rayon du flou au plus fort, en fraction de la hauteur de l'écran.
uniform float radius = 0.006;
uniform float strength = 1.0;
// Étalonnage (0 = aucun) et vignettage (opacité au coin), donnés par lighting.gd.
uniform float grade = 1.0;
uniform float vignette = 0.28;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.55, 0.85);
uniform vec3 light_tint : source_color = vec3(1.0, 0.82, 0.62);

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
	// Étalonnage.
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sc = clamp(c, 0.0, 1.0);
	c = mix(c, sc * sc * (3.0 - 2.0 * sc), 0.2 * grade);
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(l), c, 1.0 + 0.3 * grade * (1.0 - smoothstep(0.0, 0.45, sat)));
	c += (shadow_tint - 0.7) * (1.0 - smoothstep(0.05, 0.5, l)) * 0.07 * grade;
	c += (light_tint - 0.8) * smoothstep(0.5, 1.0, l) * 0.08 * grade;
	// Vignettage (le même dégradé radial que l'ancien calque).
	float t = length(uv - 0.5) / 0.778;
	c = mix(c, vec3(0.02, 0.0, 0.05), clamp((t - 0.55) / 0.45, 0.0, 1.0) * vignette);
	COLOR = vec4(c, 1.0);
}
