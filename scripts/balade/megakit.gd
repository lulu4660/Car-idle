## Rochers et galets du « Stylized Nature MegaKit » de Quaternius (CC0,
## assets/props/megakit/) : formes douces et soignées, plus belles que les rochers du kit
## Kenney, pour à peine plus de triangles. Leur texture peinte est reportée dans la
## couleur de chaque sommet (aucune texture lue en jeu : même coût que la végétation),
## ramenée vers la palette pastel de la balade en gardant ses nuances (dessus clair,
## creux sombres, un peu de mousse).
extends RefCounted

const DIR := "res://assets/props/megakit/"
## Couleur visée des rochers (beige rosé pastel), et part de la teinte d'origine gardée.
const ROCK_TINT := Color(0.58, 0.48, 0.43)
const KEEP_HUE := 0.3

static var _images := {}


static func _image(tex: Texture2D) -> Image:
	if _images.has(tex):
		return _images[tex]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	_images[tex] = img
	return img


## Maillage d'un seul tenant, couleur par sommet, sans texture : [maillage, hauteur, bas].
static func vertex_colored(name: String, tint := ROCK_TINT) -> Array:
	var root: Node3D = (load(DIR + name + ".gltf") as PackedScene).instantiate()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_i := PackedInt32Array()
	var lo := 1e9
	var hi := -1e9
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != root:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var img: Image = _image(mat.albedo_texture) if mat and mat.albedo_texture else null
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var base := out_v.size()
			for i in verts.size():
				var v := xf * verts[i]
				out_v.append(v)
				out_n.append((xf.basis * normals[i]).normalized())
				var c := tint
				if img and i < uvs.size():
					var uv := uvs[i]
					var px := Vector2i(posmod(int(uv.x * img.get_width()), img.get_width()), posmod(int(uv.y * img.get_height()), img.get_height()))
					var t := img.get_pixelv(px)
					# Nuances de la peinture d'origine, dans la palette de la balade.
					var l := clampf(t.get_luminance() / 0.32, 0.55, 1.3)
					c = (tint * l).lerp(t * 1.1, KEEP_HUE)
					c.a = 1.0
				out_c.append(c)
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i in verts.size():
					out_i.append(base + i)
			else:
				for i in idx:
					out_i.append(base + i)
	root.free()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = out_v
	arr[Mesh.ARRAY_NORMAL] = out_n
	arr[Mesh.ARRAY_COLOR] = out_c
	arr[Mesh.ARRAY_INDEX] = out_i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return [mesh, hi - lo, lo]


## Même maillage, recentré et ramené à un rocher d'environ 1 m de large posé à y ≈ 0
## (le format des grands rochers de world_builder).
static func unit_rock(name: String) -> ArrayMesh:
	var p := vertex_colored(name)
	var mesh: ArrayMesh = p[0]
	var box := mesh.get_aabb()
	var s := 1.1 / maxf(box.size.x, box.size.z)
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(-box.get_center().x * s, -box.position.y * s - 0.08, -box.get_center().z * s))
	var st := SurfaceTool.new()
	st.append_from(mesh, 0, xf)
	return st.commit()
