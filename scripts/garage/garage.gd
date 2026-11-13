## Garage 3D (écran principal de la partie idle), mis en scène comme une photo de
## studio de nuit : la voiture choisie en grand, de trois quarts, sur un plateau tournant
## sous un projecteur ; murs de briques sombres, rideau métallique encadré de néons
## orange, enseigne de l'étape (Box, Atelier, Showroom, Hangar) ; sol de béton qui
## reflète les voitures (copies inversées sous un sol un peu transparent : pas de
## post-traitement, tient sur le web) ; faisceaux de lumière et poussière qui flotte ;
## reflets chauds dans la peinture (ciel de studio qui ne sert qu'aux reflets).
## Les voitures garées attendent dans la pénombre, autour. L'interface (garage_ui.gd)
## passe par-dessus ; la caméra décale son cadre (objectif décentré) pour que la voiture
## reste dans la partie libre de l'écran.
extends Node3D

const Economy = preload("res://scripts/core/economy.gd")
const CarModels = preload("res://scripts/game/car_models.gd")

const ORANGE := Color(1.0, 0.48, 0.1)
const RED := Color(1.0, 0.16, 0.08)
const WARM := Color(1.0, 0.86, 0.7)
const PLATE_RADIUS := 3.1
const PLATE_TOP := 0.14
const BAY_W := 3.2
const TEX := "res://assets/garage/"

var game: Node
var camera: Camera3D
var ui: Node
## Part de l'écran couverte par l'interface : en bas (portrait) ou à droite (paysage).
var cover_bottom := 0.45
var cover_right := 0.4
var _bay_cars := {}
var _plate_car: Node3D
var _plate_uid := -1
var _pivot: Node3D
var _ring_mat: StandardMaterial3D
var _ring_flash := 0.0
var _key: SpotLight3D
var _bays: Node3D
var _sign: Label3D
var _sign_glow: Label3D
var _sparks: CPUParticles3D
var _cam_base := Transform3D.IDENTITY
var _shown_stage := -1
var _shown_slots := -1
var _shown_size := Vector2.ZERO
var _t := 0.0
var _flicker := 0.0


func _ready() -> void:
	game = get_node("/root/Game")
	_build_environment()
	_build_room()
	_build_plate()
	_build_atmosphere()
	_bays = Node3D.new()
	add_child(_bays)
	camera = Camera3D.new()
	add_child(camera)
	_place_camera()
	ui = load("res://scripts/garage/garage_ui.gd").new()
	ui.garage = self
	add_child(ui)
	game.changed.connect(_refresh)
	_refresh()


## Cadre : voiture de trois quarts avant, caméra basse (hauteur d'homme accroupi), un
## peu de plongée. Le cadre est décalé pour laisser la place à l'interface.
func _place_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	_shown_size = size
	var portrait := size.y > size.x
	var aspect := size.x / maxf(size.y, 1.0)
	var eye: Vector3
	var look := Vector3(0.0, 0.75, 0.0)
	var fov: float
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.near = 0.1
	camera.far = 60.0
	if portrait:
		eye = Vector3(3.0, 2.2, 6.6)
		fov = 66.0
		camera.keep_aspect = Camera3D.KEEP_WIDTH
	else:
		eye = Vector3(4.6, 2.4, 8.2)
		look = Vector3(0.0, 1.3, 0.0)
		fov = 52.0
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var span := 2.0 * camera.near * tan(deg_to_rad(fov) / 2.0)
	camera.size = span
	if portrait:
		# La voiture au milieu de la partie libre (au-dessus de l'interface).
		var free_center := (1.0 - cover_bottom) * 0.5 + 0.03
		camera.frustum_offset = Vector2(0.0, -(0.5 - free_center) * span / aspect)
	else:
		var free_center := (1.0 - cover_right) * 0.5
		camera.frustum_offset = Vector2((0.5 - free_center) * span * aspect, 0.0)
	camera.look_at_from_position(eye, look, Vector3.UP)
	_cam_base = camera.transform


func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_visible_rect().size != _shown_size:
		_place_camera()
	if _pivot:
		_pivot.rotate_y(delta * 0.22)
	_ring_flash = maxf(0.0, _ring_flash - delta * 1.8)
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = 2.4 + _ring_flash * 7.0
	if _key:
		_key.light_energy = 7.0 + _ring_flash * 6.0
	# Enseigne au néon : quelques ratés de temps en temps.
	_flicker -= delta
	var on := 1.0
	if _flicker < 0.0:
		if _flicker < -0.12:
			_flicker = randf_range(3.0, 9.0)
		on = 0.35 if fmod(_t * 37.0, 1.0) < 0.5 else 1.0
	if _sign:
		_sign.modulate.a = on
		_sign_glow.modulate.a = 0.55 * on
	# Caméra qui respire (glisse très lentement), comme une caméra à l'épaule posée.
	camera.transform = _cam_base.translated_local(Vector3(sin(_t * 0.23) * 0.12, sin(_t * 0.31) * 0.05, 0.0))


