// Poussière « en blocs » : petits rochers low poly opaques soulevés par les roues, qui
// dérivent, tournent sur eux-mêmes puis rétrécissent jusqu'à disparaître. Opaques et
// éclairés comme le décor (ombres teintées comprises) : pas de transparence, peu coûteux.
// Même codage que dust.gdshader : 1re colonne = vitesse, 2e = (départ, type, sol, -),
// INSTANCE_CUSTOM = (naissance, durée de vie, taille, graine).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, skip_vertex_transform, specular_disabled;

// Transparence : la terre soulevée est en partie transparente, et s'efface en fin de vie.
uniform float opacity = 0.62;
varying float fade;

uniform float now = 0.0;
uniform float drag = 2.2;
uniform float lift = 0.35;
uniform vec3 wind = vec3(0.4, 0.0, 0.15);

vec3 rotate_axis(vec3 v, vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float start = MODEL_MATRIX[1].x;
	float t = max(now - start, 0.0);
	float age = now - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.01);
	float k = clamp(age / life, 0.0, 1.0);
	float seed = INSTANCE_CUSTOM.w;
	float e = exp(-drag * t);
	vec3 pos = origin + v0 * (1.0 - e) / drag + vec3(0.0, lift, 0.0) * t + wind * t * smoothstep(0.0, 1.5, t);
	// Gonfle comme un nuage (petit à la sortie de la roue, plusieurs fois plus gros ensuite),
	// puis fond sur la fin de sa vie.
	float size = INSTANCE_CUSTOM.z * (0.25 + 1.0 * sqrt(smoothstep(0.0, 0.55, k))) * (1.0 - smoothstep(0.62, 1.0, k));
	if (age < 0.0 || age > life) {
		size = 0.0;
	}
	fade = smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.45, 1.0, k));
	vec3 axis = normalize(vec3(sin(seed * 12.9), cos(seed * 7.3), sin(seed * 3.1 + 1.0)));
	float ang = seed * 6.28 + t * (1.5 + seed * 2.0);
	vec3 local = rotate_axis(VERTEX * vec3(1.0, 0.8 + seed * 0.4, 1.0), axis, ang) * size;
	vec3 world = pos + local;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(rotate_axis(NORMAL, axis, ang), 0.0)).xyz);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = opacity * fade;
}
