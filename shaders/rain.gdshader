// Pluie : traits de gouttes qui tombent dans une boîte autour de la voiture (une instance de
// MultiMesh par goutte, animée ici : aucune mise à jour par le processeur). Le vent les
// incline ; la quantité affichée suit la force de la pluie (visible_instance_count).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec3 weather_wind;
global uniform float night;
uniform vec3 center = vec3(0.0);
uniform vec3 box = vec3(44.0, 30.0, 44.0);
uniform float fall_speed = 22.0;
uniform float strength = 1.0;

varying float alpha_k;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 r = vec3(h1(id + 0.1), h1(id + 3.7), h1(id + 9.3));
	vec3 vel = vec3(weather_wind.x, 0.0, weather_wind.y) * 9.0 - vec3(0.0, fall_speed, 0.0);
	// Position qui boucle dans la boîte centrée sur la voiture.
	vec3 p = r * box + vel * TIME * (0.9 + 0.2 * h1(id + 5.1));
	p = mod(p - (center - box * 0.5), box) + (center - box * 0.5);
	// Trait aligné sur la vitesse, tourné vers la caméra.
	vec3 axis = normalize(vel);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - p);
	vec3 side = normalize(cross(axis, to_cam));
	vec3 wp = p + side * VERTEX.x * 0.035 + axis * VERTEX.y * 0.9;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	alpha_k = strength;
}

void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	vec3 col = mix(vec3(0.82, 0.85, 0.9), vec3(0.45, 0.5, 0.62), night);
	ALBEDO = col;
	ALPHA = 0.2 * edge * alpha_k * (0.6 + 0.4 * UV.y);
}