# ------------------------------------------------------------------ matériaux

func _tex(name: String) -> Texture2D:
	return load(TEX + name)


func _textured(prefix: String, tint: Color, uv: Vector3, rough_scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(prefix + "_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex(prefix + "_nor_gl.jpg")
	m.roughness_texture = _tex(prefix + "_rough.jpg")
	m.roughness = rough_scale
	m.uv1_scale = uv
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _neon(c: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c.lerp(Color.WHITE, 0.35)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Texture de dégradé (halos, faisceaux, ombres douces).
func _gradient(colors: PackedColorArray, offsets: PackedFloat32Array, radial: bool, vertical := false) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128 if radial else 4
	t.height = 128 if (radial or vertical) else 4
	if radial:
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
	elif vertical:
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
	return t


func _additive(c: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = c
	m.albedo_texture = tex
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Halo doux (disque additif, face à `normal`).
func _halo(pos: Vector3, size: Vector2, c: Color, normal := Vector3.BACK, strength := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var tex := _gradient(PackedColorArray([Color(1, 1, 1, strength), Color(1, 1, 1, strength * 0.35), Color(1, 1, 1, 0)]), PackedFloat32Array([0.0, 0.35, 1.0]), true)
	mi.material_override = _additive(c, tex)
	add_child(mi)
	mi.position = pos
	if normal != Vector3.BACK:
		var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
		mi.look_at(pos - normal, up)
	return mi


# ------------------------------------------------------------------ décor

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.012)
	# Ciel « de studio » : invisible (fond noir), il ne sert qu'aux reflets de la peinture :
	# une longue bande chaude à l'horizon, des boîtes à lumière au-dessus.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.42, 0.36)
	sky_mat.sky_horizon_color = Color(1.0, 0.55, 0.25)
	sky_mat.sky_curve = 0.06
	sky_mat.ground_horizon_color = Color(0.35, 0.14, 0.05)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.42)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.08, 0.05)
	env.fog_density = 0.028
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.08
	var on_web := OS.has_feature("web") or OS.has_feature("mobile")
	env.glow_enabled = not on_web
	env.glow_intensity = 0.6
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_room() -> void:
	# Sol : béton usé, sombre, un peu transparent sur les reflets inversés des voitures.
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 26.0)
	floor.mesh = pm
	var fm := _textured("concrete_floor_worn_001", Color(0.42, 0.4, 0.4, 0.86), Vector3(7, 6, 1), 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.metallic_specular = 0.7
	fm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	floor.material_override = fm
	floor.position = Vector3(0, 0, -1.0)
	add_child(floor)
	# Murs de briques sombres et plafond noir.
	var brick := _textured("dark_brick_wall", Color(0.62, 0.55, 0.52), Vector3(6, 2, 1))
	var brick_side := _textured("dark_brick_wall", Color(0.62, 0.55, 0.52), Vector3(5, 2, 1))
	_box(Vector3(30.0, 8.0, 0.4), Vector3(0, 4.0, -10.2), brick)
	_box(Vector3(0.4, 8.0, 26.0), Vector3(-13.2, 4.0, -1.0), brick_side)
	_box(Vector3(0.4, 8.0, 26.0), Vector3(13.2, 4.0, -1.0), brick_side)
	_box(Vector3(30.0, 0.3, 26.0), Vector3(0, 7.6, -1.0), _textured("dark_brick_wall", Color(0.15, 0.13, 0.13), Vector3(8, 8, 1)))
	# Plinthe peinte (rouge sombre) au bas des murs.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.34, 0.05, 0.03)
	paint.roughness = 0.55
	_box(Vector3(29.6, 0.9, 0.06), Vector3(0, 0.45, -9.97), paint)
	_box(Vector3(0.06, 0.9, 25.6), Vector3(-12.97, 0.45, -1.0), paint)
	_box(Vector3(0.06, 0.9, 25.6), Vector3(12.97, 0.45, -1.0), paint)
	# Rideau métallique au fond, encadré de néons orange.
	var door := _textured("corrugated_iron_02", Color(0.55, 0.5, 0.48), Vector3(3, 1.6, 1), 0.9)
	door.metallic = 0.6
	_box(Vector3(7.0, 4.6, 0.12), Vector3(0, 2.3, -9.94), door)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.08, 0.075, 0.075)
	frame.metallic = 0.8
	frame.roughness = 0.35
	_box(Vector3(7.6, 0.35, 0.3), Vector3(0, 4.75, -9.9), frame)
	for x in [-3.65, 3.65]:
		_box(Vector3(0.3, 4.9, 0.3), Vector3(x, 2.45, -9.9), frame)
	var tube := _neon(ORANGE, 3.2)
	_box(Vector3(7.9, 0.07, 0.07), Vector3(0, 5.05, -9.78), tube)
	for x in [-3.95, 3.95]:
		_box(Vector3(0.07, 5.05, 0.07), Vector3(x, 2.52, -9.78), tube)
	_halo(Vector3(0, 2.6, -9.7), Vector2(11.0, 7.5), ORANGE, Vector3.BACK, 0.22)
	# Bandes de néon rouge le long des murs du fond (rythme, profondeur).
	for x in [-9.5, -6.5, 6.5, 9.5]:
		_box(Vector3(0.06, 3.2, 0.06), Vector3(x, 3.2, -9.95), _neon(RED, 3.0))
		_halo(Vector3(x, 3.2, -9.85), Vector2(1.6, 5.0), RED, Vector3.BACK, 0.35)
	# Enseigne de l'étape, au néon, au-dessus du rideau.
	var font: Font = load("res://assets/fonts/RussoOne-Regular.ttf")
	_sign_glow = Label3D.new()
	_sign_glow.font = font
	_sign_glow.font_size = 150
	_sign_glow.pixel_size = 0.011
	_sign_glow.outline_size = 60
	_sign_glow.modulate = Color(1.0, 0.45, 0.1, 0.55)
	_sign_glow.outline_modulate = Color(1.0, 0.35, 0.05, 0.25)
	_sign_glow.shaded = false
	_sign_glow.double_sided = false
	_sign_glow.position = Vector3(0, 6.05, -9.82)
	add_child(_sign_glow)
	_sign = Label3D.new()
	_sign.font = font
	_sign.font_size = 150
	_sign.pixel_size = 0.011
	_sign.outline_size = 10
	_sign.modulate = Color(1.0, 0.86, 0.62)
	_sign.outline_modulate = Color(1.0, 0.5, 0.12)
	_sign.shaded = false
	_sign.position = Vector3(0, 6.05, -9.78)
	add_child(_sign)
	_halo(Vector3(0, 6.05, -9.7), Vector2(9.0, 3.4), ORANGE, Vector3.BACK, 0.4)
	# Lumières : projecteur du plateau (seul à faire des ombres), contre-jours orange et
	# rouge pour dessiner la carrosserie, lavage du fond, rangées de voitures garées.
	_key = SpotLight3D.new()
	_key.position = Vector3(0.6, 6.6, 1.2)
	_key.look_at_from_position(_key.position, Vector3(0, 0, 0), Vector3.UP)
	_key.spot_angle = 34.0
	_key.spot_angle_attenuation = 0.8
	_key.spot_range = 12.0
	_key.light_energy = 7.0
	_key.light_color = WARM
	_key.shadow_enabled = true
	_key.shadow_blur = 2.0
	add_child(_key)
	_omni(Vector3(-5.0, 1.6, -2.5), ORANGE, 3.2, 9.0)
	_omni(Vector3(5.5, 1.3, -3.0), RED, 2.6, 9.0)
	_omni(Vector3(3.0, 3.5, 6.5), Color(1.0, 0.8, 0.7), 0.7, 12.0)
	_omni(Vector3(0.0, 4.5, -8.0), ORANGE, 2.0, 9.0)
	_omni(Vector3(-9.5, 4.5, 0.0), WARM, 1.2, 10.0)
	_omni(Vector3(9.5, 4.5, 0.0), WARM, 1.2, 10.0)
	# Plafonniers (hors du cadre) : seulement leurs faisceaux au-dessus des rangées.
	for p in [Vector3(-7.5, 7.4, -5.0), Vector3(7.5, 7.4, -5.0)]:
		_beam(p, 7.3, 0.4, 2.4, 0.05)


func _omni(pos: Vector3, c: Color, energy: float, rng: float) -> void:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = c
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.4
	add_child(o)


## Faisceau de lumière (cône additif qui s'efface vers le bas) : l'air poussiéreux.
func _beam(top: Vector3, h: float, r_top: float, r_bottom: float, alpha: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bottom
	cyl.height = h
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	var tex := _gradient(PackedColorArray([Color(1, 1, 1, alpha), Color(1, 1, 1, 0.0)]), PackedFloat32Array([0.0, 1.0]), false, true)
	mi.material_override = _additive(WARM, tex)
	mi.position = top - Vector3(0, h / 2.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_plate() -> void:
	# Plateau : disque noir laqué (un peu transparent : il reflète la voiture), bord en
	# métal, anneau de lumière orange.
	var top := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = PLATE_RADIUS
	cyl.bottom_radius = PLATE_RADIUS
	cyl.height = 0.02
	cyl.radial_segments = 64
	top.mesh = cyl
	var lac := StandardMaterial3D.new()
	lac.albedo_color = Color(0.03, 0.03, 0.035, 0.8)
	lac.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lac.roughness = 0.45
	lac.metallic_specular = 0.12
	top.material_override = lac
	top.position = Vector3(0, PLATE_TOP - 0.01, 0)
	add_child(top)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = PLATE_RADIUS + 0.12
	rc.bottom_radius = PLATE_RADIUS + 0.18
	rc.height = PLATE_TOP - 0.02
	rc.radial_segments = 64
	rim.mesh = rc
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.25, 0.24, 0.24)
	steel.metallic = 0.9
	steel.roughness = 0.3
	rim.material_override = steel
	rim.position = Vector3(0, (PLATE_TOP - 0.02) / 2.0, 0)
	add_child(rim)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = PLATE_RADIUS + 0.12
	tor.outer_radius = PLATE_RADIUS + 0.19
	tor.rings = 64
	tor.ring_segments = 8
	ring.mesh = tor
	_ring_mat = _neon(ORANGE, 2.4)
	ring.material_override = _ring_mat
	ring.position = Vector3(0, PLATE_TOP - 0.02, 0)
	add_child(ring)
	_halo(Vector3(0, 0.03, 0), Vector2(PLATE_RADIUS * 3.0, PLATE_RADIUS * 3.0), ORANGE, Vector3.UP, 0.28)
	# Faisceau du projecteur sur la voiture.
	_beam(Vector3(0.4, 6.6, 0.9), 6.4, 0.5, PLATE_RADIUS * 1.05, 0.07)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, PLATE_TOP, 0)
	_pivot.rotation.y = 0.75
	add_child(_pivot)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 60
	_sparks.lifetime = 1.0
	_sparks.explosiveness = 0.95
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_sparks.emission_ring_radius = PLATE_RADIUS + 0.15
	_sparks.emission_ring_inner_radius = PLATE_RADIUS
	_sparks.emission_ring_height = 0.05
	_sparks.emission_ring_axis = Vector3.UP
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.5
	_sparks.gravity = Vector3(0, -7.0, 0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	_sparks.mesh = sm
	_sparks.material_override = _neon(Color(1.0, 0.72, 0.3), 5.0)
	_sparks.position = Vector3(0, PLATE_TOP, 0)
	add_child(_sparks)


## Poussière qui flotte dans la lumière (petits points additifs, lents).
func _build_atmosphere() -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(4.5, 2.5, 4.0)
	dust.position = Vector3(0, 2.6, 0)
	dust.direction = Vector3(0.3, 1, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.12
	dust.gravity = Vector3(0, -0.01, 0)
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	dust.mesh = q
	var tex := _gradient(PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)]), PackedFloat32Array([0.0, 1.0]), true)
	var m := _additive(Color(1.0, 0.85, 0.65, 0.6), tex)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust.material_override = m
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	dust.scale_amount_curve = curve
	add_child(dust)


