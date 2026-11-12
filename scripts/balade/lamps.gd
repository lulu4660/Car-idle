## Réverbères : le long des trottoirs de la ville, de la piste près des lieux habités (ville,
## fermes, plage) et de la promenade de plage. Mât low poly en MultiMesh par case ; la tête
## s'allume la nuit (shaders/lamp.gdshader, réglée par le paramètre global « night »).
## La lumière qu'ils jettent au sol est précalculée (tools/bake_shadows.gd -> lights.png) et
## ajoutée par le terrain et l'herbe : des centaines de « lumières » sans aucun calcul de
## lumière en temps réel.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")

const CELL := 120.0
const HEIGHT := 6.5


## Positions des réverbères (x, sol, z) et direction du bras (vers la rue).
static func positions(data: RefCounted, town: Node) -> Array:
	var out: Array = []
	# Ville : le long de chaque bord de pâté, tous les ~18 m, bras vers la rue.
	for seg in town.sidewalks:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n := maxi(1, int(a.distance_to(b) / 18.0))
		var d := (b - a).normalized()
		var out_dir := Vector2(d.y, -d.x)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n) + out_dir * 0.6
			out.append([Vector3(p.x, WL.GROUND_LEVEL, p.y), out_dir])
	# Piste : un côté, tous les 34 m, là où c'est habité (ville, fermes, plage).
	var poly := WL.road_polyline()
	var acc := 0.0
	var side := 1.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		acc += a.distance_to(b)
		if acc < 34.0:
			continue
		acc = 0.0
		var near_town := a.x < -60.0 or a.x > 300.0
		var farm := false
		for r in [Rect2(-175.0, 130.0, 115.0, 150.0), Rect2(-170.0, -340.0, 105.0, 130.0), Rect2(-175.0, -50.0, 90.0, 100.0)]:
			if (r as Rect2).has_point(a):
				farm = true
		if not (near_town or farm):
			continue
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x) * side
		var p := a + n * (WL.ROAD_HALF + 1.8)
		var g: float = data.height_at(p.x, p.y)
		if g < WL.SEA_LEVEL + 0.3:
			continue
		out.append([Vector3(p.x, g, p.y), -n])
		side = -side
	# Promenade de plage : une rangée entre la piste et les parasols.
	var z := -280.0
	while z < 280.0:
		z += 30.0
		var x := WL.DUNES_END + WL.shore_offset(z) + 18.0
		var g2: float = data.height_at(x, z)
		if g2 > WL.SEA_LEVEL + 0.4 and data.road_distance(x, z) > WL.ROAD_HALF + 2.0:
			out.append([Vector3(x, g2, z), Vector2(1, 0)])
	return out


func build(data: RefCounted, town: Node) -> void:
	var list := positions(data, town)
	var mesh := _lamp_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lamp.gdshader")
	var cells := {}
	for l in list:
		var p: Vector3 = l[0]
		var d: Vector2 = l[1]
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), p))
	for key in cells:
		var xs: Array = cells[key]
		var origin := Vector3((key.x + 0.5) * CELL, 0, (key.y + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			var xf: Transform3D = xs[i]
			xf.origin -= origin
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = origin
		mmi.visibility_range_end = 220.0
		add_child(mmi)


## Réverbère low poly : mât, bras vers +Z, tête. UV.x = 1 sur l'ampoule (s'allume).
static func _lamp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, HEIGHT / 2.0, 0), Vector3(0.12, HEIGHT, 0.12), 0.0)
	_box(st, Vector3(0, HEIGHT - 0.1, 0.7), Vector3(0.08, 0.08, 1.4), 0.0)
	_box(st, Vector3(0, HEIGHT - 0.2, 1.4), Vector3(0.45, 0.16, 0.6), 0.0)
	_box(st, Vector3(0, HEIGHT - 0.32, 1.4), Vector3(0.36, 0.06, 0.48), 1.0)
	st.generate_normals()
	return st.commit()


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, glow: float) -> void:
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
			st.set_uv(Vector2(glow, 0))
			st.add_vertex(pts[idx])
