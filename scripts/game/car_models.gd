## Voitures du catalogue montrées avec les modèles du « Car Kit » de Kenney (CC0,
## assets/cars/kenney/) : chaque carrosserie du catalogue prend le modèle le plus proche,
## repeint à la couleur de la voiture. Le kit colore tout par une palette commune
## (colormap.png, cases de 32 × 128 pixels en dégradé) : on repère la case de la
## carrosserie de chaque modèle (celle qui couvre le plus de surface parmi les couleurs
## vives) et on la remplace, dans une copie de la palette, par la couleur voulue en gardant
## son dégradé. (L'ancien « Low Poly Car Set » reste pour la balade sans partie et les tests.)
## Sert au garage (maillage fusionné, peinture brillante), à la balade (voiture conduite,
## voitures à spotter) et à la circulation (life.gd).
extends RefCounted

const Car = preload("res://scripts/balade/car.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const MeshMerge = preload("res://scripts/balade/mesh_merge.gd")

## Carrosserie du catalogue -> modèle du pack.
const KIT_BY_BODY := {
	"citadine": "hatchback-sports", "compacte": "hatchback-sports", "berline": "sedan",
	"break": "sedan", "4x4": "suv", "suv": "suv-luxury", "monospace": "van", "combi": "van",
	"fourgon": "van", "coupe": "sedan-sports", "fastback": "sedan-sports",
	"sportback": "sedan-sports", "cabriolet": "sedan-sports", "roadster": "sedan-sports",
	"pickup": "truck", "supercar": "sedan-sports",
}
const CELL := Vector2i(32, 128)

static var _oriented := {}
static var _cells := {}
static var _palettes := {}
static var _colormap: Image


## Modèle du kit pour une voiture du catalogue (hypercars mythiques : bolide de course).
static func kit_for(model_id: String) -> String:
	var m := Catalog.get_car(model_id)
	if m.is_empty():
		return "sedan"
	var kit: String = KIT_BY_BODY.get(String(m["body"]), "sedan")
	if String(m["body"]) == "supercar" and int(m["rarity"]) >= 5:
		kit = "race-future"
	return kit


static func _palette_image() -> Image:
	if _colormap == null:
		var tex: Texture2D = load("res://assets/cars/kenney/Textures/colormap.png")
		_colormap = tex.get_image()
		if _colormap.is_compressed():
			_colormap.decompress()
		_colormap.convert(Image.FORMAT_RGBA8)
	return _colormap


## Case de la palette qui peint la carrosserie d'un modèle du kit.
static func paint_cell(kit: String) -> Rect2i:
	if _cells.has(kit):
		return _cells[kit]
	var img := _palette_image()
	var scene: Node3D = (load(Car.model_path(kit)) as PackedScene).instantiate()
	var weight := {}
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if String(mi.name).begins_with("wheel") or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n := idx.size() if not idx.is_empty() else v.size()
			var k := 0
			while k + 2 < n:
				var a := idx[k] if not idx.is_empty() else k
				var b := idx[k + 1] if not idx.is_empty() else k + 1
				var c := idx[k + 2] if not idx.is_empty() else k + 2
				var area := (v[b] - v[a]).cross(v[c] - v[a]).length()
				var u := (uv[a] + uv[b] + uv[c]) / 3.0
				var cell := Vector2i(clampi(int(u.x * img.get_width()) / CELL.x, 0, img.get_width() / CELL.x - 1), clampi(int(u.y * img.get_height()) / CELL.y, 0, img.get_height() / CELL.y - 1))
				weight[cell] = float(weight.get(cell, 0.0)) + area
				k += 3
	scene.free()
	var best := Vector2i(-1, -1)
	var bw := 0.0
	for cell in weight:
		var col := img.get_pixel(cell.x * CELL.x + CELL.x / 2, cell.y * CELL.y + CELL.y / 2)
		if col.s < 0.3 or col.v < 0.3:
			continue
		if float(weight[cell]) > bw:
			bw = weight[cell]
			best = cell
	var r := Rect2i(best * CELL, CELL) if best.x >= 0 else Rect2i()
	_cells[kit] = r
	return r


## Palette où la case de la carrosserie prend la couleur voulue (dégradé gardé).
static func palette(cell: Rect2i, paint: Color) -> Texture2D:
	var key := "%s_%s" % [cell, paint.to_html(false)]
	if _palettes.has(key):
		return _palettes[key]
	var img := _palette_image().duplicate() as Image
	if cell.size.x > 0:
		var ref := img.get_pixel(cell.position.x + cell.size.x / 2, cell.position.y + cell.size.y / 2).get_luminance()
		for y in range(cell.position.y, cell.end.y):
			for x in range(cell.position.x, cell.end.x):
				var p := img.get_pixel(x, y)
				var f := clampf(p.get_luminance() / maxf(ref, 0.05), 0.4, 1.6)
				img.set_pixel(x, y, Color(paint.r * f, paint.g * f, paint.b * f, p.a).clamp())
	var tex := ImageTexture.create_from_image(img)
	_palettes[key] = tex
	return tex


static func _is_palette(mat: Material) -> bool:
	return mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null and (mat as BaseMaterial3D).albedo_texture.resource_path.ends_with("colormap.png")


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
	var scene: Node3D = (load(Car.model_path(kit)) as PackedScene).instantiate()
	var kenney := Car.KENNEY.has(kit)
	var node: Node3D = scene if kenney else scene.find_child(String(Car.TOON[kit][0]), true, false)
	var wheels: Array[Vector3] = []
	for k in 4:
		for c in node.find_children("*", "Node3D", true, false):
			var nm := String(c.name)
			if (kenney and nm == Car.WHEEL_NAMES[k][0]) or (not kenney and nm.contains(Car.WHEEL_CODES[k])):
				wheels.append(Car._center(c, node))
				break
	var paint := main_paint(node.find_children("*", "MeshInstance3D", true, false))
	var paint_name := paint.resource_name if paint else ""
	var cell := paint_cell(kit) if kenney else Rect2i()
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
	var s: float = Car.length_of(kit) / maxf(rot_box.size.z, 0.01)
	var xf := Transform3D(basis.scaled(Vector3.ONE * s), Vector3.ZERO)
	var placed := xf * box
	xf.origin = Vector3(-placed.get_center().x, -placed.position.y, -placed.get_center().z)
	var v := [mesh, xf, placed.size / 2.0, paint_surface, cell]
	_oriented[kit] = v
	return v


## Repeint une voiture déjà construite (voiture conduite en balade) : la peinture la plus
## étendue prend la couleur voulue (kit Kenney : la case de la carrosserie de la palette).
static func repaint(root: Node3D, paint: Color, kit := "") -> void:
	if Car.KENNEY.has(kit):
		var tex := palette(paint_cell(kit), paint)
		for m in root.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(si)
				if _is_palette(mat):
					var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_texture = tex
					mi.set_surface_override_material(si, d)
		return
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
		if (v[4] as Rect2i).size.x > 0 and _is_palette(src):
			# Kit Kenney : palette repeinte, vernis brillant.
			m.albedo_texture = palette(v[4], paint)
			m.roughness = 0.28
			m.metallic = 0.25
			m.metallic_specular = 0.75
		elif si == int(v[3]):
			m.albedo_texture = null
			m.albedo_color = paint
			m.roughness = 0.22
			m.metallic = 0.35
			m.metallic_specular = 0.8
		mi.set_surface_override_material(si, m)
	return mi