# ------------------------------------------------------------------ places

## Place n (0 à 19) : rangée du fond de part et d'autre du rideau, puis le long des murs,
## en épi ; les voitures regardent vers le centre.
func bay_transform(n: int) -> Transform3D:
	var pos: Vector3
	var yaw: float
	if n < 6:
		var xs := [-6.2, 6.2, -9.0, 9.0, -11.8, 11.8]
		pos = Vector3(xs[n], 0.0, -7.2)
		yaw = -signf(xs[n]) * 0.35
	else:
		var k := (n - 6) / 2
		var side := -1.0 if (n - 6) % 2 == 0 else 1.0
		pos = Vector3(side * 10.4, 0.0, -2.6 + k * BAY_W)
		yaw = -side * (PI / 2.0 - 0.45)
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _bay_lines(n: int, owned: bool) -> void:
	var xf := bay_transform(n)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.72, 0.3, 0.75) if owned else Color(0.95, 0.72, 0.3, 0.25)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.roughness = 0.7
	for dx in [-BAY_W / 2.0, BAY_W / 2.0]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.09, 0.006, 5.2)
		mi.mesh = b
		mi.material_override = paint
		mi.transform = xf * Transform3D(Basis.IDENTITY, Vector3(dx, 0.004, 0.0))
		_bays.add_child(mi)
	if not owned:
		var plus := Label3D.new()
		plus.text = "+"
		plus.font = load("res://assets/fonts/RussoOne-Regular.ttf")
		plus.font_size = 120
		plus.pixel_size = 0.01
		plus.modulate = Color(1.0, 0.6, 0.2, 0.55)
		plus.shaded = false
		plus.transform = xf * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.02, 0))
		_bays.add_child(plus)


