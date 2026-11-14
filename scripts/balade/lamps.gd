## Éclairage public, avec un modèle selon le lieu :
## - centre-ville : grands réverbères modernes à bras, le long des trottoirs ;
## - banlieue : lanternes classiques plus basses ;
## - fermes : poteaux en bois avec une petite lampe, autour de la cour ;
## - plage : bornes basses le long de la promenade.
## Pas d'éclairage le long de la piste de terre (rien de logique à éclairer en forêt ou dans
## les dunes). Mâts en MultiMesh par case et par modèle ; la lampe s'allume la nuit
## (shaders/lamp.gdshader, paramètre global « night »). La lumière au sol est précalculée
## (tools/bake_shadows.gd -> lights.png), avec une portée propre à chaque modèle.
extends Node3D

const FarFade = preload("res://scripts/balade/far_fade.gd")

const WL = preload("res://scripts/core/world_layout.gd")
const Town = preload("res://scripts/balade/town.gd")

const CELL := 120.0
enum Style { CITY, SUBURB, FARM, BEACH }
## Par modèle : hauteur de la lampe, avancée du bras, taille du halo, portée au sol (m).
const LAMP_HEIGHT: Array[float] = [6.05, 3.9, 5.0, 0.85]
const LAMP_REACH: Array[float] = [1.4, 0.0, 0.7, 0.0]
const HALO_SIZE: Array[float] = [3.2, 2.2, 2.0, 1.1]
const GLOW_RADIUS: Array[float] = [11.0, 8.0, 7.5, 4.5]


## Lampadaires : [position (x, sol, z), direction du bras (vers la rue), modèle].
static func positions(data: RefCounted, town: Node) -> Array:
	var out: Array = []
	# Ville : le long de chaque bord de pâté, tous les ~18 m (centre) ou ~22 m (banlieue).
	for seg in town.sidewalks:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var suburb: bool = (a.x + b.x) * 0.5 > -260.0
		var gap := 22.0 if suburb else 18.0
		var n := maxi(1, int(a.distance_to(b) / gap))
		var d := (b - a).normalized()
		var out_dir := Vector2(d.y, -d.x)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n) + out_dir * 0.6
			out.append([Vector3(p.x, WL.GROUND_LEVEL, p.y), out_dir, Style.SUBURB if suburb else Style.CITY])
	# Fermes : trois poteaux en bois autour de la cour (entre la maison et les champs).
	for r in Town.FARMS:
		var rect := r as Rect2
		for o in [Vector2(26.0, 4.0), Vector2(4.0, 40.0), Vector2(26.0, 46.0)]:
			var p2: Vector2 = rect.position + o
			if data.road_distance(p2.x, p2.y) < WL.ROAD_HALF + 2.0:
				continue
			var g: float = data.height_at(p2.x, p2.y)
			out.append([Vector3(p2.x, g, p2.y), (rect.position + Vector2(14.0, 24.0) - p2).normalized(), Style.FARM])
	# Plage : bornes basses le long de la promenade, entre les dunes et les parasols.
	var z := -WL.VALLEY_HALF
	while z < WL.VALLEY_HALF:
		z += 14.0
		var x := WL.DUNES_END + WL.shore_offset(z) + 18.0
		var g2: float = data.height_at(x, z)
		if g2 > WL.SEA_LEVEL + 0.4 and data.road_distance(x, z) > WL.ROAD_HALF + 2.0 and WL.mountain_factor(x, z) < 0.02:
			out.append([Vector3(x, g2, z), Vector2(1, 0), Style.BEACH])
	return out


