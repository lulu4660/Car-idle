## Fondu en distance du décor : les objets s'effacent peu à peu (trame) avant leur distance
## d'affichage au lieu d'apparaître d'un coup. Shaders du décor : `shaders/far_fade.gdshaderinc`
## (`fade_end`, `fade_width`) ; matériaux standard (objets fusionnés du kit, voitures et
## piétons) : leur fondu en distance intégré, en trame (`DISTANCE_FADE_*_DITHER`).
## Les cases restent affichées `margin` mètres plus loin que la fin du fondu (le moteur les
## coupe quand le centre de la case s'éloigne : il faut que leurs objets aient déjà disparu).
## La distance d'affichage des réglages (`settings.range`) multiplie `fade_end`.
extends RefCounted

const WIDTH := 50.0
## Marge des cases : 0,3 × leur taille. Une case est coupée quand son centre passe à
## `fade_end + marge` : ses objets les plus proches sont alors vers `fade_end - 0,4 × taille`,
## au début de la bande de fondu (50 m). Mesuré en ville : 0 = coût d'avant mais objets qui
## surgissent, 0,45 = +35 % de sommets ; 0,3 est le compromis.
const CELL_MARGIN := 0.3


## `fade_end` : distance où l'objet a disparu ; `margin` : `CELL_MARGIN` × la taille de la
## case pour une case, quelques mètres pour un objet seul.
static func setup(gi: GeometryInstance3D, fade_end: float, margin: float, width := WIDTH, per_object := false) -> void:
	gi.set_meta("fade_end", fade_end)
	gi.set_meta("fade_margin", margin)
	gi.set_meta("fade_width", width)
	gi.set_meta("fade_object", per_object)
	apply(gi, 1.0)


## Applique la distance d'affichage des réglages (facteur `f`).
static func apply(gi: GeometryInstance3D, f: float) -> void:
	var end := float(gi.get_meta("fade_end")) * f
	var width := minf(float(gi.get_meta("fade_width")), end * 0.5)
	gi.visibility_range_end = end + float(gi.get_meta("fade_margin"))
	for m in materials_of(gi):
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("fade_end", end)
			(m as ShaderMaterial).set_shader_parameter("fade_width", width)
		elif m is BaseMaterial3D:
			var b := m as BaseMaterial3D
			# Distance mini > maxi : l'objet s'efface en s'éloignant (et non en s'approchant).
			b.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER if bool(gi.get_meta("fade_object")) else BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			b.distance_fade_min_distance = end
			b.distance_fade_max_distance = end - width


static func materials_of(gi: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if gi.material_override:
		out.append(gi.material_override)
		return out
	var mesh: Mesh = null
	if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	elif gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	if mesh:
		for s in mesh.get_surface_count():
			var m: Material = (gi as MeshInstance3D).get_surface_override_material(s) if gi is MeshInstance3D else null
			if m == null:
				m = mesh.surface_get_material(s)
			if m:
				out.append(m)
	return out
