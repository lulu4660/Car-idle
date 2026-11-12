// Arbres, cactus, buissons, rochers (vegetation.gd) : couleur par sommet, mats ; la nuit,
// éclairés par les réverbères proches et par les phares de la voiture.
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/night_light.gdshaderinc"
uniform sampler2D night_light_tex : filter_linear, repeat_disable;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float world_size = 1024.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	if (night > 0.01) {
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float lamp = texture(night_light_tex, (wpos.xz + vec2(world_size * 0.5)) / world_size).r;
		EMISSION = COLOR.rgb * (lamp_color * lamp * lamp * night * 1.2 + head_color * headlight(wpos, nw) * 1.6);
	}
}
