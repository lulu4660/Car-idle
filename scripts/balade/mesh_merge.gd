## Fusion d'un modèle en un seul maillage : toutes ses pièces (positions relatives gardées)
## réunies, une surface par matériau. Une voiture du pack passe d'une dizaine d'objets à
## 3 ou 4 appels de dessin ; un bâtiment Kenney (une texture commune) à un seul.
## Les matériaux sont rendus mats (pas de reflet), dans l'esprit de la balade.
extends RefCounted


## Maillage fusionné de `root` (déjà instancié, pas dans l'arbre), recentré si `center`
## (milieu en x/z, bas à y = 0). Rend [maillage, boîte englobante].
static func merge(root: Node3D, center := true) -> Array:
	var groups := {}   # matériau -> SurfaceTool
	var mats := {}
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != root:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			var key: Variant = mat if mat else "none"
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = st
				mats[key] = _matte(mat)
			(groups[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var mesh := ArrayMesh.new()
	for key in groups:
		(groups[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	var box := mesh.get_aabb()
	if center and mesh.get_surface_count() > 0:
		var off := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		var moved := ArrayMesh.new()
		for s in mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mesh, s, Transform3D(Basis.IDENTITY, off))
			st.commit(moved)
			moved.surface_set_material(s, mesh.surface_get_material(s))
		mesh = moved
		box = mesh.get_aabb()
	return [mesh, box]


static func _matte(mat: Material) -> Material:
	if mat is BaseMaterial3D:
		var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.metallic = 0.0
		m.roughness = 1.0
		return m
	var d := StandardMaterial3D.new()
	d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return d
