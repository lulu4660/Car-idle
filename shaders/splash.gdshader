// Éclaboussures de pluie au sol autour de la voiture : petits anneaux qui s'ouvrent et
// s'effacent, replacés au hasard à chaque cycle, posés sur le relief (texture des hauteurs
// du terrain). Rien sur la mer.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float weather_rain;
uniform sampler2D height_tex : filter_nearest;
uniform float world_size = 1024.0;
uniform float sea_level = 10.0;
uniform vec3 center = vec3(0.0);
uniform float radius = 22.0;

varying float k_life;
varying float alive;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float period = 0.45 + 0.3 * h1(id + 2.0);
	float t = TIME / period + h1(id + 7.0);
	float cyc = floor(t);
	k_life = fract(t);
	vec2 off = (vec2(h1(id * 1.7 + cyc * 3.1), h1(id * 2.3 + cyc * 5.7)) * 2.0 - 1.0) * radius;
	vec2 xz = center.xz + off;
	ivec2 g = ivec2(clamp(xz + vec2(world_size * 0.5), vec2(0.0), vec2(world_size)));
	float y = texelFetch(height_tex, g, 0).r;
	alive = step(sea_level + 0.15, y) * step(h1(id + cyc * 9.1), weather_rain);
	float s = (0.08 + k_life * 0.28) * alive;
	vec3 wp = vec3(xz.x, y + 0.04, xz.y) + vec3(VERTEX.x, 0.0, VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring = smoothstep(0.15, 0.0, abs(r - 0.75));
	ALBEDO = vec3(0.85, 0.88, 0.92);
	ALPHA = ring * (1.0 - k_life) * 0.55 * alive;
}
