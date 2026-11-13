// Le décor s'efface autour de la voiture : tout ce qui se trouve entre la caméra et la
// voiture (immeubles, arbres) et tout ce qui touche presque la caméra disparaît par une
// trame régulière, avec un bord doux. La voiture reste toujours visible. Les ombres ne
// changent pas (elles sont calculées à part).
// see_pos : la voiture (balade.gd, à chaque image).
global uniform vec3 see_pos;

float see_bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

// 0 = visible, 1 = effacé.
float see_fade(vec3 wp, vec3 cam) {
	vec3 seg = see_pos - cam;
	float len = length(seg);
	if (len < 1.0) {
		return 0.0;
	}
	vec3 d = seg / len;
	vec3 rel = wp - cam;
	float t = dot(rel, d);
	float fade = 0.0;
	if (t > 0.0 && t < len - 1.2) {
		float r = length(rel - d * t);
		// Cône : étroit près de la caméra, large autour de la voiture.
		float rad = mix(2.5, 6.0, clamp(t / len, 0.0, 1.0));
		fade = 1.0 - smoothstep(rad * 0.6, rad, r);
	}
	return max(fade, 1.0 - smoothstep(6.0, 11.0, length(rel)));
}
