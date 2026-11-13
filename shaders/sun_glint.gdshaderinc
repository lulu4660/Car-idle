// Reflet du soleil (ou de la lune) sur l'eau : flaques, sol mouillé, mer.
// Vrai miroir : on renvoie le regard sur la surface (sa normale) et l'on compare à la
// direction de l'astre. Trois lobes : le disque (net, très fort, déclenche le bloom), son
// halo, et une large traînée douce ; sur une surface ridée chaque petite facette renvoie
// son propre éclat, ce qui donne le chemin scintillant vers le soleil.
// sun_dir : direction vers l'astre qui éclaire ; sun_glint : sa couleur × sa force (déjà
// voilée par les nuages), mis à jour par lighting.gd.
global uniform vec3 sun_dir;
global uniform vec3 sun_glint;

// n : normale (monde) de l'eau ; v : direction vers la caméra (monde) ; spread 0 = miroir
// lisse, 1 = eau agitée (reflet plus étalé, moins intense) ; reach : écart de hauteur
// toléré (radians) entre le regard renvoyé et l'astre.
// La caméra est haute et plongeante : un miroir parfait ne montrerait le soleil que s'il
// est aussi haut que la caméra est plongeante. Comme sur une mer ridée, où les pentes des
// vagues étirent le reflet en un long chemin vers l'astre, le reflet est étiré en hauteur
// (direction de l'astre gardée, hauteur rapprochée de celle du regard renvoyé) et
// s'affaiblit avec l'écart.
vec3 sun_reflection(vec3 n, vec3 v, float spread, float reach) {
	if (sun_dir.y < -0.05) {
		return vec3(0.0);
	}
	vec3 r = reflect(-v, n);
	float el_s = asin(clamp(sun_dir.y, -1.0, 1.0));
	float de = asin(clamp(r.y, -1.0, 1.0)) - el_s;
	float el_t = el_s + clamp(de, -reach, reach);
	vec2 hs = normalize(sun_dir.xz + vec2(1e-5));
	vec3 s = vec3(hs.x * cos(el_t), sin(el_t), hs.y * cos(el_t));
	float d = max(dot(r, s), 0.0);
	float disk = pow(d, mix(3000.0, 600.0, spread)) * mix(14.0, 5.0, spread);
	float halo = pow(d, mix(220.0, 70.0, spread)) * mix(1.6, 1.0, spread);
	float wide = pow(d, 10.0) * 0.18;
	float fall = exp(-de * de / (reach * reach + 1e-4) * 1.5);
	// Plus fort en rasant (Fresnel de l'eau).
	float fres = 0.3 + 0.7 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
	return sun_glint * (disk + halo + wide) * fres * fall;
}