## Voiture du garage : modèle repeint, son reflet dans le sol (copie inversée) et une
## ombre douce dessous.
func _car_node(car: Dictionary) -> Node3D:
	var node := Node3D.new()
	var kit := CarModels.kit_for(String(car["model"]))
	var paint := CarModels.color_of(car)
	node.add_child(CarModels.showroom(kit, paint))
	var mirror := Node3D.new()
	mirror.scale = Vector3(1, -1, 1)
	mirror.add_child(CarModels.showroom(kit, paint))
	node.add_child(mirror)
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.9, 5.6)
	sh.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _gradient(PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0)]), PackedFloat32Array([0.0, 0.5, 1.0]), true)
	sh.material_override = m
	sh.rotation.x = -PI / 2.0
	sh.position.y = 0.012
	node.add_child(sh)
	return node


## Remet le garage d'accord avec la partie : enseigne, places, voitures garées, plateau.
func _refresh() -> void:
	if _shown_stage != game.stage:
		_shown_stage = game.stage
		var name := String(Economy.STAGES[game.stage]["name"]).to_upper()
		_sign.text = name
		_sign_glow.text = name
	if _shown_slots != game.slots:
		_shown_slots = game.slots
		for c in _bays.get_children():
			c.queue_free()
		for n in mini(game.slots + 1, Economy.MAX_SLOTS):
			_bay_lines(n, n < game.slots)
	var want := {}
	for i in game.parked.size():
		var uid: int = game.parked[i]
		if uid != game.selected:
			want[uid] = i
	for uid in _bay_cars.keys():
		if not want.has(uid):
			(_bay_cars[uid] as Node3D).queue_free()
			_bay_cars.erase(uid)
	for uid in want:
		var node: Node3D = _bay_cars.get(uid)
		if node == null:
			node = _car_node(game.get_car(uid))
			add_child(node)
			_bay_cars[uid] = node
		node.transform = bay_transform(int(want[uid]))
	if _plate_uid != game.selected:
		_show_on_plate(game.selected)


