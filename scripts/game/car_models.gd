## Voitures du catalogue montrées avec les modèles du « Low Poly Car Set » : chaque
## carrosserie du catalogue prend le modèle du pack le plus proche, repeint à la couleur
## de la voiture (la peinture du pack est un aplat : on remplace sa couleur).
## Sert au garage (maillage fusionné, peinture brillante), à la balade (voiture conduite,
## voitures à spotter) et à la circulation (life.gd).
extends RefCounted

const Car = preload("res://scripts/balade/car.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const MeshMerge = preload("res://scripts/balade/mesh_merge.gd")

## Carrosserie du catalogue -> modèle du pack.
## (Dans le pack, « coupe » est un gros tout-terrain à calandre, « break » un break haut.)
const KIT_BY_BODY := {
	"citadine": "puce", "compacte": "familiale", "berline": "berline", "break": "break",
	"4x4": "coupe", "suv": "break", "monospace": "break", "combi": "fourgon",
	"fourgon": "fourgon", "coupe": "bolide", "fastback": "berline_longue", "sportback": "bolide",
	"cabriolet": "puce_carbone", "roadster": "puce_carbone", "pickup": "coupe", "supercar": "bolide",
}

static var _oriented := {}


## Modèle du pack pour une voiture du catalogue (supercars épiques et plus : Bolide GT).
static func kit_for(model_id: String) -> String:
	var m := Catalog.get_car(model_id)
	if m.is_empty():
		return "bolide"
	var kit: String = KIT_BY_BODY.get(String(m["body"]), "berline")
	if kit == "bolide" and int(m["rarity"]) >= 3:
		kit = "bolide_gt"
	return kit


static func color_of(car: Dictionary) -> Color:
	var hex := String(car.get("color", ""))
	if hex == "":
		hex = String(Catalog.get_car(String(car.get("model", ""))).get("color", "888888"))
	return Color.html(hex)


## Matériau de peinture du pack : une petite texture d'une seule couleur (cars_1 à cars_7) ;
## cars_0 est la palette des détails (vitres, phares, pneus).
static func is_paint(mat: Material) -> bool:
	if not mat is BaseMaterial3D:
		return false
	var tex := (mat as BaseMaterial3D).albedo_texture
	return tex != null and not tex.resource_path.ends_with("cars_0.png") and (mat as BaseMaterial3D).albedo_color.a > 0.9


## Peinture principale d'un ensemble de pièces : celle qui couvre le plus de sommets
## (les bandes d'un Bolide restent blanches).
static func main_paint(meshes: Array) -> Material:
	var count := {}
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si)
			if is_paint(mat):
				count[mat] = int(count.get(mat, 0)) + int(mi.mesh.surface_get_array_len(si))
	var best: Material = null
	var n := -1
	for mat in count:
		if int(count[mat]) > n:
			n = int(count[mat])
			best = mat
	return best


## Maillage fusionné d'un modèle du pack, avant vers +Z et haut vers +Y, à sa longueur
## réelle : [maillage, transformation à appliquer, demi-taille, index de la surface peinte].
static func oriented(kit: String) -> Array:
	if _oriented.has(kit):
		return _oriented[kit]
	var scene: Node3D = (load(Car.PACK) as PackedScene).instantiate()
	var node: Node3D = scene.find_child(String(Car.TOON[kit][0]), true, false)
	var wheels: Array[Vector3] = []
	for code in Car.WHEEL_CODES:
		for c in node.get_children():
			if String(c.name).contains(code):
				wheels.append(Car._center(c, node))
				break
	var paint := main_paint(node.find_children("*", "MeshInstance3D", true, false))
	var paint_name := paint.resource_name if paint else ""
	var merged: Array = MeshMerge.merge(node, false)
	scene.free()
	var mesh: ArrayMesh = merged[0]
	var box: AABB = merged[1]
	var paint_surface := -1
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		if mat and paint_name != "" and mat.resource_name == paint_name:
			paint_surface = si
	var front := (wheels[0] + wheels[1]) / 2.0
	var back := (wheels[2] + wheels[3]) / 2.0
	var fwd_n := (front - back).normalized()
	var side := (wheels[0] - wheels[1]).normalized()
	var up := Vector3.UP
	for a in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if absf((a as Vector3).dot(fwd_n)) + absf((a as Vector3).dot(side)) < 0.3:
			up = a
			break
	if (wheels[0] + wheels[1] + wheels[2] + wheels[3]).dot(up) / 4.0 > box.get_center().dot(up):
		up = -up
	var x_axis := up.cross(fwd_n).normalized()
	var basis := Basis(x_axis, up, fwd_n).inverse()
	var rot_box := Transform3D(basis, Vector3.ZERO) * box
	var s: float = float(Car.TOON[kit][1]) / maxf(rot_box.size.z, 0.01)
	var xf := Transform3D(basis.scaled(Vector3.ONE * s), Vector3.ZERO)
	var placed := xf * box
	xf.origin = Vector3(-placed.get_center().x, -placed.position.y, -placed.get_center().z)
	var v := [mesh, xf, placed.size / 2.0, paint_surface]
	_oriented[kit] = v
	return v


## Repeint une voiture déjà construite (voiture conduite en balade) : la peinture la plus
## étendue prend la couleur voulue.
static func repaint(root: Node3D, paint: Color) -> void:
	var best: Array = []
	var n := -1
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(si)
			if is_paint(mat) and mi.mesh.surface_get_array_len(si) > n:
				n = mi.mesh.surface_get_array_len(si)
				best = [mi, si, mat]
	if best.is_empty():
		return
	var m := (best[2] as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.albedo_texture = null
	m.albedo_color = paint
	(best[0] as MeshInstance3D).set_surface_override_material(int(best[1]), m)


## Voiture d'exposition (garage) : maillage du pack, peinture brillante à la couleur
## voulue, détails légèrement brillants. Le bas des roues est à y = 0, l'avant vers +Z.
static func showroom(kit: String, paint: Color) -> MeshInstance3D:
	var v := oriented(kit)
	var mi := MeshInstance3D.new()
	mi.mesh = v[0]
	mi.transform = v[1]
	var mesh: ArrayMesh = v[0]
	for si in mesh.get_surface_count():
		var src := mesh.surface_get_material(si) as BaseMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as BaseMaterial3D
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.roughness = 0.5
		m.metallic_specular = 0.5
		if si == int(v[3]):
			m.albedo_texture = null
			m.albedo_color = paint
			m.roughness = 0.22
			m.metallic = 0.35
			m.metallic_specular = 0.8
		mi.set_surface_override_material(si, m)
	return mi
