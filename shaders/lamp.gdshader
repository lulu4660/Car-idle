// Réverbère : mât (couleur par sommet), ampoule qui s'allume la nuit (UV.x = 1 sur l'ampoule).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

global uniform float night;
#include "res://shaders/far_fade.gdshaderinc"
uniform vec3 pole_color : source_color = vec3(0.22, 0.22, 0.25);
uniform vec3 bulb_color : source_color = vec3(1.0, 0.78, 0.45);

varying float bulb;

void vertex() {
	bulb = UV.x;
	v_far = far_amount(MODEL_MATRIX, INV_VIEW_MATRIX);
	v_far_seed = far_seed(MODEL_MATRIX);
	if (v_far >= 1.0) {
		VERTEX = vec3(0.0);   // trop loin : objet replié, aucun pixel
	}
}

void fragment() {
	if (v_far > far_bayer(FRAGCOORD.xy, v_far_seed)) {
		discard;
	}
	// Couleur du mât par sommet (métal, fonte, bois selon le modèle).
	ALBEDO = mix(COLOR.rgb, vec3(0.9, 0.85, 0.75), bulb);
	EMISSION = bulb_color * bulb * night * 6.0;
	ROUGHNESS = 0.8;
}
