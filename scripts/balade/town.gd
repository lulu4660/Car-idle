## La part « habitée » de la carte, d'ouest en est, pour une carte cohérente :
## - la ville : centre d'affaires (tours), quartier commerçant, banlieue pavillonnaire
##   (maisons, clôtures, arbres) et quelques parcs ; Kenney City Kit Commercial et
##   Suburban (CC0) ;
## - les fermes entre la ville et la forêt : champs, clôtures, ferme ;
## - la plage aménagée : parasols, serviettes, cabanes.
## Comme la végétation : chaque modèle fusionné en un seul maillage, dessiné en MultiMesh
## par case de 120 m (un appel de dessin par modèle et par case), collisions simples.
extends Node3D

const FarFade = preload("res://scripts/balade/far_fade.gd")

const WL = preload("res://scripts/core/world_layout.gd")
const MeshMerge = preload("res://scripts/balade/mesh_merge.gd")

const CELL := 120.0
const RANGE := 180.0
const CITY := "res://assets/props/city/"
const SUBURB := "res://assets/props/suburb/"
const NATURE := "res://assets/props/nature/"
const BUILDING_SHADER = preload("res://shaders/building.gdshader")

## Modèles par quartier : 6 par quartier au plus (chaque modèle coûte un appel de dessin par
## case de 120 m ; avec moins de modèles, la ville reste fluide et chaque quartier a son style).
const TOWERS := ["building-skyscraper-a", "building-skyscraper-c", "building-skyscraper-e"]
const DOWNTOWN_SHOPS := ["building-h", "building-k", "building-n"]
const SHOPS := ["building-a", "building-c", "building-d", "building-f", "building-g", "building-j"]
const HOUSES := ["building-type-a", "building-type-c", "building-type-f", "building-type-i", "building-type-m", "building-type-p"]

## Fermes (x, z, largeur, profondeur) : la forêt ne pousse pas dessus (vegetation.gd).
const FARMS := [Rect2(-165.0, 140.0, 95.0, 130.0), Rect2(-160.0, -330.0, 85.0, 110.0), Rect2(-165.0, -40.0, 70.0, 80.0)]

var data: RefCounted
var _proto := {}   # chemin -> [maillage, boîte]
var _cells := {}   # [case, chemin] -> Array[Transform3D]
var _body: StaticBody3D
var count := 0
## Places de stationnement le long des rues, pour la circulation (life.gd) : [position, cap].
var parking: Array = []
## Bords de trottoirs pour les piétons : [départ, arrivée].
var sidewalks: Array = []
## Plage : places des parasols, pour les vacanciers.
var beach_spots: Array[Vector3] = []


func build(world_data: RefCounted) -> void:
	data = world_data
	_body = StaticBody3D.new()
	_body.name = "Batiments"
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_city(rng)
	_farms(rng)
	_beach(rng)
	_commit()
	add_child(_body)


static func in_farm(x: float, z: float, margin := 0.0) -> bool:
	for r in FARMS:
		if (r as Rect2).grow(margin).has_point(Vector2(x, z)):
			return true
	return false


# ------------------------------------------------------------------ ville

func _city(rng: RandomNumberGenerator) -> void:
	var half := WL.SIZE / 2.0
	# La ville reste dans la vallée, au pied des montagnes.
	var bx := WL.CITY_START
	while bx + WL.BLOCK_SIZE <= WL.CITY_END + 1.0:
		var bz := -WL.VALLEY_HALF
		while bz + WL.BLOCK_SIZE <= WL.VALLEY_HALF:
			var x0 := bx + WL.STREET_WIDTH
			var z0 := bz + WL.STREET_WIDTH
			var w := WL.BLOCK_SIZE - WL.STREET_WIDTH
			var district := 0 if bx < -340.0 else (1 if bx < -260.0 else 2)
			if rng.randf() < 0.1:
				_park(x0, z0, w, rng)
			else:
				for i in 2:
					for j in 2:
						var c := Vector2(x0 + w * (0.25 + 0.5 * i), z0 + w * (0.25 + 0.5 * j))
						match district:
							0: _building(CITY + (TOWERS[rng.randi() % TOWERS.size()] if rng.randf() < 0.55 else DOWNTOWN_SHOPS[rng.randi() % DOWNTOWN_SHOPS.size()]), c, w * 0.42, rng, 1.0 + rng.randf() * 0.6)
							1: _building(CITY + SHOPS[rng.randi() % SHOPS.size()], c, w * 0.42, rng, 1.0)
							2: _house(c, w * 0.5, rng)
			# Trottoirs (bord du pâté) et places de stationnement le long des rues.
			var e := 1.2
			var corners := [Vector2(x0 - e, z0 - e), Vector2(x0 + w + e, z0 - e), Vector2(x0 + w + e, z0 + w + e), Vector2(x0 - e, z0 + w + e)]
			for k in 4:
				sidewalks.append([corners[k], corners[(k + 1) % 4]])
			if rng.randf() < 0.6:
				var side := rng.randi() % 4
				var a: Vector2 = corners[side]
				var b: Vector2 = corners[(side + 1) % 4]
				var out := (b - a).normalized().orthogonal() * -2.6
				for n in rng.randi_range(1, 3):
					var p := a.lerp(b, rng.randf_range(0.15, 0.85)) + out
					# Une place sur deux occupée (moins d'objets à dessiner).
					if rng.randf() < 0.5:
						continue
					parking.append([Vector3(p.x, WL.GROUND_LEVEL, p.y), atan2((b - a).x, (b - a).y)])
			bz += WL.BLOCK_SIZE
		bx += WL.BLOCK_SIZE


