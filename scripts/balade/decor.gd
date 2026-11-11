## Vie du décor : touffes d'herbes sèches sur les dunes et le haut de la plage (agitées par le
## vent, avec leurs ombres), mouettes qui tournent au-dessus de la plage et de la voiture.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")

const GRASS_COUNT := 11000
const GRASS_CELL := 48.0
const GRASS_SHADOW_RANGE := 70.0
const GRASS_RANGE := 140.0
const BIRDS := 9

var data: RefCounted
var low_quality := false
var target: Node3D
var _birds: Array[Dictionary] = []
var _bird_mat: ShaderMaterial
var _clock := 0.0


func build(world_data: RefCounted, follow: Node3D) -> void:
	data = world_data
	target = follow
	_build_grass()
	_build_birds()
	_build_props()


# ------------------------------------------------------------------ herbes

func _build_grass() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	var mesh := _tuft_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var xforms: Array[Transform3D] = []
	var attempts := 0
	while xforms.size() < GRASS_COUNT and attempts < GRASS_COUNT * 12:
		attempts += 1
		# Les touffes poussent en colonies, surtout en arrière de la plage et dans les creux des dunes.
		var x := rng.randf_range(WL.DIRT_END - 20.0, WL.BEACH_END)
		var z := rng.randf_range(-WL.SIZE / 2.0 + 30.0, WL.SIZE / 2.0 - 30.0)
		var h: float = data.height_at(x, z)
		var s := WL.surface_at(x, z, h)
		if s != WL.Surface.SAND and s != WL.Surface.DIRT:
			continue
		if h < WL.SEA_LEVEL + 0.8:
			continue
		var colony := WL.fbm(x / 22.0 + 40.0, z / 22.0 - 3.0)
		var near_beach := clampf(1.0 - absf(x - (WL.DUNES_END - 5.0 + WL.shore_offset(z))) / 60.0, 0.0, 1.0)
		var trough := clampf((WL.GROUND_LEVEL + 4.0 - h) / 4.0, 0.0, 1.0)
		# Colonies serrées : beaucoup de touffes là où le bruit est haut, presque rien ailleurs.
		var chance := (colony - 0.55) * 2.6 + near_beach * 0.3 + trough * 0.2
		if rng.randf() > chance:
			continue
		# Une touffe en appelle d'autres : petit massif de 3 à 7 touffes serrées.
		for k in rng.randi_range(3, 7):
			var px := x + rng.randf_range(-1.6, 1.6)
			var pz := z + rng.randf_range(-1.6, 1.6)
			var ph: float = data.height_at(px, pz)
			var scale := rng.randf_range(0.9, 1.9) * (1.0 + near_beach * 0.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
			basis = basis.scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.3), scale))
			xforms.append(Transform3D(basis, Vector3(px, ph - 0.05, pz)))
	# Rangées par cases de 48 m : seules les cases proches sont dessinées (et ombrées de près).
	var cells := {}
	for xf in xforms:
		var key := Vector2i(floori(xf.origin.x / GRASS_CELL), floori(xf.origin.z / GRASS_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
	for key in cells:
		var list: Array = cells[key]
		var center := Vector3((key.x + 0.5) * GRASS_CELL, 0.0, (key.y + 0.5) * GRASS_CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		var aabb := AABB(list[0].origin - center, Vector3.ZERO)
		for i in list.size():
			mm.set_instance_transform(i, Transform3D(list[i].basis, list[i].origin - center))
			aabb = aabb.expand(list[i].origin - center)
		mm.custom_aabb = aabb.grow(2.0)
		# Deux copies : ombrée près de la caméra, sans ombre plus loin.
		for near in [true, false]:
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.position = center
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# iPhone et web : ombres de l'herbe seulement tout près (passe d'ombre moins chère).
			var shadow_range := GRASS_SHADOW_RANGE * (0.45 if low_quality else 1.0)
			if near:
				mmi.visibility_range_end = shadow_range
			else:
				mmi.visibility_range_begin = shadow_range
				mmi.visibility_range_end = GRASS_RANGE * (0.75 if low_quality else 1.0)
			add_child(mmi)


## Touffe d'herbe low poly : 7 lames larges et pointues, taillées en facettes (chaque
## triangle a sa propre normale), couleurs unies du vert olive à la paille.
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for blade in 7:
		var ang := blade / 7.0 * TAU + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := dir.cross(Vector3.UP)
		var reach := rng.randf_range(0.15, 0.45)
		var height := rng.randf_range(0.55, 1.0)
		var width := rng.randf_range(0.09, 0.14)
		var base := dir * 0.05
		var mid := base + dir * reach * 0.35 + Vector3.UP * height * 0.55
		var tip := base + dir * reach + Vector3.UP * height
		var col := Color(0.62, 0.56, 0.27).lerp(Color(0.86, 0.76, 0.42), rng.randf())
		var dark := col.darkened(0.25)
		var quad := [base - side * width, base + side * width, mid + side * width * 0.6, mid - side * width * 0.6]
		var tris := [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]], [quad[3], quad[2], tip]]
		var cols := [[dark, dark, col], [dark, col, col], [col, col, col.lightened(0.12)]]
		for t in 3:
			for k in 3:
				st.set_color(cols[t][k])
				var v: Vector3 = tris[t][k]
				st.set_uv(Vector2(0.5, 1.0 - clampf(v.y / height, 0.0, 1.0)))
				st.add_vertex(v)
	# Normales par triangle : rendu facetté.
	st.generate_normals()
	return st.commit()


# ------------------------------------------------------------------ objets

const PROP_DIR := "res://assets/props/kenney/"
const PropBody = preload("res://scripts/balade/prop_body.gd")
## Objets destructibles : masse (kg), fragile (se brise en morceaux), couleur des morceaux.
const DESTRUCTIBLE := {
	"barrel": [45.0, false, Color(0.55, 0.32, 0.20)], "barrel-open": [35.0, true, Color(0.55, 0.32, 0.20)],
	"box-large": [30.0, true, Color(0.72, 0.55, 0.34)], "box": [12.0, true, Color(0.72, 0.55, 0.34)],
	"signpost": [20.0, true, Color(0.60, 0.44, 0.28)], "tent-canvas": [25.0, true, Color(0.85, 0.80, 0.68)],
	"metal-panel": [25.0, false, Color(0.6, 0.62, 0.65)], "cactus_short": [40.0, true, Color(0.36, 0.55, 0.28)],
	"cactus_tall": [80.0, true, Color(0.36, 0.55, 0.28)], "tree-log": [60.0, false, Color(0.5, 0.36, 0.24)],
	"log": [40.0, false, Color(0.5, 0.36, 0.24)], "log_large": [90.0, false, Color(0.5, 0.36, 0.24)],
	"stump_old": [120.0, true, Color(0.48, 0.35, 0.24)],
}
var effects: Node3D
# Hauteur visée (m) de chaque objet du kit, et s'il arrête la voiture.
const PROPS := {
	"structure-metal": [3.2, true], "tent-canvas": [2.2, true], "barrel": [1.0, true], "barrel-open": [1.0, true],
	"box-large": [1.0, true], "box": [0.6, true], "signpost": [2.2, true], "campfire-pit": [0.45, false],
	"metal-panel": [1.6, true], "tree-log": [0.6, true], "log": [0.45, true], "log_large": [0.8, true],
	"stump_old": [0.8, true], "cactus_short": [1.3, true], "cactus_tall": [3.2, true],
	"rock-sand-a": [1.1, true], "rock-sand-b": [0.8, true], "rock-sand-c": [1.4, true],
}


## Campements au bord de la plage et dans les dunes, bois flotté le long du rivage, souches
## et cactus épars : de quoi raconter un lieu vu du ciel.
func _build_props() -> void:
	var body := StaticBody3D.new()
	body.name = "Objets"
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# Campement de pêcheurs près du départ, côté dunes (hors de la route le long du rivage).
	_camp(body, Vector2(WL.SPAWN_X - 26.0, WL.SPAWN_Z - 45.0), 0.4)
	_camp(body, Vector2(268.0, 160.0), 2.1)
	_camp(body, Vector2(345.0, 330.0), -0.8)
	# Bois flotté et cailloux le long du rivage.
	var z := -WL.SIZE / 2.0 + 40.0
	while z < WL.SIZE / 2.0 - 40.0:
		z += rng.randf_range(18.0, 45.0)
		var x := WL.DUNES_END + WL.shore_offset(z) + rng.randf_range(10.0, 45.0)
		var kind: String = ["log", "log", "log_large", "rock-sand-b", "tree-log"][rng.randi() % 5]
		_place(body, kind, Vector2(x, z), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	# Souches, cactus et rochers épars dans les dunes.
	for i in 90:
		var x := rng.randf_range(WL.DIRT_END + 10.0, WL.DUNES_END - 10.0)
		var zz := rng.randf_range(-WL.SIZE / 2.0 + 40.0, WL.SIZE / 2.0 - 40.0)
		if Vector2(x - WL.SPAWN_X, zz - WL.SPAWN_Z).length() < 30.0:
			continue
		var kind: String = ["stump_old", "cactus_short", "cactus_tall", "rock-sand-a", "rock-sand-c", "log_large"][rng.randi() % 6]
		_place(body, kind, Vector2(x, zz), rng.randf() * TAU, rng.randf_range(0.8, 1.3))


func _camp(body: StaticBody3D, at: Vector2, yaw: float) -> void:
	var r := Basis(Vector3.UP, yaw)
	var items := [["tent-canvas", Vector3(0, 0, 0), 0.0], ["tent-canvas", Vector3(6.5, 0, 2.5), 0.6],
		["barrel", Vector3(-2.6, 0, 1.5), 0.0], ["barrel", Vector3(-2.5, 0, 2.6), 0.0], ["barrel-open", Vector3(-3.6, 0, 2.1), 0.0],
		["box-large", Vector3(3.0, 0, -2.0), 0.3], ["box", Vector3(3.6, 0, -0.9), 1.0], ["campfire-pit", Vector3(4.5, 0, 4.5), 0.0],
		["signpost", Vector3(-5.0, 0, -4.0), 2.4], ["metal-panel", Vector3(1.5, 0, 3.6), 1.2]]
	for it in items:
		var off: Vector3 = r * (it[1] as Vector3)
		_place(body, it[0], at + Vector2(off.x, off.z), yaw + float(it[2]), 1.0)


func _place(body: StaticBody3D, kind: String, at: Vector2, yaw: float, size_k: float) -> void:
	var scene: PackedScene = load(PROP_DIR + kind + ".glb")
	if scene == null:
		return
	var node: Node3D = scene.instantiate()
	var b := _bounds(node)
	var spec: Array = PROPS[kind]
	var s := float(spec[0]) * size_k / maxf(b.size.y, 0.01)
	var ground: float = data.height_at(at.x, at.y)
	if ground < WL.SEA_LEVEL + 0.2:
		node.free()
		return
	var size := b.size * s
	var foot := Vector3(at.x, ground - 0.05, at.y)
	if not spec[1]:
		node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), foot - Vector3(0, b.position.y * s, 0))
		add_child(node)
		return
	if DESTRUCTIBLE.has(kind):
		# Objet destructible : un corps physique figé, réveillé par la voiture.
		var info: Array = DESTRUCTIBLE[kind]
		var prop: RigidBody3D = PropBody.new()
		prop.mass = info[0]
		prop.fragile = info[1]
		prop.debris_color = info[2]
		prop.effects = effects
		prop.transform = Transform3D(Basis(Vector3.UP, yaw), foot)
		node.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), -Vector3(b.get_center().x, b.position.y, b.get_center().z) * s)
		prop.add_child(node)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size * 0.9
		cs.shape = box
		cs.position = Vector3(0, size.y / 2.0, 0)
		prop.add_child(cs)
		add_child(prop)
		prop.setup(size)
		return
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), foot - Vector3(0, b.position.y * s, 0))
	add_child(node)
	var cs2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = size * 0.9
	cs2.shape = box2
	cs2.transform = Transform3D(Basis(Vector3.UP, yaw), node.transform * b.get_center())
	body.add_child(cs2)


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != root:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var b := xf * (m as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# ------------------------------------------------------------------ mouettes

func _build_birds() -> void:
	_bird_mat = ShaderMaterial.new()
	_bird_mat.shader = load("res://shaders/bird.gdshader")
	var mesh := _bird_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in BIRDS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _bird_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.set_instance_shader_parameter("phase", rng.randf() * TAU)
		add_child(mi)
		_birds.append({"node": mi, "radius": rng.randf_range(8.0, 26.0), "height": rng.randf_range(7.0, 16.0),
			"speed": rng.randf_range(0.25, 0.5) * (1.0 if rng.randf() < 0.7 else -1.0), "angle": rng.randf() * TAU,
			"offset": Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), "center": Vector3.ZERO})