func build(data: RefCounted, town: Node) -> void:
	var list := positions(data, town)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lamp.gdshader")
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = load("res://shaders/halo.gdshader")
	var meshes: Array[ArrayMesh] = []
	for st in 4:
		meshes.append(_lamp_mesh(st))
	var cells := {}
	for l in list:
		var p: Vector3 = l[0]
		var d: Vector2 = l[1]
		var style: int = l[2]
		var key := [Vector2i(floori(p.x / CELL), floori(p.z / CELL)), style]
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), p))
	for key in cells:
		var cell: Vector2i = key[0]
		var style: int = key[1]
		var xs: Array = cells[key]
		var origin := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[style]
		mm.instance_count = xs.size()
		for i in xs.size():
			var xf: Transform3D = xs[i]
			xf.origin -= origin
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = origin
		FarFade.setup(mmi, 200.0, CELL * FarFade.CELL_MARGIN)
		add_child(mmi)
		# Halos des lampes (la nuit).
		var hm := MultiMesh.new()
		hm.transform_format = MultiMesh.TRANSFORM_3D
		hm.mesh = QuadMesh.new()
		hm.instance_count = xs.size()
		for i in xs.size():
			var xf: Transform3D = xs[i]
			var bulb := xf * Vector3(0, LAMP_HEIGHT[style] - 0.1, LAMP_REACH[style]) - origin
			hm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * HALO_SIZE[style]), bulb))
		hm.custom_aabb = AABB(Vector3(-CELL, -5, -CELL), Vector3(CELL * 2, 60, CELL * 2))
		var hmi := MultiMeshInstance3D.new()
		hmi.multimesh = hm
		hmi.material_override = halo_mat
		hmi.position = origin
		hmi.visibility_range_end = 200.0 + CELL * FarFade.CELL_MARGIN
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hmi)


## Modèle low poly de chaque style ; UV.x = 1 sur l'ampoule (s'allume), couleur par sommet.
static func _lamp_mesh(style: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal := Color(0.22, 0.22, 0.25)
	match style:
		Style.CITY:
			_box(st, Vector3(0, 3.25, 0), Vector3(0.12, 6.5, 0.12), 0.0, metal)
			_box(st, Vector3(0, 6.4, 0.7), Vector3(0.08, 0.08, 1.4), 0.0, metal)
			_box(st, Vector3(0, 6.3, 1.4), Vector3(0.45, 0.16, 0.6), 0.0, metal)
			_box(st, Vector3(0, 6.18, 1.4), Vector3(0.36, 0.06, 0.48), 1.0, metal)
		Style.SUBURB:
			var dark := Color(0.16, 0.18, 0.17)
			_box(st, Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.3), 0.0, dark)
			_box(st, Vector3(0, 1.9, 0), Vector3(0.1, 3.4, 0.1), 0.0, dark)
			_box(st, Vector3(0, 3.62, 0), Vector3(0.34, 0.06, 0.34), 0.0, dark)
			_box(st, Vector3(0, 3.92, 0), Vector3(0.26, 0.5, 0.26), 1.0, dark)
			_box(st, Vector3(0, 4.22, 0), Vector3(0.4, 0.1, 0.4), 0.0, dark)
		Style.FARM:
			var wood := Color(0.36, 0.25, 0.16)
			_box(st, Vector3(0, 2.75, 0), Vector3(0.2, 5.5, 0.2), 0.0, wood)
			_box(st, Vector3(0, 5.2, 0.35), Vector3(0.08, 0.08, 0.7), 0.0, wood)
			_box(st, Vector3(0, 5.1, 0.7), Vector3(0.3, 0.12, 0.3), 0.0, Color(0.2, 0.24, 0.2))
			_box(st, Vector3(0, 4.98, 0.7), Vector3(0.18, 0.12, 0.18), 1.0, metal)
		Style.BEACH:
			var post := Color(0.42, 0.33, 0.24)
			_box(st, Vector3(0, 0.38, 0), Vector3(0.22, 0.76, 0.22), 0.0, post)
			_box(st, Vector3(0, 0.84, 0), Vector3(0.2, 0.16, 0.2), 1.0, post)
			_box(st, Vector3(0, 0.96, 0), Vector3(0.3, 0.06, 0.3), 0.0, post)
	st.generate_normals()
	return st.commit()


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, glow: float, col: Color) -> void:
	var h := s / 2.0
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var corners := [n - u - v, n + u - v, n + u + v, n - u + v]
		var pts := []
		for k in corners:
			pts.append(c + (k as Vector3) * h)
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_uv(Vector2(glow, 0))
			st.add_vertex(pts[idx])