func _building(path: String, c: Vector2, size: float, rng: RandomNumberGenerator, tall: float) -> void:
	var p: Array = _prototype(path)
	var box: AABB = p[1]
	var s := size / maxf(box.size.x, box.size.z)
	var yaw := float(rng.randi() % 4) * PI * 0.5
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * tall, s))
	_add(path, Transform3D(basis, Vector3(c.x, WL.GROUND_LEVEL, c.y)))
	_box(Vector3(c.x, WL.GROUND_LEVEL, c.y), Vector3(box.size.x * s, box.size.y * s * tall, box.size.z * s), yaw)


func _house(c: Vector2, plot: float, rng: RandomNumberGenerator) -> void:
	_building(SUBURB + HOUSES[rng.randi() % HOUSES.size()], c, plot * 0.6, rng, 1.0)
	# Clôture sur deux côtés et un arbre dans le jardin.
	var fence: Array = _prototype(SUBURB + "fence-1x3")
	var fs := plot * 0.45 / maxf(fence[1].size.x, 0.01)
	for k in 2:
		var yaw := k * PI * 0.5
		var off := Vector2(0, plot * 0.45).rotated(-yaw)
		_add(SUBURB + "fence-1x3", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * fs), Vector3(c.x + off.x, WL.GROUND_LEVEL, c.y + off.y)))
	if rng.randf() < 0.8:
		var t := c + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)) * plot
		var tree: Array = _prototype(SUBURB + "tree-large")
		_add(SUBURB + "tree-large", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(7.0, 10.0) / maxf(tree[1].size.y, 0.01) * 1.0), Vector3(t.x, WL.GROUND_LEVEL, t.y)))


func _park(x0: float, z0: float, w: float, rng: RandomNumberGenerator) -> void:
	var tree: Array = _prototype(SUBURB + "tree-large")
	for n in 14:
		var t := Vector2(x0 + rng.randf_range(3.0, w - 3.0), z0 + rng.randf_range(3.0, w - 3.0))
		var h := rng.randf_range(6.0, 11.0)
		_add(SUBURB + "tree-large", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * h / maxf(tree[1].size.y, 0.01)), Vector3(t.x, WL.GROUND_LEVEL, t.y)))


# ------------------------------------------------------------------ fermes

func _farms(rng: RandomNumberGenerator) -> void:
	var crops := ["crops_cornStageD", "crops_wheatStageB", "crops_leafsStageB"]
	for r in FARMS:
		var rect := r as Rect2
		# Ferme et grange dans un coin, champs en rangs dans le reste.
		var home := rect.position + Vector2(12.0, 12.0)
		_building(SUBURB + "building-type-c", home, 14.0, rng, 1.0)
		_building(SUBURB + "building-type-k", home + Vector2(0.0, 22.0), 16.0, rng, 1.2)
		var kind: String = crops[rng.randi() % crops.size()]
		var crop: Array = _prototype(NATURE + kind)
		var cs := 1.6 / maxf(crop[1].size.y, 0.01)
		var x := rect.position.x + 30.0
		while x < rect.end.x - 4.0:
			var z := rect.position.y + 4.0
			while z < rect.end.y - 4.0:
				if data.road_distance(x, z) > WL.ROAD_HALF + 3.0:
					var g: float = data.height_at(x, z)
					_add(NATURE + kind, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3).scaled(Vector3.ONE * cs), Vector3(x, g - 0.05, z)))
				z += 1.6
			x += 3.2
			if rng.randf() < 0.06:
				kind = crops[rng.randi() % crops.size()]
				crop = _prototype(NATURE + kind)
				cs = 1.6 / maxf(crop[1].size.y, 0.01)
		# Clôture tout autour (sauf là où passe la piste).
		var fence: Array = _prototype(NATURE + "fence_simple")
		var fl: float = fence[1].size.x
		var fs := 3.0 / maxf(fl, 0.01)
		for side in 4:
			var a: Vector2 = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)][side]
			var b: Vector2 = [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position][side]
			var n := int(a.distance_to(b) / 3.0)
			var yaw := atan2((b - a).x, (b - a).y) - PI * 0.5
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n)
				if data.road_distance(p.x, p.y) < WL.ROAD_HALF + 2.0:
					continue
				_add(NATURE + "fence_simple", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * fs), Vector3(p.x, data.height_at(p.x, p.y) - 0.05, p.y)))


