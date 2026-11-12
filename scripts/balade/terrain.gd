## Terrain de la balade : 16 × 16 morceaux de 64 m. Chaque morceau existe en deux niveaux
## de détail (1 m près de la caméra, 4 m au loin) ; la carte graphique les déforme avec la
## carte des hauteurs (shaders/terrain.gdshader). Collision : une HeightMapShape3D de
## 1025 × 1025. Le sol peut se creuser (réception de saut) : carte et collision suivent.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")

const CHUNK := 64
const NEAR_RANGE := 180.0

var data: RefCounted
var _height_image: Image
var _height_tex: ImageTexture
var _shape: HeightMapShape3D
var _material: ShaderMaterial


var near_range := NEAR_RANGE
## iPhone : le terrain ne projette pas d'ombre (le relief se lit déjà par la lumière des facettes).
var cast_shadows := true


func build(world_data: RefCounted) -> void:
	data = world_data
	_height_image = data.height_image()
	_height_tex = ImageTexture.create_from_image(_height_image)
	var splat := ImageTexture.create_from_image(data.splat_image())

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/terrain.gdshader")
	_material.set_shader_parameter("height_tex", _height_tex)
	_material.set_shader_parameter("splat_tex", splat)
	_material.set_shader_parameter("road_tex", ImageTexture.create_from_image(data.road_image()))
	_material.set_shader_parameter("road_half", WL.ROAD_HALF)
	_material.set_shader_parameter("world_size", WL.SIZE)
	_material.set_shader_parameter("res", data.res)

	# Facettes de 2 m (voir tools/bake_world.gd) : 2 m entre sommets suffit, sans perte.
	var near_mesh := _grid_mesh(CHUNK / 2, 2)
	var far_mesh := _grid_mesh(CHUNK / 4, 4)
	var count := int(WL.SIZE) / CHUNK
	var aabb := AABB(Vector3(0, -5, 0), Vector3(CHUNK, WL.MAX_HEIGHT + 5.0, CHUNK))
	for cz in count:
		for cx in count:
			var origin := Vector3(cx * CHUNK - WL.SIZE / 2.0, 0.0, cz * CHUNK - WL.SIZE / 2.0)
			for lod in 2:
				var mi := MeshInstance3D.new()
				mi.mesh = near_mesh if lod == 0 else far_mesh
				mi.material_override = _material
				mi.custom_aabb = aabb
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = origin
				if lod == 0:
					mi.visibility_range_end = near_range
				else:
					mi.visibility_range_begin = near_range
				add_child(mi)

	var body := StaticBody3D.new()
	body.name = "Sol"
	body.add_to_group("terrain")
	var cs := CollisionShape3D.new()
	_shape = HeightMapShape3D.new()
	_shape.map_width = data.res
	_shape.map_depth = data.res
	_shape.map_data = data.heights
	cs.shape = _shape
	body.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	body.physics_material_override = pm
	add_child(body)


## Grille de n × n carreaux de `step` mètres, avec une jupe sur les bords (UV2.x = 1 :
## sommets abaissés par le shader, pour cacher les fentes entre niveaux de détail).
func _grid_mesh(n: int, step: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in n + 1:
		for i in n + 1:
			verts.append(Vector3(i * step, 0, j * step))
			uv2.append(Vector2.ZERO)
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	# Jupe : chaque bord est doublé par des sommets abaissés.
	var edges := [[], [], [], []]
	for k in n + 1:
		edges[0].append(k)
		edges[1].append(n * (n + 1) + k)
		edges[2].append(k * (n + 1))
		edges[3].append(k * (n + 1) + n)
	for e in edges:
		var base := verts.size()
		for v in e:
			verts.append(verts[v])
			uv2.append(Vector2(1, 0))
		for k in n:
			var a: int = e[k]
			var b: int = e[k + 1]
			idx.append_array([a, b, base + k, b, base + k + 1, base + k, a, base + k, b, b, base + k, base + k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var tangents := PackedFloat32Array()
	for v in verts.size():
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func material() -> ShaderMaterial:
	return _material


func height_texture() -> Texture2D:
	return _height_tex


## Creuse une cuvette (profil en cloche) bordée d'un léger bourrelet, autour de `world`.
func dent(world: Vector3, radius: float, depth: float) -> void:
	var res: int = data.res
	var half := WL.SIZE / 2.0
	var rim := radius * 1.7
	var r := int(ceil(rim)) + 1
	var cx := int(round(world.x + half))
	var cz := int(round(world.z + half))
	for z in range(maxi(cz - r, 0), mini(cz + r, res - 1) + 1):
		for x in range(maxi(cx - r, 0), mini(cx + r, res - 1) + 1):
			var dx := x - half - world.x
			var dz := z - half - world.z
			var d := sqrt(dx * dx + dz * dz) / radius
			var delta := 0.0
			if d < 1.0:
				var t := 1.0 - d * d
				delta = -depth * t * t
			elif d < 1.7:
				delta = depth * 0.22 * sin((d - 1.0) / 0.7 * PI)
			else:
				continue
			var h: float = data.heights[z * res + x] + delta
			data.heights[z * res + x] = h
			_height_image.set_pixel(x, z, Color(h, 0, 0))
	# Envoi groupé : une réception de saut creuse jusqu'à 5 fois dans la même image ; la
	# texture (1 million de hauteurs) part une seule fois par image, et la collision au plus
	# toutes les 0,3 s (sa reconstruction est le plus cher).
	_dirty_tex = true
	_dirty_shape = true


var _dirty_tex := false
var _dirty_shape := false
var _shape_timer := 0.0


func _process(delta: float) -> void:
	_shape_timer -= delta
	if _dirty_tex:
		_dirty_tex = false
		_height_tex.update(_height_image)
	if _dirty_shape and _shape_timer <= 0.0:
		_dirty_shape = false
		_shape_timer = 0.3
		_shape.map_data = data.heights
