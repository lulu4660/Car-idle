// Herbes sèches : panneaux découpés (alpha), agités par le vent, ombres portées.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wind = 0.18;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + w.x * 0.35 + w.z * 0.2) + 0.5 * sin(TIME * 3.1 + w.z * 0.7);
	VERTEX.x += gust * wind * k * k;
	VERTEX.z += gust * wind * 0.4 * k * k;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Un peu de lumière traverse les brins.
	BACKLIGHT = vec3(0.25, 0.2, 0.1);
}
