## Habitacle de la voiture conduite : les vitres du Car Kit de Kenney (peintes opaques dans
## la palette commune) deviennent de vraies vitres teintées, et l'on voit dedans un
## conducteur (Mini Characters de Kenney, animation « drive ») et un volant qui tourne
## avec les roues. L'intérieur est une boîte sombre dont on ne dessine que les faces
## intérieures (fond et parois du côté opposé à la caméra) : pas de maillage d'intérieur.
extends RefCounted

const PEOPLE := "res://assets/props/people/"
const DRIVERS: Array[String] = ["character-male-a", "character-male-b", "character-male-c", "character-male-d", "character-male-e", "character-female-a", "character-female-b", "character-female-c", "character-female-d", "character-female-e"]
## Pose « drive » des Mini Characters (échelle 1) : hanches à 0,03 m au-dessus de l'origine,
## haut de la tête à 0,625 m (grosse tête de jouet).
const DRIVER_HIPS := 0.03
const DRIVER_TOP := 0.625
## Le volant tourne plus que les roues (démultiplication de la direction, réduite pour rester lisible).
const WHEEL_TURNS := 3.0

## Couleur de la palette Kenney qui sert aux vitres (bleu très pâle, 231,245,255 et ses nuances).
static func is_glass(c: Color) -> bool:
	return c.b > 0.985 and c.r < 0.97 and c.r > 0.8 and c.g > 0.9


## Construit l'habitacle si la voiture a des vitres reconnues. Rend [volant, conducteur] ou [].
static func build(car: VehicleBody3D, rng_seed: int = -1) -> Array:
	var body := car.body_node.get_node_or_null("Carrosserie") as MeshInstance3D
	if body == null:
		return []
	var boxes := _split_glass(body)
	if boxes.is_empty():
		return []
	var glass_box: AABB = boxes[0]
	var side_box: AABB = boxes[1]
	if glass_box.size.x < 0.3 or glass_box.size.z < 0.3:
		return []
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	# Volume de l'habitacle : sous les vitres, un peu en retrait de la tôle.
	var lo := glass_box.position
	var hi := glass_box.end
	# La boîte s'arrête au bas des vitres : au-dessus, on voit à travers l'autre vitre, comme
	# dans une vraie voiture (et elle ne dépasse pas des vitres inclinées).
	var inner := AABB(Vector3(lo.x + 0.06, lo.y - 0.35, lo.z + 0.08), Vector3(hi.x - lo.x - 0.12, 0.37, hi.z - lo.z - 0.16))
	var cabin := MeshInstance3D.new()
	cabin.name = "Habitacle"
	var box := BoxMesh.new()
	box.size = inner.size
	cabin.mesh = box
	cabin.position = inner.get_center()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.42, 0.28, 0.22)
	dark.disable_receive_shadows = true
	dark.roughness = 0.9
	dark.cull_mode = BaseMaterial3D.CULL_FRONT
	cabin.material_override = dark
	# Elle remplace le dessus plein retiré dans l'ombre portée de la voiture (sinon le soleil
	# passerait par les vitres et le bas de caisse, ouvert dessous).
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	car.body_node.add_child(cabin)

	# Conducteur à gauche (+X), derrière le milieu des vitres latérales (bien visible de profil
	# et par la lunette arrière).
	var seat_x := inner.get_center().x + inner.size.x * 0.24
	var seat_z := side_box.get_center().z - side_box.size.z * 0.3 if side_box.size.z > 0.2 else inner.get_center().z
	# Assis sous la ligne des vitres, la tête juste sous le pavillon : on le voit de la tête
	# aux épaules, comme dans une vraie voiture.
	var seat_y := lo.y - 0.22
	var s := clampf((hi.y - 0.07 - seat_y) / DRIVER_TOP, 0.5, 1.4)
	var name: String = DRIVERS[rng.randi() % DRIVERS.size()]
	var driver: Node3D = (load(PEOPLE + name + ".glb") as PackedScene).instantiate()
	driver.name = "Conducteur"
	driver.scale = Vector3.ONE * s
	driver.position = Vector3(seat_x, seat_y - DRIVER_HIPS * s, seat_z)
	car.body_node.add_child(driver)
	_no_shadows(driver)
	var player := driver.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		player.play("drive")

	# Sièges : dossiers sombres derrière les deux places.
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.32, 0.17, 0.12)
	seat_mat.roughness = 0.8
	seat_mat.disable_receive_shadows = true
	for side in [1.0, -1.0]:
		var back := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# Jusqu'aux épaules seulement : vu de derrière, on voit la tête du conducteur.
		bm.size = Vector3(inner.size.x * 0.3, 0.3 * s, 0.07)
		back.mesh = bm
		back.material_override = seat_mat
		back.position = Vector3(inner.get_center().x + side * inner.size.x * 0.24, seat_y + 0.06 * s, seat_z - 0.17 * s)
		back.rotation_degrees.x = -12.0
		car.body_node.add_child(back)
		_no_shadows(back)

	# Volant : devant les mains du conducteur, incliné vers lui.
	var wheel := Node3D.new()
	wheel.name = "Volant"
	wheel.position = Vector3(seat_x, seat_y + 0.2 * s, seat_z + 0.3 * s)
	wheel.rotation_degrees.x = -62.0
	wheel.scale = Vector3.ONE * clampf(s * 1.1, 0.6, 1.3)
	var spin := Node3D.new()
	spin.name = "Rotation"
	spin.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # tourné dans _process
	wheel.add_child(spin)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.07, 0.07)
	black.roughness = 0.5
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.105
	tm.outer_radius = 0.14
	tm.rings = 18
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = black
	spin.add_child(ring)
	# Branches (en T) et moyeu : on voit le volant tourner.
	for a in [0.0, 90.0, 180.0]:
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.12, 0.018, 0.03)
		spoke.mesh = sm
		spoke.material_override = black
		spoke.rotation_degrees.y = a
		spoke.position = Vector3(cos(deg_to_rad(a)), 0.0, -sin(deg_to_rad(a))) * 0.06
		spin.add_child(spoke)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.04
	hm.bottom_radius = 0.04
	hm.height = 0.04
	hm.radial_segments = 10
	hub.mesh = hm
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.45, 0.15)
	hub.material_override = orange
	spin.add_child(hub)
	# Colonne de direction vers le tableau de bord.
	var column := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.025
	cm.height = 0.22
	cm.radial_segments = 6
	column.mesh = cm
	column.material_override = black
	column.position = Vector3(0, -0.11, 0)
	wheel.add_child(column)
	_no_shadows(wheel)
	car.body_node.add_child(wheel)
	return [spin, driver]


