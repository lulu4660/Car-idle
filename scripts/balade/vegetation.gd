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

const FarFade = preload("res://scripts/balade/far_fade.gd")

const WL = preload("res://scripts/core/world_layout.gd")
const Town = preload("res://scripts/balade/town.gd")
const Megakit = preload("res://scripts/balade/megakit.gd")
## Rochers du kit Kenney remplacés par ceux du Stylized Nature MegaKit (même place, même
## taille visée ; plus beaux, toujours en couleur par sommet).
const MEGAKIT_ROCKS := {
	"rock_largeA": "Rock_Medium_1", "rock_largeC": "Rock_Medium_2", "rock_largeE": "Rock_Medium_3",
	"rock_tallB": "Rock_Medium_3", "rock_tallE": "Rock_Medium_1", "rock_smallC": "Pebble_Round_1",
}

const DIR := "res://assets/props/nature/"
const CELL := 96.0
const RANGE := 150.0
## Niveaux de détail des arbres : modèle jusqu'à `LOD_NEAR` (centre de la case), imposteur
## au-delà jusqu'à `IMP_RANGE` (fondu en distance au bout, dans la brume) ; passage en
## `LOD_FADE_TIME` secondes. Les forêts se voient ainsi jusqu'à l'horizon pour deux triangles
## par arbre.
const LOD_NEAR := 125.0
## Seuil en cours (outils : 0 = tout en imposteurs, pour les comparer aux modèles).
var lod_near := LOD_NEAR
const LOD_HYST := 10.0
const LOD_FADE_TIME := 0.25
const IMP_RANGE := 420.0

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
var _material: ShaderMaterial
var _tree_material: ShaderMaterial
var impostors: Node
var _lod_cells := []    # par case d'arbres : centre, MultiMesh modèle et imposteur, état
var lod_freeze := false
## Arbres dessinés deux fois (pendant un fondu), pour la vue de débogage.
var twice := 0
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
	# Tirage à part : le reste du décor garde exactement les mêmes places.
	var rng_hills := RandomNumberGenerator.new()
	rng_hills.seed = 78
	_foothills(rng_hills)
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
		# Limite des arbres : rien au-dessus de 22 m au-dessus de la vallée (roche, neige).
		if data.height_at(x, z) > WL.GROUND_LEVEL + 22.0:
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


## Contreforts des montagnes : forêt de pins côté vallée verte (jusqu'à la limite des
## arbres), rochers épars côté désert. Pas de collision (pentes où l'on ne roule guère) :
## la physique reste légère.
func _foothills(rng: RandomNumberGenerator) -> void:
	var pines := ["tree_pineTallA", "tree_pineTallC", "tree_pineRoundA", "tree_pineDefaultA"]
	var half := WL.SIZE / 2.0
	for i in 14000:
		var x := rng.randf_range(WL.CITY_START - 90.0, WL.BEACH_END)
		var z := rng.randf_range(-half + 8.0, half - 8.0)
		var m := WL.mountain_factor(x, z)
		if m < 0.03 or m > 0.75:
			continue
		var g: float = data.height_at(x, z)
		if g > WL.GROUND_LEVEL + 22.0 + 6.0 * WL.fbm(x / 30.0, z / 30.0):
			continue
		var green := x < WL.DIRT_END + 30.0 + 40.0 * (WL.fbm(x / 80.0, z / 80.0) - 0.5)
		if green:
			if WL.fbm(x / 70.0 - 9.0, z / 70.0 + 2.0) * (1.0 - m * 0.6) < rng.randf_range(0.28, 0.42):
				continue
			_add(pines[rng.randi() % pines.size()], x, z, rng, false)
		elif rng.randf() < 0.18:
			_add(["rock_largeA", "rock_largeC", "rock_tallE", "rock_tallB"][rng.randi() % 4], x, z, rng, false)


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
func _add(kind: String, x: float, z: float, rng: RandomNumberGenerator, collide := true) -> void:
	var ground: float = data.height_at(x, z)
	if ground < WL.SEA_LEVEL + 0.6:
		return
	# Ligne droite de départ (vers l'ouest depuis la plage) toujours dégagée.
	if absf(z - WL.SPAWN_Z) < 9.0 and x > WL.SPAWN_X - 70.0 and x < WL.SPAWN_X + 12.0:
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
	if r > 0.0 and collide:
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
	if MEGAKIT_ROCKS.has(kind):
		_proto[kind] = Megakit.vertex_colored(MEGAKIT_ROCKS[kind])
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
	# Shader léger : couleur par sommet, mat, et lumières de nuit (réverbères, phares).
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/vegetation.gdshader")
	_material.set_shader_parameter("night_light_tex", load("res://assets/balade/lights.png"))
	# Arbres à imposteur : même shader, sans fondu en distance (c'est le niveau de détail
	# qui les remplace au loin).
	_tree_material = _material.duplicate() as ShaderMaterial
	var lod_kinds := {}
	for key in _cells:
		var kind: String = key[1]
		if _has_impostor(kind) and not lod_kinds.has(kind):
			var spec: Array = KINDS[kind]
			lod_kinds[kind] = [_proto[kind][0], float(spec[0]) / maxf(_proto[kind][1], 0.01)]
	impostors = load("res://scripts/balade/impostors.gd").new()
	impostors.name = "Imposteurs"
	add_child(impostors)
	impostors.prepare(lod_kinds)
	var by_cell := {}
	for key in _cells:
		var cell: Vector2i = key[0]
		var kind: String = key[1]
		var list: Array = _cells[key]
		var origin := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _proto[kind][0]
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
		mmi.position = origin
		if not lod_kinds.has(kind):
			mmi.material_override = _material
			# Fondu en distance (pas de rochers qui surgissent) ; la case reste affichée un peu plus loin.
			FarFade.setup(mmi, RANGE, CELL * FarFade.CELL_MARGIN)
			add_child(mmi)
			continue
		# Un matériau par case : son fondu de niveau de détail lui est propre (les « uniformes
		# par instance » du moteur sont limités à 4 096 et il y a trop de cases).
		if not by_cell.has(cell):
			by_cell[cell] = {"center": Vector2(origin.x, origin.z), "near": [], "imp": [], "mats": [], "count": 0, "lod": -1, "t": 1.0}
			by_cell[cell]["near_mat"] = _tree_material.duplicate()
			by_cell[cell]["mats"].append(by_cell[cell]["near_mat"])
		mmi.material_override = by_cell[cell]["near_mat"]
		add_child(mmi)
		# Imposteurs de la case : mêmes places, deux triangles chacun.
		var im := MultiMesh.new()
		im.transform_format = MultiMesh.TRANSFORM_3D
		im.mesh = _impostor_quad()
		im.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i]
			xf.origin -= origin
			im.set_instance_transform(i, xf)
		im.custom_aabb = aabb.grow(aabb.size.y * 0.5)
		var imi := MultiMeshInstance3D.new()
		imi.multimesh = im
		imi.position = origin
		var imat: ShaderMaterial = impostors.materials[kind].duplicate()
		impostors.copies[kind].append(imat)
		by_cell[cell]["mats"].append(imat)
		imi.material_override = imat
		imi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		FarFade.setup(imi, IMP_RANGE, CELL * FarFade.CELL_MARGIN, 80.0)
		add_child(imi)
		by_cell[cell]["near"].append(mmi)
		by_cell[cell]["imp"].append(imi)
		by_cell[cell]["count"] += list.size()
	_lod_cells = by_cell.values()
	_cells.clear()


