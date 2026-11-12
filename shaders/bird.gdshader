// Mouette : ailes qui battent (puis planent), dessous clair, bouts d'ailes gris.
shader_type spatial;
render_mode cull_disabled;

uniform float now = 0.0;
instance uniform float phase = 0.0;

void vertex() {
	float t = now + phase;
	// Battements par séries, entrecoupés de vol plané.
	float flap = sin(t * 9.0) * smoothstep(0.2, 0.6, sin(t * 0.8) * 0.5 + 0.5);
	VERTEX.y += flap * UV.x * UV.x * 0.35;
}

void fragment() {
	ALBEDO = mix(vec3(0.95), vec3(0.45, 0.47, 0.5), smoothstep(0.75, 1.0, UV.x));
	ROUGHNESS = 0.8;
}
