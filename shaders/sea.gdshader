// Mer : houle qui arrive du large et s'écrase sur la plage, rides fines, eau claire et
// turquoise sur le sable près du bord, foncée au large, écume au bord. Reflets du ciel et
// du soleil donnés par le moteur (eau très lisse).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform vec4 depth_rect = vec4(290.0, -552.0, 420.0, 1104.0);
uniform vec3 deep_color : source_color = vec3(0.02, 0.13, 0.18);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.50, 0.48);
uniform vec3 foam_color : source_color = vec3(0.95, 0.93, 0.88);
uniform float wave_height = 0.25;

varying vec3 wpos;
varying float depth;

float water_depth(vec2 p) {
	vec2 uv = (p - depth_rect.xy) / depth_rect.zw;
	return texture(depth_tex, uv).r * 8.0;
}

// Houle : hauteur, pente x, pente z.
vec3 swell(vec2 p, float t) {
	vec3 r = vec3(0.0);
	vec2 dirs[4] = vec2[](vec2(-1.0, 0.15), vec2(-0.8, -0.55), vec2(-0.95, 0.35), vec2(-0.4, 0.9));
	float lens[4] = float[](38.0, 21.0, 11.0, 6.5);
	float amps[4] = float[](1.0, 0.5, 0.25, 0.12);
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float k = 6.28318 / lens[i];
		float c = sqrt(9.8 / k);
		float ph = k * (dot(d, p) - c * t);
		float a = amps[i] * wave_height;
		r.x += a * sin(ph);
		r.yz += a * k * cos(ph) * d;
	}
	return r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = water_depth(w.xz);
	VERTEX.y += swell(w.xz, TIME).x * clamp(depth / 2.0, 0.0, 1.0);
	wpos = w;
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float d = water_depth(p);
	vec3 s = swell(p, t);
	vec2 ripple = vec2(sin(p.x * 1.7 + t * 2.1 + sin(p.y * 0.9)), sin(p.y * 1.9 - t * 1.7 + sin(p.x * 1.1))) * 0.06;
	ripple += vec2(sin(p.x * 4.3 - t * 3.3 + p.y * 2.0), sin(p.y * 3.7 + t * 2.9 - p.x * 1.6)) * 0.03;
	vec3 nw = normalize(vec3(-(s.y + ripple.x), 1.0, -(s.z + ripple.y)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	vec3 water = mix(shallow_color, deep_color, clamp(d / 6.0, 0.0, 1.0));
	float shore = 1.0 - clamp(d / 0.9, 0.0, 1.0);
	float surf = sin(d * 5.0 - t * 1.6 + sin(p.y * 0.08) * 2.0) * 0.5 + 0.5;
	float foam = clamp(shore * 1.4 * (0.55 + 0.45 * surf), 0.0, 1.0);
	foam = max(foam, smoothstep(0.6, 1.0, surf) * clamp(1.0 - d / 2.5, 0.0, 1.0) * 0.5);

	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.04, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(0.4 + d * 0.6 + foam, 0.0, 1.0);
}
