## Végétation et rochers de la balade, en low poly (Nature Kit de Kenney, CC0) :
## - forêt de pins sur la terre, en massifs, avec des couloirs libres pour rouler ;
## - cactus, buissons et rochers épars dans les dunes ;
## - palmiers en haut de la plage.
## Pour rester fluide sur iPhone (pas d'instanciation automatique sur le web) : chaque modèle
## est réduit à une seule surface, ses couleurs rangées dans les sommets (un seul matériau mat
## pour tout), et dessiné en MultiMesh par case de 96 m : un appel de dessin par modèle et par
## case. Couleurs mates (pas de reflet), choisies dans la palette de la balade.
## Troncs, rochers et cactus arrêtent la voiture (formes simples) ; les buissons non.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")
const Town = preload("res://scripts/balade/town.gd")

const DIR := "res://assets/props/nature/"
const CELL := 96.0
const RANGE := 170.0

## Couleur de chaque matériau du kit (par nom), dans la palette de la balade.
const PALETTE := {
	"leafsDark": Color(0.29, 0.43, 0.27), "leafsGreen": Color(0.40, 0.55, 0.30),
	"grass": Color(0.47, 0.58, 0.31), "dirt": Color(0.72, 0.57, 0.47),
	"woodBark": Color(0.47, 0.33, 0.24), "woodBarkDark": Color(0.38, 0.27, 0.21),
	"_defaultMat": Color(0.66, 0.55, 0.48),
}
## Modèle : hauteur visée (m), rayon de collision du pied (0 = traversable), variation de taille.
const KINDS := {
	"tree_pineDefaultA": [9.0, 0.35, 0.3], "tree_pineDefaultB": [10.0, 0.35, 0.3],
	"tree_pineRoundA": [8.0, 0.35, 0.3], "tree_pineRoundC": [8.5, 0.35, 0.3],
	"tree_pineTallA": [12.0, 0.35, 0.25], "tree_pineTallC": [13.0, 0.35, 0.25],
	"tree_pineSmallA": [5.0, 0.25, 0.3],
	"tree_palmTall": [8.0, 0.3, 0.2], "tree_palmBend": [7.0, 0.3, 0.2], "tree_palmDetailedTall": [9.0, 0.3, 0.2],
	"plant_bushLarge": [1.6, 0.0, 0.4], "plant_bushDetailed": [1.1, 0.0, 0.4], "plant_bush": [0.9, 0.0, 0.4],
	"rock_largeA": [2.2, 1.1, 0.5], "rock_largeC": [1.8, 1.0, 0.5], "rock_largeE": [2.6, 1.2, 0.5],
	"rock_tallB": [4.5, 1.2, 0.3], "rock_tallE": [3.5, 1.0, 0.3], "rock_smallC": [0.6, 0.0, 0.5],
	"cactus_tall": [3.4, 0.3, 0.3], "cactus_short": [1.6, 0.3, 0.3],
}

var data: RefCounted
var _proto := {}        # modèle -> [maillage, hauteur, bas]
var _material: StandardMaterial3D
var _cells := {}        # [case, modèle] -> Array[Transform3D]
var _body: StaticBody3D
var count := 0


func build(world_data: RefCounted) -> void:
	data = world_data
	_body = StaticBody3D.new()
	_body.name = "Arbres"
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_forest(rng)
	_dunes(rng)
	_beach(rng)
	_commit()
	# Le corps n'entre dans la scène qu'une fois toutes ses formes posées (sinon la physique
	# le reconstruit à chaque forme ajoutée).
	add_child(_body)


## Clairières dans la forêt (x, z, rayon) : de grands espaces pour glisser.
const CLEARINGS := [Vector3(0.0, -300.0, 110.0), Vector3(-60.0, 200.0, 85.0), Vector3(40.0, 20.0, 60.0)]


## Couloirs de rallye à travers la forêt (pistes sinueuses d'ouest en est).
static func corridor_distance(x: float, z: float) -> float:
	var best := 1e9
	for base in [-330.0, -110.0, 110.0, 330.0]:
		var cz: float = base + 55.0 * sin(x / 70.0 + base) + 25.0 * sin(x / 23.0 + base * 0.1)
		best = minf(best, absf(z - cz))
	return best


func _forest(rng: RandomNumberGenerator) -> void:
	# Surtout les pins les plus légers (136 à 156 sommets), quelques ronds pour varier.
	var pines := ["tree_pineTallA", "tree_pineTallA", "tree_pineTallC", "tree_pineTallC", "tree_pineRoundA", "tree_pineDefaultA"]
	var x0 := WL.CITY_END + 35.0
	var x1 := WL.DIRT_END + 25.0
	for i in 26000:
		var x := rng.randf_range(x0, x1)
		var z := rng.randf_range(-WL.SIZE / 2.0 + 30.0, WL.SIZE / 2.0 - 30.0)
		# Massifs : densité selon un bruit, plus clairsemé en lisière des dunes.
		var dense := WL.fbm(x / 140.0 + 7.0, z / 140.0 - 3.0)
		var edge := smoothstep(x1, x1 - 60.0, x)
		if dense * edge < rng.randf_range(0.30, 0.48):
			continue
		if corridor_distance(x, z) < 13.0:
			continue
		var open := false
		for c in CLEARINGS:
			if Vector2(x - c.x, z - c.y).length() < c.z * rng.randf_range(0.85, 1.0):
				open = true
		if open:
			continue
		if rng.randf() < 0.12:
			_add("plant_bushLarge", x, z, rng)
		elif rng.randf() < 0.04:
			_add(["rock_largeA", "rock_largeC", "rock_tallE"][rng.randi() % 3], x, z, rng)
		else:
			_add(pines[rng.randi() % pines.size()], x, z, rng)


