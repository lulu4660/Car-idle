// Halo de lumière (remplace le « glow » plein écran, trop coûteux sur iPhone) : un petit
// disque doux additif, tourné vers la caméra, qui n'apparaît que la nuit.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float night;
uniform vec3 color : source_color = vec3(1.0, 0.75, 0.45);
uniform float strength = 1.0;
uniform bool use_vertex_color = false;

void vertex() {
	// Panneau face à la caméra, taille donnée par l'échelle de l'instance.
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 view_c = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	view_c.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * vec4(view_c, 1.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	vec3 c = use_vertex_color ? COLOR.rgb : color;
	ALBEDO = c * a * night * strength;
}
