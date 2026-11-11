// Oyats : brins en vraie 3D, couleur par sommet, agités par le vent (plus en haut qu'en bas),
// éclairés en partie par transparence ; ils portent leurs ombres sur le sable.
shader_type spatial;
render_mode cull_disabled;

uniform float wind = 0.16;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 1.0 - UV.y;
	float gust = sin(TIME * 1.6 + w.x * 0.3 + w.z * 0.2) + 0.5 * sin(TIME * 3.3 + w.z * 0.8 + w.x * 0.4);
	VERTEX.x += gust * wind * k * k;
	VERTEX.z += gust * wind * 0.5 * k * k;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = COLOR.rgb * 0.35;
	AO = mix(0.55, 1.0, 1.0 - UV.y);
}
