// Feux des voitures : petits pavés qui brillent la nuit (blancs devant, rouges derrière).
shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform float night;
uniform vec3 color : source_color = vec3(1.0, 0.95, 0.85);
uniform float power = 4.0;

void fragment() {
	ALBEDO = color * (0.25 + night * power);
}