# ------------------------------------------------------------------ plage

func _beach(rng: RandomNumberGenerator) -> void:
	var parasols := ["detail-parasol-a", "detail-parasol-b"]
	var z := -300.0
	while z < 300.0:
		z += rng.randf_range(6.0, 14.0)
		# Entre la piste (qui longe la plage) et l'eau : le sable sec du haut de plage.
		for tries in 3:
			var x := rng.randf_range(WL.DUNES_END + 30.0, WL.BEACH_END + 25.0)
			var g: float = data.height_at(x, z)
			if g < WL.SEA_LEVEL + 0.35 or data.road_distance(x, z) < WL.ROAD_HALF + 4.0:
				continue
			var kind: String = parasols[rng.randi() % 2]
			var p: Array = _prototype(CITY + kind)
			var s := 2.6 / maxf(p[1].size.y, 0.01)
			_add(CITY + kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, g - 0.1, z)))
			beach_spots.append(Vector3(x, g, z))
			if rng.randf() < 0.08 and data.road_distance(x - 10.0, z) > WL.ROAD_HALF + 8.0:
				# Cabane de plage un peu en retrait.
				_building(SUBURB + "building-type-a", Vector2(x - 10.0, z), 7.0, rng, 0.8)
			break


# ------------------------------------------------------------------ outils

func _prototype(path: String) -> Array:
	if not _proto.has(path):
		var root: Node3D = (load(path + ".glb") as PackedScene).instantiate()
		var merged: Array = MeshMerge.merge(root)
		root.free()
		# Bâtiments et maisons : fenêtres qui s'allument la nuit.
		if path.contains("/building"):
			var mesh: ArrayMesh = merged[0]
			for si in mesh.get_surface_count():
				var m := mesh.surface_get_material(si) as BaseMaterial3D
				if m and m.albedo_texture:
					var sm := ShaderMaterial.new()
					sm.shader = BUILDING_SHADER
					sm.set_shader_parameter("albedo_tex", m.albedo_texture)
					mesh.surface_set_material(si, sm)
		# Cultures : le kit les donne turquoise et blanches ; on les met aux couleurs du
		# décor (vert de champ, blé doré, épis jaunes).
		if path.contains("crops_"):
			var cmesh: ArrayMesh = merged[0]
			var wheat := path.contains("wheat")
			for si in cmesh.get_surface_count():
				var cm := cmesh.surface_get_material(si) as BaseMaterial3D
				if cm == null:
					continue
				if wheat:
					cm.albedo_color = Color(0.85, 0.66, 0.27)
				elif cm.albedo_color.g > cm.albedo_color.r:
					cm.albedo_color = Color(0.36, 0.55, 0.22)
				else:
					cm.albedo_color = Color(0.93, 0.76, 0.3)
		_proto[path] = merged
	return _proto[path]


func _add(path: String, xf: Transform3D) -> void:
	_prototype(path)
	var key := [Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL)), path]
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(xf)
	count += 1


func _box(foot: Vector3, size: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size * Vector3(0.95, 1.0, 0.95)
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), foot + Vector3(0, size.y / 2.0, 0))
	_body.add_child(cs)


func _commit() -> void:
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
		mmi.position = origin
		# Fondu en distance (pas de maisons qui surgissent) ; la case reste affichée un peu plus loin.
		FarFade.setup(mmi, RANGE - 10.0, CELL * FarFade.CELL_MARGIN)
		add_child(mmi)
	_cells.clear()
