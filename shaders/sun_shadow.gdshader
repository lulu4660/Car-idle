// Ombres du décor pour la position du soleil (ou de la lune) du moment, calculées par la
// carte graphique dans une fenêtre de 256 m autour de la voiture (50 cm par pixel ;
// scripts/balade/sun_shadows.gd la refait par morceaux, en continu).
// Pour chaque point du sol, on remonte le rayon vers l'astre pas à pas dans la carte des
// obstacles (tools/bake_shadows.gd : haut et bas des objets depuis leur pied, part de la
// case couverte) : le rayon est bloqué s'il passe entre le bas et le haut d'un objet.
// Sortie : 0 = au soleil, 1 = dans l'ombre (bords adoucis).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D occ_tex : filter_linear, repeat_disable;
// Direction horizontale vers l'astre (x, z), normalisée.
uniform vec2 sun_xz = vec2(1.0, 0.0);
// Montée du rayon par mètre (tangente de la hauteur de l'astre).
uniform float rise = 1.0;
uniform int steps = 32;
uniform float step_len = 0.5;
uniform float map_px = 2048.0;
uniform float texel = 0.5;
// Coin de la fenêtre calculée, en pixels de la carte des obstacles.
uniform vec2 origin_px = vec2(0.0);

varying vec2 px;

void vertex() {
	px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv0 = (origin_px + px + vec2(0.0)) / map_px;
	vec2 duv = sun_xz * (step_len / texel / map_px);
	float span = float(steps) * step_len;
	float m = 0.0;
	for (int i = 1; i <= steps; i++) {
		float t = float(i) * step_len;
		vec3 o = texture(occ_tex, uv0 + duv * float(i)).rgb;
		float cov = smoothstep(0.15, 0.6, o.b);
		if (cov > 0.0) {
			float h = t * rise;
			float top = o.r * 25.5;
			float bot = o.g * 25.5;
			float hit = cov * clamp((top - h) / 0.25 + 0.5, 0.0, 1.0) * clamp((h - bot) / 0.25 + 0.5, 0.0, 1.0);
			// Ombre très longue (soleil bas) : s'efface au bout de la portée du calcul.
			m = max(m, hit * (1.0 - smoothstep(span * 0.75, span, t)));
		}
	}
	COLOR = vec4(m, m, m, 1.0);
}