static func _has_impostor(kind: String) -> bool:
	return kind.begins_with("tree_") or kind == "cactus_tall"


var _quad: QuadMesh
func _impostor_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad


# ------------------------------------------------------------------ niveaux de détail

## Chaque case d'arbres passe du modèle (LOD0) à l'imposteur quand son centre s'éloigne de
## la caméra au-delà de `LOD_NEAR` (et revient en deçà, avec un écart pour ne pas hésiter).
## Le passage est un fondu minuté de `LOD_FADE_TIME` (comme dans les jeux récents) : les deux
## versions ne sont dessinées ensemble que pendant ce fondu, jamais tant que la caméra
## stationne près du seuil (un fondu selon la distance les dessinerait deux fois tout ce temps).
func _process(delta: float) -> void:
	if lod_freeze or _lod_cells.is_empty() or not impostors.done:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := Vector2(cam.global_position.x, cam.global_position.z)
	twice = 0
	for c in _lod_cells:
		var d: float = p.distance_to(c["center"])
		var want: int = c["lod"]
		if d > lod_near + LOD_HYST:
			want = 1
		elif d < lod_near - LOD_HYST:
			want = 0
		elif want < 0:
			want = 0 if d < lod_near else 1
		if want != c["lod"]:
			# Premier tour : tout de suite ; ensuite, fondu.
			c["t"] = 1.0 if c["lod"] < 0 else 0.0
			c["lod"] = want
			for n in c["near"] + c["imp"]:
				(n as Node3D).visible = true
		if c["t"] < 1.0 or c.get("dirty", true):
			c["t"] = minf(1.0, c["t"] + delta / LOD_FADE_TIME)
			var k: float = smoothstep(0.0, 1.0, c["t"])
			var share := k if c["lod"] == 1 else 1.0 - k
			for m in c["mats"]:
				(m as ShaderMaterial).set_shader_parameter("lod_fade", share)
			c["dirty"] = c["t"] < 1.0
			if c["t"] >= 1.0:
				# Fondu fini : une seule version reste dessinée.
				for n in c["near"]:
					(n as Node3D).visible = c["lod"] == 0
				for n in c["imp"]:
					(n as Node3D).visible = c["lod"] == 1
			else:
				twice += int(c["count"])


## Préchauffage (balade.gd) : les deux versions affichées pour compiler tous les shaders.
func set_lod_freeze(on: bool) -> void:
	lod_freeze = on
	for c in _lod_cells:
		for n in c["near"] + c["imp"]:
			(n as Node3D).visible = true
		if not on:
			c["lod"] = -1
			c["dirty"] = true
