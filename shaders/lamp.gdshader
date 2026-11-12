// Réverbère : mât sombre, ampoule qui s'allume la nuit (UV.x = 1 sur l'ampoule).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

global uniform float night;
uniform vec3 pole_color : source_color = vec3(0.22, 0.22, 0.25);
uniform vec3 bulb_color : source_color = vec3(1.0, 0.78, 0.45);

varying float bulb;

void vertex() {
	bulb = UV.x;
}

void fragment() {
	ALBEDO = mix(pole_color, vec3(0.9, 0.85, 0.75), bulb);
	EMISSION = bulb_color * bulb * night * 6.0;
	ROUGHNESS = 0.8;
}
