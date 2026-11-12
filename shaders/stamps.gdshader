// Traces de pneus : chaque empreinte est une instance d'un MultiMesh posée à plat sur le
// sol. INSTANCE_CUSTOM.x = moment de la pose, .y = durée de vie. Elle s'efface seule.
shader_type spatial;
// Horloge du jeu (secondes), donnée par effects.gd : la même que celle des poses.
uniform float now = 0.0;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;

varying float fade;

void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.01);
	fade = clamp(1.0 - (age - life * 0.7) / (life * 0.3), 0.0, 1.0);
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * t.a * fade;
}
