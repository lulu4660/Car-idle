## Construit le décor de la balade autour du terrain : ciel et soleil d'après-midi, brume, post-traitement, mer animée, sable à
## perte de vue, limites du monde, immeubles de la ville et rochers.
extends RefCounted

const WL = preload("res://scripts/core/world_layout.gd")
const Waves = preload("res://scripts/balade/waves.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")

## Soleil d'après-midi (34°) au sud-ouest : ombres nettes et assez longues, le sable modelé
## par la lumière rasante sur les versants, image claire comme une vidéo de drone en plein jour.
const SUN_ELEVATION := 34.0
const SUN_AZIMUTH := 225.0  # degrés depuis le nord, dans le sens des aiguilles d'une montre
const SUN_COLOR := Color(1.0, 0.89, 0.76)
## Horizon : la brume légère s'y fond.
const HAZE_COLOR := Color(0.88, 0.80, 0.78)
## Lumière ambiante (couleur des ombres) : lavande, pour des ombres colorées sur le sol chaud.
const SHADOW_TINT := Color(0.60, 0.60, 0.80)


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
	# Style « rallye low poly » : ombres teintées (lavande) plutôt que grises, lumière mate.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SHADOW_TINT
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Rendu cinéma : ACES, image claire, halo léger sur les reflets.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 0.9

	# Brume chaude : le lointain se fond dans une lumière poudrée (perspective aérienne).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = HAZE_COLOR
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.4
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
	sun.light_energy = 1.8
	# Pas d'ombres en temps réel : le décor fixe a ses ombres précalculées
	# (tools/bake_shadows.gd) et l'ombre de la voiture est calculée par le terrain
	# (shaders/car_shadow.gdshaderinc). Plus rapide, et bords lisses partout.
	sun.shadow_enabled = false
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.4
	parent.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_direction(), Vector3.UP)
	return sun


## Mer : une mer plate et grossière jusqu'à l'horizon (la grille fine qui suit la voiture
## est fabriquée par balade.gd). Rend [matériau de la grille fine, matériau de la mer plate].
static func build_sea(parent: Node, data: RefCounted, height_tex: Texture2D) -> Array[ShaderMaterial]:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	mat.set_shader_parameter("height_tex", height_tex)
	mat.set_shader_parameter("res", data.res)
	mat.set_shader_parameter("world_size", WL.SIZE)
	mat.set_shader_parameter("sea_level", WL.SEA_LEVEL)
	mat.set_shader_parameter("wave_height", Waves.WAVE_HEIGHT)
	mat.set_shader_parameter("ripple_tex", load("res://assets/water/ripples.png"))
	var far_mat := mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("is_near", true)
	var r := WorldData.SEA_RECT
	# Le long de la côte, des carreaux de 16 m suffisent : le rivage suit le sable.
	_sea_mesh(parent, far_mat, r, 16.0, 16.0)
	var far := 4000.0
	_sea_mesh(parent, far_mat, Rect2(r.end.x, -far, far, far * 2.0), 400.0, 400.0)
	_sea_mesh(parent, far_mat, Rect2(r.position.x, r.end.y, r.size.x, far - r.end.y), 60.0, 400.0)
	_sea_mesh(parent, far_mat, Rect2(r.position.x, -far, r.size.x, r.position.y + far), 60.0, 400.0)
	return [mat, far_mat]


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


## Montagnes à l'horizon : la chaîne qui ferme la vallée continue au-delà des bords de la
## carte (nord, sud, ouest) en low poly à facettes, roche puis neige, et descend dans la mer
## à l'est. Un seul maillage, couleurs par sommet, brume par-dessus.
static func build_far_ground(parent: Node) -> void:
	var half := WL.SIZE / 2.0
	var step := 24.0
	var reach := 1400.0
	var n := int(ceil((reach * 2.0) / step))
	var x0 := -reach
	var z0 := -reach
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			var inside := absf(x) <= half and absf(z) <= half
			# Au bord de la carte, la même hauteur que le terrain (pas de marche).
			var cx := clampf(x, -half, half)
			var cz := clampf(z, -half, half)
			var h: float
			if inside:
				h = WL.height(x, z) - 2.0
			elif absf(x) <= half + step and absf(z) <= half + step:
				h = lerpf(WL.height(cx, cz), WL.far_height(x, z), 0.35)
			else:
				h = WL.far_height(x, z)
			hs[j * (n + 1) + i] = h
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x := x0 + i * step
			var z := z0 + j * step
			# Rien sous la carte elle-même (le terrain la couvre).
			if x >= -half and x + step <= half and z >= -half and z + step <= half:
				continue
			var p00 := Vector3(x, hs[j * (n + 1) + i], z)
			var p10 := Vector3(x + step, hs[j * (n + 1) + i + 1], z)
			var p01 := Vector3(x, hs[(j + 1) * (n + 1) + i], z + step)
			var p11 := Vector3(x + step, hs[(j + 1) * (n + 1) + i + 1], z + step)
			if maxf(maxf(p00.y, p10.y), maxf(p01.y, p11.y)) < WL.SEA_LEVEL - 1.0:
				continue
			for tri in [[p00, p11, p10], [p00, p01, p11]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var nrm := (c - a).cross(b - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				var hy := (a.y + b.y + c.y) / 3.0
				st.set_normal(nrm)
				st.set_color(_mountain_color(hy, 1.0 - nrm.y, a.x * 0.37 + a.z * 0.71))
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Horizon"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Couleur d'une facette de montagne : forêt au pied, roche, neige au sommet.
static func _mountain_color(h: float, steep: float, seed: float) -> Color:
	var j := fposmod(sin(seed) * 437.585, 1.0)
	var c := Color(0.36, 0.45, 0.25).lerp(Color(0.30, 0.38, 0.22), j)
	if h > 30.0 or steep > 0.35:
		c = Color(0.52, 0.47, 0.47).lerp(Color(0.42, 0.37, 0.39), j)
	if h > 68.0 + j * 10.0 and steep < 0.55:
		c = Color(0.93, 0.92, 0.95)
	return c


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
	var r := rock_placements(data)
	var meshes: Array = r[0]
	var placed: Array = r[1]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var body := StaticBody3D.new()
	body.name = "Rochers"
	# Collision pour les rochers assez gros (même choix qu'avant le partage du placement).
	for big in r[2]:
		var cs := CollisionShape3D.new()
		cs.shape = (meshes[big[0]] as ArrayMesh).create_convex_shape()
		cs.transform = big[1]
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


## Places des grands rochers : [maillages, positions par maillage, gros rochers à collision]. Partagé avec le calcul
## des ombres (tools/bake_shadows.gd).
static func rock_placements(data: RefCounted) -> Array:
	# Rochers du Stylized Nature MegaKit (Quaternius, CC0), à la taille des anciens rochers
	# générés ; couleur par sommet.
	var meshes: Array[ArrayMesh] = []
	for name in ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Rock_Medium_2"]:
		meshes.append(load("res://scripts/balade/megakit.gd").unit_rock(name))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var half := WL.SIZE / 2.0 - 20.0
	var placed: Array = [[], [], [], []]
	var big: Array = []
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
			big.append([k, xf])
	return [meshes, placed, big]


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
	st.set_smooth_group(-1)
	for r in RINGS:
		for g in SEGS:
			var a := r * (SEGS + 1) + g
			var b := a + SEGS + 1
			for tri in [[a, b, a + 1], [a + 1, b, b + 1]]:
				for i in tri:
					st.add_vertex(pts[i])
	st.generate_normals()
	return st.commit()