func _dunes(rng: RandomNumberGenerator) -> void:
	var kinds := ["cactus_tall", "cactus_short", "cactus_short", "plant_bush", "plant_bushDetailed", "rock_largeA", "rock_largeE", "rock_tallB", "rock_smallC", "rock_smallC"]
	for i in 700:
		var x := rng.randf_range(WL.DIRT_END + 15.0, WL.DUNES_END - 15.0)
		var z := rng.randf_range(-WL.SIZE / 2.0 + 30.0, WL.SIZE / 2.0 - 30.0)
		if WL.fbm(x / 60.0 - 11.0, z / 60.0 + 4.0) < 0.5:
			continue
		if Vector2(x - WL.SPAWN_X, z - WL.SPAWN_Z).length() < 35.0:
			continue
		var k: String = kinds[rng.randi() % kinds.size()]
		_add(k, x, z, rng)
		# Petits groupes : un ou deux voisins plus petits.
		if k.begins_with("rock") or k.begins_with("cactus"):
			for j in rng.randi() % 3:
				_add("rock_smallC" if rng.randf() < 0.6 else "plant_bush", x + rng.randf_range(-3.0, 3.0), z + rng.randf_range(-3.0, 3.0), rng)


func _beach(rng: RandomNumberGenerator) -> void:
	var palms := ["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall"]
	var z := -WL.SIZE / 2.0 + 30.0
	while z < WL.SIZE / 2.0 - 30.0:
		z += rng.randf_range(10.0, 40.0)
		var x := WL.DUNES_END + WL.shore_offset(z) + rng.randf_range(-25.0, 5.0)
		if Vector2(x - WL.SPAWN_X, z - WL.SPAWN_Z).length() < 30.0:
			continue
		var n := 1 + rng.randi() % 3
		for i in n:
			_add(palms[rng.randi() % palms.size()], x + rng.randf_range(-5.0, 5.0), z + rng.randf_range(-5.0, 5.0), rng)


## Ajoute un objet : son maillage rejoint celui de sa case, son pied une forme de collision.
func _add(kind: String, x: float, z: float, rng: RandomNumberGenerator) -> void:
	var ground: float = data.height_at(x, z)
	if ground < WL.SEA_LEVEL + 0.6:
		return
	# Rien sur la piste ni sur ses bas-côtés, ni dans les fermes.
	if data.road_distance(x, z) < WL.ROAD_HALF + 3.5 or Town.in_farm(x, z, 5.0):
		return
	var p: Array = _prototype(kind)
	var spec: Array = KINDS[kind]
	var s: float = float(spec[0]) / maxf(p[1], 0.01) * (1.0 + rng.randf_range(-1.0, 1.0) * float(spec[2]))
	# Légèrement enfoncé : pas de pied qui flotte sur une pente.
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, ground - 0.15 - p[2] * s, z))
	var key := [Vector2i(floori(x / CELL), floori(z / CELL)), kind]
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(xf)
	count += 1
	var r: float = float(spec[1]) * s / (float(spec[0]) / maxf(p[1], 0.01))
	if r > 0.0:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(x, ground + 1.2, z)
		_body.add_child(cs)


## Le modèle en une seule surface (couleur du matériau dans chaque sommet), sa hauteur, son bas.
func _prototype(kind: String) -> Array:
	if _proto.has(kind):
		return _proto[kind]
	var root: Node3D = (load(DIR + kind + ".glb") as PackedScene).instantiate()
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
			var mat := mi.mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else "_defaultMat"
			var col: Color = PALETTE.get(nm, PALETTE["_defaultMat"])
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var base := out_v.size()
			for i in verts.size():
				var v := xf * verts[i]
				out_v.append(v)
				out_n.append((xf.basis * normals[i]).normalized())
				out_c.append(col)
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
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
	var p := [mesh, hi - lo, lo]
	_proto[kind] = p
	return p


func _commit() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 1.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for key in _cells:
		var cell: Vector2i = key[0]
		var list: Array = _cells[key]
		var origin := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _proto[key[1]][0]
		mm.instance_count = list.size()
		var aabb := AABB()
		for i in list.size():
			var xf: Transform3D = list[i]
			xf.origin -= origin
			mm.set_instance_transform(i, xf)
			var b := xf * (mm.mesh as Mesh).get_aabb()
			aabb = b if i == 0 else aabb.merge(b)
		mm.custom_aabb = aabb
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.position = origin
		mmi.visibility_range_end = RANGE
		add_child(mmi)
	_cells.clear()