func _show_on_plate(uid: int) -> void:
	_plate_uid = uid
	if _plate_car:
		_plate_car.queue_free()
		_plate_car = null
	var car: Dictionary = game.get_car(uid)
	if car.is_empty():
		return
	_plate_car = _car_node(car)
	_pivot.add_child(_plate_car)
	# Arrivée : la voiture descend sur le plateau avec un petit rebond, l'anneau s'allume.
	_plate_car.position.y = 1.2
	_plate_car.scale = Vector3(0.94, 0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_plate_car, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_plate_car, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ring_flash = 1.0


## Amélioration achetée : la voiture rebondit, l'anneau et le projecteur s'illuminent,
## des étincelles jaillissent du bord du plateau.
func celebrate(big: bool) -> void:
	_ring_flash = 1.0
	_sparks.amount = 90 if big else 45
	_sparks.restart()
	_sparks.emitting = true
	if _plate_car:
		var tw := create_tween()
		_plate_car.scale = Vector3(1.03, 0.93, 1.03)
		tw.tween_property(_plate_car, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Voiture garée la plus proche d'un point de l'écran (la toucher la choisit).
func car_at_screen(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for uid in _bay_cars:
		var node := _bay_cars[uid] as Node3D
		if camera.is_position_behind(node.global_position):
			continue
		var sp := camera.unproject_position(node.global_position + Vector3(0, 0.7, 0))
		var d := sp.distance_to(p)
		if d < best_d:
			best_d = d
			best = uid
	var vp := get_viewport().get_visible_rect().size
	return best if best_d < minf(vp.x, vp.y) * 0.1 else -1