## Ni ombre portée ni ombre reçue : sous le pavillon, l'ombre de la voiture rendrait le
## conducteur et le volant tout noirs.
static func _no_shadows(n: Node) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override is BaseMaterial3D:
			var o := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			o.disable_receive_shadows = true
			mi.material_override = o
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.disable_receive_shadows = true
				mi.set_surface_override_material(i, copy)


## Sépare les triangles des vitres (couleur de la palette) dans leur propre surface, en verre
## teinté transparent, et retire le dessus plein de la caisse sous les vitres (les modèles
## du kit sont des volumes fermés : ce « couvercle » cacherait l'intérieur). Rend [boîte de
## toutes les vitres, boîte des vitres latérales] (repère de la caisse), ou [] sans vitres.
static func _split_glass(body: MeshInstance3D) -> Array:
	var src := body.mesh
	var glass_box := AABB()
	var side_box := AABB()
	var found := false
	var side_found := false
	# 1. Triangles de vitre de chaque surface.
	var surfaces := []   # [arrays, idx, flags (1 = vitre)] par surface, ou [arrays] telle quelle
	for s in src.get_surface_count():
		var mat := body.get_surface_override_material(s)
		var arrays := src.surface_get_arrays(s)
		var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture if mat is BaseMaterial3D else null
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		if tex == null or uv == null:
			surfaces.append([arrays, null, null, mat])
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var flags := PackedByteArray()
		flags.resize(idx.size() / 3)
		var w := img.get_width()
		var h := img.get_height()
		for f in idx.size() / 3:
			var a := idx[f * 3]
			var b := idx[f * 3 + 1]
			var c := idx[f * 3 + 2]
			var u: Vector2 = (uv[a] + uv[b] + uv[c]) / 3.0
			if not is_glass(img.get_pixel(posmod(int(u.x * w), w), posmod(int(u.y * h), h))):
				continue
			flags[f] = 1
			var side := absf((verts[b] - verts[a]).cross(verts[c] - verts[a]).normalized().x) > 0.6
			for v in [verts[a], verts[b], verts[c]]:
				glass_box = AABB(v, Vector3.ZERO) if not found else glass_box.expand(v)
				found = true
				if side:
					side_box = AABB(v, Vector3.ZERO) if not side_found else side_box.expand(v)
					side_found = true
		surfaces.append([arrays, idx, flags, mat])
	if not found:
		return []
	# 2. Dessus plein sous les vitres : faces tournées vers le haut, à hauteur du bas des
	# vitres, entièrement dans leur emprise.
	var lo := glass_box.position
	var hi := glass_box.end
	var out := ArrayMesh.new()
	var mats: Array[Material] = []
	var glass_arrays := []
	for entry in surfaces:
		var arrays: Array = entry[0]
		if entry[1] == null:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mats.append(entry[3])
			continue
		var idx: PackedInt32Array = entry[1]
		var flags: PackedByteArray = entry[2]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var keep := PackedInt32Array()
		var glass := PackedInt32Array()
		for f in flags.size():
			var tri := [idx[f * 3], idx[f * 3 + 1], idx[f * 3 + 2]]
			if flags[f] == 1:
				glass.append_array(tri)
				continue
			var p0 := verts[tri[0]]
			var p1 := verts[tri[1]]
			var p2 := verts[tri[2]]
			# Sens des faces de Godot (horaire) : la normale vers l'extérieur est l'opposé du
			# produit vectoriel.
			var n := -(p1 - p0).cross(p2 - p0).normalized()
			var cy := (p0.y + p1.y + p2.y) / 3.0
			var cx := (p0.x + p1.x + p2.x) / 3.0
			var cz := (p0.z + p1.z + p2.z) / 3.0
			var inside := cx > lo.x and cx < hi.x and cz > lo.z and cz < hi.z
			if inside and n.y > 0.7 and cy > lo.y - 0.25 and cy < lo.y + 0.15:
				continue
			keep.append_array(tri)
		if not keep.is_empty():
			var ka := arrays.duplicate()
			ka[Mesh.ARRAY_INDEX] = keep
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ka)
			mats.append(entry[3])
		if not glass.is_empty():
			var ga := arrays.duplicate()
			ga[Mesh.ARRAY_INDEX] = glass
			glass_arrays.append(ga)
	# Les vitres en dernier (objets transparents). Peu de reflet : sous la caméra plongeante,
	# un vrai reflet du ciel rendrait la vitre grise et opaque ; on veut voir le conducteur.
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.12, 0.15, 0.18, 0.2)
	glass_mat.roughness = 0.6
	glass_mat.metallic_specular = 0.1
	glass_mat.cull_mode = BaseMaterial3D.CULL_BACK
	for ga in glass_arrays:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ga)
		mats.append(glass_mat)
	body.mesh = out
	for i in mats.size():
		body.set_surface_override_material(i, mats[i])
	return [glass_box, side_box]