## Mouette : corps fuselé et deux ailes (1 m d'envergure), blanche aux bouts gris.
func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [
		# aile gauche, aile droite (UV.x = distance au corps, pour le battement)
		[Vector3(0, 0, 0.12), Vector3(0, 0, -0.12), Vector3(-0.55, 0, -0.05)],
		[Vector3(0, 0, -0.12), Vector3(0, 0, 0.12), Vector3(0.55, 0, -0.05)],
		# corps
		[Vector3(0, 0.02, 0.3), Vector3(-0.05, 0, -0.25), Vector3(0.05, 0, -0.25)],
	]
	for tri in tris:
		for v in tri:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(absf(v.x) / 0.55, 0))
			st.add_vertex(v)
	return st.commit()


func _process(delta: float) -> void:
	_clock += delta
	_bird_mat.set_shader_parameter("now", _clock)
	if target == null or not is_instance_valid(target):
		return
	var focus := target.global_position
	for b in _birds:
		# Le centre de leur ronde suit doucement la voiture.
		b["center"] = (b["center"] as Vector3).lerp(focus + b["offset"], 1.0 - exp(-0.3 * delta))
		b["angle"] = float(b["angle"]) + float(b["speed"]) * delta
		var a: float = b["angle"]
		var c: Vector3 = b["center"]
		var r: float = b["radius"]
		var pos := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var ground: float = data.height_at(pos.x, pos.z)
		pos.y = maxf(ground, WL.SEA_LEVEL) + float(b["height"]) + sin(_clock * 0.7 + a) * 0.6
		var dir := Vector3(-sin(a), 0, cos(a)) * signf(float(b["speed"]))
		var node: MeshInstance3D = b["node"]
		node.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP).rotated(dir, 0.25 * signf(float(b["speed"]))), pos)
