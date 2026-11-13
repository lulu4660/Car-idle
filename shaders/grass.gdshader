// Herbe low poly : lames facettées en couleurs unies (couleur par sommet), agités par le vent (plus en haut qu'en bas),
// éclairés en partie par transparence ; ils portent leurs ombres sur le sable.
shader_type spatial;
render_mode cull_disabled;

uniform float wind = 0.16;
uniform float world_size = 1024.0;
#include "res://shaders/car_shadow.gdshaderinc"
varying vec3 wpos;
varying float sun_vis;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 1.0 - UV.y;
	// Vent (météo) : l'herbe se couche dans le sens du vent et ondule en rafales.
	float strength = wind + weather_wind.z * 0.55;
	vec2 wdir = normalize(weather_wind.xy + vec2(1e-4));
	float speed = 1.6 + weather_wind.z * 2.5;
	float gust = sin(TIME * speed + w.x * 0.3 + w.z * 0.2) + 0.5 * sin(TIME * speed * 2.1 + w.z * 0.8 + w.x * 0.4);
	vec2 bend = wdir * (0.6 + 0.4 * gust) * weather_wind.z * 0.6 + vec2(gust, gust * 0.5) * strength * 0.5;
	VERTEX.x += bend.x * k * k;
	VERTEX.z += bend.y * k * k;
	wpos = w;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	base = mix(vec3(lum), base, 0.8) * 1.12 + vec3(0.03, 0.02, 0.0);
	base *= mix(vec3(1.0), vec3(0.62, 0.6, 0.72), ground_ao(wpos, world_size) * 0.85);
	ALBEDO = base * mix(1.0, 0.75, weather_wet);
	ROUGHNESS = mix(0.9, 0.5, weather_wet);
	SPECULAR = 0.0;
	BACKLIGHT = COLOR.rgb * 0.25;
	sun_vis = sun_visibility(wpos, world_size);
	EMISSION = COLOR.rgb * (lamp_glow(wpos, world_size) + head_color * headlight(wpos, vec3(0.0, 1.0, 0.0)) * 1.4);
}

void light() {
	DIFFUSE_LIGHT += (clamp(dot(NORMAL, LIGHT), 0.0, 1.0) + 0.25) * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_vis : ATTENUATION);
}
