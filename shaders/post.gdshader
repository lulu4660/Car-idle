// Post-traitement « cinéma » des réglages Haut et Ultra, dessiné sur un rectangle collé à la
// caméra (marche avec tous les rendus, web compris) :
// - niveau 1 : étalonnage (contraste en S, ombres légèrement lavande, hautes lumières
//   chaudes), netteté, aberration chromatique sur les bords, grain très fin ;
// - niveau 2 : en plus, effet « maquette » (tilt-shift : flou de profondeur hors de la zone
//   de la voiture, fort en haut de l'image) et rayons du soleil à travers le décor.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform int level = 1;
uniform float focus_distance = 30.0;     // distance caméra -> voiture (m)
uniform float blur_strength = 1.0;
uniform vec2 sun_screen = vec2(0.5, -0.3);  // position du soleil à l'écran (UV)
uniform float sun_visible = 0.0;
uniform vec3 sun_tint : source_color = vec3(1.0, 0.82, 0.55);
uniform float night = 0.0;
uniform float time = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;

	if (level >= 2) {
		// Tilt-shift : le flou dépend de l'écart de profondeur avec la voiture, renforcé en
		// haut de l'image (le lointain), nul autour de la voiture.
		float z = linear_depth(uv, INV_PROJECTION_MATRIX);
		float dz = abs(z - focus_distance) / focus_distance;
		float band = smoothstep(0.12, 0.55, abs(uv.y - 0.55));
		float coc = clamp(dz * 1.4 + band * 0.6 - 0.25, 0.0, 1.0) * blur_strength;
		if (coc > 0.02) {
			vec3 acc = col;
			float wsum = 1.0;
			float radius = coc * 9.0;
			for (int i = 0; i < 12; i++) {
				float a = float(i) * 2.39996;
				float r = sqrt(float(i) + 0.5) / sqrt(12.0) * radius;
				vec2 o = vec2(cos(a), sin(a)) * r * px;
				acc += textureLod(screen_tex, uv + o, coc * 1.5).rgb;
				wsum += 1.0;
			}
			col = acc / wsum;
		}
		// Rayons du soleil : flou radial des zones claires vers le soleil.
		if (sun_visible > 0.01 && night < 0.5) {
			vec2 dir = (sun_screen - uv) / 16.0;
			vec2 p = uv;
			float decay = 1.0;
			vec3 rays = vec3(0.0);
			for (int i = 0; i < 16; i++) {
				p += dir;
				vec3 s = textureLod(screen_tex, clamp(p, vec2(0.0), vec2(1.0)), 2.0).rgb;
				rays += max(s - vec3(0.72), vec3(0.0)) * decay;
				decay *= 0.92;
			}
			col += rays * sun_tint * 0.09 * sun_visible;
		}
	}

	// Netteté légère (4 voisins).
	vec3 n = texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
	if (level < 2) {
		col += (col - n * 0.25) * 0.35;
	}
	// Aberration chromatique sur les bords seulement.
	vec2 fromc = uv - 0.5;
	float edge = dot(fromc, fromc);
	vec2 ca = fromc * edge * 0.012;
	col.r = mix(col.r, texture(screen_tex, uv + ca).r, 0.7);
	col.b = mix(col.b, texture(screen_tex, uv - ca).b, 0.7);
	// Étalonnage : courbe en S douce, ombres lavande, lumières chaudes (DA de la balade).
	float l = luma(col);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.25);
	col += vec3(0.02, 0.0, 0.035) * (1.0 - smoothstep(0.0, 0.4, l)) * (1.0 - night * 0.5);
	col *= mix(vec3(1.0), vec3(1.04, 1.0, 0.94), smoothstep(0.5, 1.0, l) * (1.0 - night));
	// Grain très fin, animé.
	float g = fract(sin(dot(uv * VIEWPORT_SIZE + time * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (g - 0.5) * 0.018;
	ALBEDO = col;
}
