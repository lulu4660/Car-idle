## Construit le décor de la balade autour du terrain : ciel et soleil d'après-midi, brume, post-traitement, mer animée, sable à
## perte de vue, limites du monde, immeubles de la ville et rochers.
extends RefCounted

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")

## Soleil d'après-midi (34°) au sud-ouest : ombres nettes et assez longues, le sable modelé
## par la lumière rasante sur les versants, image claire comme une vidéo de drone en plein jour.
const SUN_ELEVATION := 34.0
const SUN_AZIMUTH := 225.0  # degrés depuis le nord, dans le sens des aiguilles d'une montre
const SUN_COLOR := Color(1.0, 0.95, 0.86)
## Horizon : la brume légère s'y fond.
const HAZE_COLOR := Color(0.78, 0.84, 0.88)


## Direction vers le soleil (repère Godot : nord = -Z, est = +X).
static func sun_direction() -> Vector3:
	var az := deg_to_rad(SUN_AZIMUTH)
	var el := deg_to_rad(SUN_ELEVATION)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


static func build_environment(parent: Node) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# Ciel calculé : bleu-vert au zénith, clair à l'horizon, disque du soleil à sa place.
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.22, 0.42, 0.55)
	proc.sky_horizon_color = Color(0.72, 0.80, 0.84)
	proc.sky_curve = 0.12
	proc.sky_energy_multiplier = 1.0
	proc.ground_horizon_color = Color(0.80, 0.70, 0.55)
	proc.ground_bottom_color = Color(0.70, 0.58, 0.42)
	proc.sun_angle_max = 20.0
	proc.sun_curve = 0.1
	sky.sky_material = proc
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Rendu cinéma : ACES, image claire, halo léger sur les reflets.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.15

	# Brume légère : seulement le lointain se fond dans l'horizon.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = HAZE_COLOR
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.1
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.3
	# Ombres de contact (rendu Forward+ seulement).
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4

	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.light_color = SUN_COLOR
	sun.light_energy = 2.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.4
	parent.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_direction(), Vector3.UP)
	return sun


## Mer : maillage fin le long de la côte (houle visible, vagues qui lèchent le sable)
## entouré de grands panneaux jusqu'à l'horizon.
static func build_sea(parent: Node, data: RefCounted, height_tex: Texture2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	mat.set_shader_parameter("height_tex", height_tex)
	mat.set_shader_parameter("res", data.res)
	mat.set_shader_parameter("world_size", WL.SIZE)
	mat.set_shader_parameter("sea_level", WL.SEA_LEVEL)
	var r := WorldData.SEA_RECT
	var far_mat := mat.duplicate() as ShaderMaterial
	far_mat.set_shader_parameter("wave_height", 0.0)
	_sea_mesh(parent, mat, r, 2.0, 4.0)
	var far := 4000.0
	_sea_mesh(parent, far_mat, Rect2(r.end.x, -far, far, far * 2.0), 400.0, 400.0)
	_sea_mesh(parent, far_mat, Rect2(r.position.x, r.end.y, r.size.x, far - r.end.y), 60.0, 400.0)
	_sea_mesh(parent, far_mat, Rect2(r.position.x, -far, r.size.x, r.position.y + far), 60.0, 400.0)


static func _sea_mesh(parent: Node, mat: Material, r: Rect2, step_x: float, step_z: float) -> void:
	var nx := maxi(1, int(ceil(r.size.x / step_x)))
	var nz := maxi(1, int(ceil(r.size.y / step_z)))
	var pm := PlaneMesh.new()
	pm.size = r.size
	pm.subdivide_width = nx - 1
	pm.subdivide_depth = nz - 1
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(r.get_center().x, WL.SEA_LEVEL, r.get_center().y)
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)


## Sable à perte de vue au nord, au sud et à l'ouest, à la hauteur des bords du terrain.
static func build_far_ground(parent: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ground/sand_albedo.png")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / 7.0
	mat.roughness = 1.0
	var half := WL.SIZE / 2.0
	var far := 2500.0
	var east := WL.BEACH_END - 15.0
	var y := WL.GROUND_LEVEL - 0.05
	for r in [Rect2(-far, half - 1.0, east + far, far), Rect2(-far, -half - far + 1.0, east + far, far), Rect2(-far, -half, far - half + 1.0, WL.SIZE)]:
		var pm := PlaneMesh.new()
		pm.size = r.size
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(r.get_center().x, y, r.get_center().y)
		parent.add_child(mi)


## Murs invisibles au nord, au sud et à l'ouest (la mer, à l'est, ramène au sec).
static func build_walls(parent: Node) -> void:
	var half := WL.SIZE / 2.0
	var body := StaticBody3D.new()
	body.name = "Limites"
	for w in [[Vector3(0, 30, half - 6.0), Vector3(WL.SIZE * 2.0, 80, 2)], [Vector3(0, 30, -half + 6.0), Vector3(WL.SIZE * 2.0, 80, 2)], [Vector3(-half + 6.0, 30, 0), Vector3(2, 80, WL.SIZE * 2.0)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = w[1]
		cs.shape = box
		cs.position = w[0]
		body.add_child(cs)
	parent.add_child(body)


## Immeubles de la ville : des blocs sur des pâtés de 60 m (MultiMesh : un seul appel de dessin).
static func build_city(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var palette := [Color(0.20, 0.19, 0.21), Color(0.30, 0.27, 0.25), Color(0.42, 0.38, 0.34), Color(0.16, 0.17, 0.20), Color(0.50, 0.30, 0.22)]
	var half := WL.SIZE / 2.0
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var body := StaticBody3D.new()
	body.name = "Ville"
	var bx := ceilf(-half / WL.BLOCK_SIZE) * WL.BLOCK_SIZE
	while bx + WL.BLOCK_SIZE < WL.CITY_END - 40.0:
		var bz := ceilf(-half / WL.BLOCK_SIZE) * WL.BLOCK_SIZE
		while bz + WL.BLOCK_SIZE < half:
			var x0 := bx + WL.STREET_WIDTH
			var z0 := bz + WL.STREET_WIDTH
			var w := WL.BLOCK_SIZE - WL.STREET_WIDTH
			var split := rng.randi_range(1, 2)
			var cell := w / split
			for i in split:
				for j in split:
					var s := cell - 4.0
					var h := 8.0 + rng.randf() * (55.0 if rng.randf() < 0.15 else 22.0)
					var c := Vector3(x0 + cell * (i + 0.5), WL.GROUND_LEVEL + h / 2.0, z0 + cell * (j + 0.5))
					xforms.append(Transform3D(Basis.from_scale(Vector3(s, h, s)), c))
					colors.append(palette[rng.randi() % palette.size()])
					var cs := CollisionShape3D.new()
					var box := BoxShape3D.new()
					box.size = Vector3(s, h, s)
					cs.shape = box
					cs.position = c
					body.add_child(cs)
			bz += WL.BLOCK_SIZE
		bx += WL.BLOCK_SIZE
	parent.add_child(body)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


## Rochers dans la terre et au pied des dunes ; les gros arrêtent la voiture.
static func build_rocks(parent: Node, data: RefCounted) -> void:
	var meshes: Array[ArrayMesh] = []
	for i in 4:
		meshes.append(_rock_mesh(500 + i))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ground/dirt_albedo.png")
	mat.albedo_color = Color(0.85, 0.78, 0.72)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / 2.5
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/ground/dirt_normal.jpg")
	mat.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var half := WL.SIZE / 2.0 - 20.0
	var placed: Array = [[], [], [], []]
	var body := StaticBody3D.new()
	body.name = "Rochers"
	for attempt in 4000:
		if placed[0].size() + placed[1].size() + placed[2].size() + placed[3].size() >= 320:
			break
		var x := lerpf(WL.CITY_END + 20.0, WL.DUNES_END - 30.0, rng.randf())
		var z := lerpf(-half, half, rng.randf())
		var h: float = data.height_at(x, z)
		var s := WL.surface_at(x, z, h)
		var cluster := WL.fbm(x / 45.0 + 30.0, z / 45.0 - 12.0)
		var chance := cluster * 1.4 - 0.35 if s == WL.Surface.DIRT else ((cluster - 0.62) * 0.6 if s == WL.Surface.SAND else 0.0)
		if rng.randf() > chance:
			continue
		if absf(x - WL.SPAWN_X) < 40.0 and absf(z - WL.SPAWN_Z) < 40.0:
			continue
		var scale := 0.4 + pow(rng.randf(), 3.0) * 3.2
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.17, 0.17), rng.randf() * TAU, rng.randf_range(-0.17, 0.17)))
		basis = basis.scaled(Vector3(scale * rng.randf_range(0.8, 1.4), scale * rng.randf_range(0.5, 0.9), scale * rng.randf_range(0.8, 1.4)))
		var xf := Transform3D(basis, Vector3(x, h - scale * 0.25, z))
		var k := rng.randi() % meshes.size()
		placed[k].append(xf)
		if scale > 1.1:
			var cs := CollisionShape3D.new()
			cs.shape = meshes[k].create_convex_shape()
			cs.transform = xf
			body.add_child(cs)
	parent.add_child(body)
	for k in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = placed[k].size()
		for n in placed[k].size():
			mm.set_instance_transform(n, placed[k][n])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		parent.add_child(mmi)


## Rocher : sphère grossière déformée par du bruit, aplatie à la base, à facettes.
static func _rock_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ox := rng.randf() * 100.0
	var oz := rng.randf() * 100.0
	const RINGS := 8
	const SEGS := 12
	var pts: Array[Vector3] = []
	for r in RINGS + 1:
		var lat := PI * r / RINGS
		for g in SEGS + 1:
			var lon := TAU * g / SEGS
			var v := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)) * 0.5
			var d := 0.75 + 0.5 * WL.fbm(v.x * 4.4 + ox, v.z * 4.4 + v.y * 3.4 + oz)
			v *= d
			if v.y < -0.08:
				v.y = -0.08 + (v.y + 0.08) * 0.3
			pts.append(v)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in RINGS:
		for g in SEGS:
			var a := r * (SEGS + 1) + g
			var b := a + SEGS + 1
			for tri in [[a, b, a + 1], [a + 1, b, b + 1]]:
				for i in tri:
					st.add_vertex(pts[i])
	st.generate_normals()
	return st.commit()
