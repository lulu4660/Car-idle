## Garage 3D (écran principal de la partie idle) : un garage de nuit, béton sombre et
## brillant, néons orange, enseigne de l'étape (Box, Atelier, Showroom, Hangar). Les
## voitures garées attendent dans leurs places peintes ; la voiture choisie tourne sur un
## plateau sous un projecteur. L'interface (garage_ui.gd) passe par-dessus.
## Places : rangée du fond, puis murs de gauche et de droite (jusqu'à 20).
extends Node3D

const Economy = preload("res://scripts/core/economy.gd")
const CarModels = preload("res://scripts/game/car_models.gd")

const ORANGE := Color(1.0, 0.5, 0.12)
const RED := Color(1.0, 0.18, 0.1)
const PLATE := Vector3(0.0, 0.0, 2.0)
const PLATE_RADIUS := 3.3
const BAY_W := 3.3
const BAY_LEN := 5.6

var game: Node
var camera: Camera3D
var ui: Node
## Voitures dans leurs places : uid -> nœud.
var _bay_cars := {}
var _plate_car: Node3D
var _plate_uid := -1
var _plate_pivot: Node3D
var _ring_mat: StandardMaterial3D
var _ring_flash := 0.0
var _bays: Node3D
var _sign: Label3D
var _sparks: CPUParticles3D
var _cam_base := Transform3D.IDENTITY
var _shown_stage := -1
var _shown_slots := -1
var _shown_size := Vector2.ZERO


func _ready() -> void:
	game = get_node("/root/Game")
	_build_room()
	_build_plate()
	_bays = Node3D.new()
	add_child(_bays)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 62.0
	camera.near = 0.2
	camera.far = 120.0
	add_child(camera)
	_place_camera()
	ui = load("res://scripts/garage/garage_ui.gd").new()
	ui.garage = self
	add_child(ui)
	game.changed.connect(_refresh)
	_refresh()


func _place_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	_shown_size = size
	var portrait := size.y > size.x
	# La fiche des pièces couvre le bas (portrait) ou la droite (paysage) de l'écran : le
	# cadre de la caméra est décalé (objectif décentré) pour que le garage remplisse la
	# partie libre, sans pencher la vue.
	var eye := Vector3(0.0, 9.5, 12.0) if portrait else Vector3(0.0, 7.5, 14.0)
	var look := Vector3(0.0, 0.0, -3.0) if portrait else Vector3(0.0, 0.6, -2.0)
	var fov := 78.0 if portrait else 56.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	var near := 0.2
	var span := 2.0 * near * tan(deg_to_rad(fov) / 2.0)   # largeur (portrait) ou hauteur (paysage)
	camera.size = span
	var aspect := size.x / maxf(size.y, 1.0)
	if portrait:
		# Contenu remonté de 17 % de la hauteur de l'écran.
		camera.frustum_offset = Vector2(0.0, -0.17 * span / aspect)
	else:
		# Contenu poussé de 20 % de la largeur vers la gauche.
		camera.frustum_offset = Vector2(0.2 * span * aspect, 0.0)
	camera.near = near
	camera.look_at_from_position(eye, look, Vector3.UP)
	_cam_base = camera.transform


func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _shown_size:
		_place_camera()
	if _plate_pivot:
		_plate_pivot.rotate_y(delta * 0.35)
	_ring_flash = maxf(0.0, _ring_flash - delta * 2.0)
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = 2.2 + _ring_flash * 6.0
	# Caméra qui respire un peu (vivant, sans gêner la lecture).
	var t := Time.get_ticks_msec() / 1000.0
	camera.transform = _cam_base.translated_local(Vector3(sin(t * 0.21) * 0.25, sin(t * 0.17) * 0.12, 0.0))


# ------------------------------------------------------------------ décor

func _mat(c: Color, rough := 0.8, spec := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = spec
	return m


func _neon_mat(c: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


## Halo doux (disque additif) autour d'un néon ou d'une lampe : pas de post-traitement.
func _halo(pos: Vector3, size: Vector2, c: Color, face := Vector3.BACK) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.55))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	if face != Vector3.BACK:
		mi.look_at(pos + face, Vector3.UP if absf(face.y) < 0.9 else Vector3.FORWARD)
		mi.rotate_object_local(Vector3.UP, PI)


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.013, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.5)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	var on_web := OS.has_feature("web") or OS.has_feature("mobile")
	env.glow_enabled = not on_web
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.0
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Sol : béton sombre, assez lisse pour accrocher les néons.
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30.0, 26.0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	floor.mesh = pm
	var fm := _mat(Color(0.08, 0.075, 0.078), 0.6, 0.3)
	floor.material_override = fm
	floor.position = Vector3(0, 0, -1.0)
	add_child(floor)
	# Murs : fond et côtés, gris charbon ; plinthe et bande peinte.
	var wall := _mat(Color(0.085, 0.08, 0.085), 0.9, 0.2)
	_box(Vector3(30.0, 7.0, 0.4), Vector3(0, 3.5, -14.0), wall)
	_box(Vector3(0.4, 7.0, 26.0), Vector3(-15.0, 3.5, -1.0), wall)
	_box(Vector3(0.4, 7.0, 26.0), Vector3(15.0, 3.5, -1.0), wall)
	var stripe := _mat(Color(0.55, 0.12, 0.06), 0.7, 0.3)
	_box(Vector3(29.6, 0.5, 0.05), Vector3(0, 1.0, -13.78), stripe)
	_box(Vector3(0.05, 0.5, 25.6), Vector3(-14.78, 1.0, -1.0), stripe)
	_box(Vector3(0.05, 0.5, 25.6), Vector3(14.78, 1.0, -1.0), stripe)
	# Néons : un long tube orange en haut du mur du fond, deux tubes rouges verticaux.
	_box(Vector3(24.0, 0.12, 0.12), Vector3(0, 5.6, -13.7), _neon_mat(ORANGE, 3.0))
	_halo(Vector3(0, 5.6, -13.6), Vector2(30.0, 3.5), ORANGE)
	for x in [-13.0, 13.0]:
		_box(Vector3(0.12, 4.0, 0.12), Vector3(x, 3.4, -13.7), _neon_mat(RED, 3.0))
		_halo(Vector3(x, 3.4, -13.6), Vector2(2.6, 6.0), RED)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.12, 0.12, 10.0), Vector3(side * 14.7, 5.6, -8.0), _neon_mat(ORANGE, 2.5))
		_halo(Vector3(side * 14.6, 5.6, -8.0), Vector2(13.0, 3.0), ORANGE, Vector3(-side, 0, 0))
	# Enseigne de l'étape.
	_sign = Label3D.new()
	_sign.font = load("res://assets/fonts/RussoOne-Regular.ttf")
	_sign.font_size = 160
	_sign.pixel_size = 0.012
	_sign.modulate = Color(1.0, 0.62, 0.25)
	_sign.outline_modulate = Color(1.0, 0.35, 0.05, 0.35)
	_sign.outline_size = 24
	_sign.position = Vector3(0, 3.6, -13.75)
	_sign.shaded = false
	add_child(_sign)
	_halo(Vector3(0, 3.6, -13.6), Vector2(10.0, 4.0), ORANGE)
	# Lumières : le projecteur du plateau, des lampes chaudes au plafond, l'orange des néons.
	var spot := SpotLight3D.new()
	spot.position = PLATE + Vector3(0, 9.0, 1.5)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.spot_angle = 30.0
	spot.spot_range = 16.0
	spot.light_energy = 9.0
	spot.light_color = Color(1.0, 0.93, 0.84)
	spot.spot_attenuation = 0.6
	add_child(spot)
	for p in [Vector3(-8, 5.5, -8), Vector3(8, 5.5, -8), Vector3(-10, 5.0, 2), Vector3(10, 5.0, 2)]:
		var o := OmniLight3D.new()
		o.position = p
		o.omni_range = 13.0
		o.light_energy = 1.6
		o.light_color = Color(1.0, 0.62, 0.32)
		add_child(o)
	var back := OmniLight3D.new()
	back.position = Vector3(0, 4.5, -12.0)
	back.omni_range = 12.0
	back.light_energy = 1.4
	back.light_color = ORANGE
	add_child(back)


func _build_plate() -> void:
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = PLATE_RADIUS
	cyl.bottom_radius = PLATE_RADIUS + 0.1
	cyl.height = 0.16
	cyl.radial_segments = 48
	base.mesh = cyl
	base.material_override = _mat(Color(0.11, 0.105, 0.11), 0.25, 0.8)
	base.position = PLATE + Vector3(0, 0.08, 0)
	add_child(base)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = PLATE_RADIUS + 0.02
	tor.outer_radius = PLATE_RADIUS + 0.14
	tor.rings = 48
	ring.mesh = tor
	_ring_mat = _neon_mat(ORANGE, 2.2)
	ring.material_override = _ring_mat
	ring.position = PLATE + Vector3(0, 0.12, 0)
	add_child(ring)
	_halo(PLATE + Vector3(0, 0.05, 0), Vector2(PLATE_RADIUS * 2.9, PLATE_RADIUS * 2.9), ORANGE, Vector3.UP)
	_plate_pivot = Node3D.new()
	_plate_pivot.position = PLATE + Vector3(0, 0.16, 0)
	_plate_pivot.rotation.y = 0.6
	add_child(_plate_pivot)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 40
	_sparks.lifetime = 0.9
	_sparks.explosiveness = 0.95
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_sparks.emission_ring_radius = PLATE_RADIUS
	_sparks.emission_ring_inner_radius = PLATE_RADIUS * 0.9
	_sparks.emission_ring_height = 0.1
	_sparks.emission_ring_axis = Vector3.UP
	_sparks.direction = Vector3.UP
	_sparks.spread = 30.0
	_sparks.initial_velocity_min = 2.5
	_sparks.initial_velocity_max = 5.0
	_sparks.gravity = Vector3(0, -6.0, 0)
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	_sparks.mesh = sm
	_sparks.material_override = _neon_mat(Color(1.0, 0.7, 0.3), 4.0)
	_sparks.position = PLATE + Vector3(0, 0.2, 0)
	add_child(_sparks)


# ------------------------------------------------------------------ places

## Position et orientation (vers le plateau) de la place n (0 à 19).
func bay_transform(n: int) -> Transform3D:
	var pos: Vector3
	var yaw: float
	if n < 8:
		pos = Vector3((n - 3.5) * BAY_W, 0.0, -10.4)
		yaw = 0.0
	else:
		var k := (n - 8) / 2
		var side := -1.0 if (n - 8) % 2 == 0 else 1.0
		pos = Vector3(side * 11.6, 0.0, -5.4 + k * BAY_W)
		yaw = -side * PI / 2.0
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _bay_lines(n: int, owned: bool) -> void:
	var xf := bay_transform(n)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.8, 0.7, 0.85) if owned else Color(0.5, 0.45, 0.4, 0.35)
	paint.roughness = 0.6
	if not owned:
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for dx in [-BAY_W / 2.0, BAY_W / 2.0]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.1, 0.012, BAY_LEN)
		mi.mesh = b
		mi.material_override = paint
		mi.transform = xf * Transform3D(Basis.IDENTITY, Vector3(dx, 0.006, 0.0))
		_bays.add_child(mi)
	var num := Label3D.new()
	num.text = str(n + 1) if owned else "+"
	num.font = load("res://assets/fonts/RussoOne-Regular.ttf")
	num.font_size = 96
	num.pixel_size = 0.008
	num.modulate = Color(0.85, 0.8, 0.7, 0.5) if owned else Color(1.0, 0.55, 0.2, 0.6)
	num.shaded = false
	num.transform = xf * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.02, -BAY_LEN / 2.0 + 0.7))
	_bays.add_child(num)


func _car_node(car: Dictionary) -> Node3D:
	var node := Node3D.new()
	var kit := CarModels.kit_for(String(car["model"]))
	node.add_child(CarModels.showroom(kit, CarModels.color_of(car)))
	# Ombre douce sous la voiture (disque sombre).
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 5.2)
	sh.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.65))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = tex
	sh.material_override = m
	sh.rotation.x = -PI / 2.0
	sh.position.y = 0.015
	node.add_child(sh)
	return node


## Remet le garage d'accord avec la partie : enseigne, places, voitures garées, plateau.
func _refresh() -> void:
	if _shown_stage != game.stage:
		_shown_stage = game.stage
		_sign.text = String(Economy.STAGES[game.stage]["name"]).to_upper()
	if _shown_slots != game.slots:
		_shown_slots = game.slots
		for c in _bays.get_children():
			c.queue_free()
		for n in mini(game.slots + 1, Economy.MAX_SLOTS):
			_bay_lines(n, n < game.slots)
	# Voitures garées : une par place, sauf celle du plateau.
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
		node.transform = bay_transform(int(want[uid])) * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3))
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
	_plate_pivot.add_child(_plate_car)
	# Arrivée : la voiture monte du plateau avec un petit rebond.
	_plate_car.position.y = -1.6
	var tw := create_tween()
	tw.tween_property(_plate_car, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ring_flash = 1.0


## Amélioration achetée : la voiture rebondit, l'anneau s'illumine, des étincelles.
func celebrate(big: bool) -> void:
	_ring_flash = 1.0
	_sparks.amount = 60 if big else 30
	_sparks.restart()
	_sparks.emitting = true
	if _plate_car:
		var tw := create_tween()
		_plate_car.scale = Vector3(1.04, 0.9, 1.04)
		tw.tween_property(_plate_car, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Voiture garée la plus proche d'un point de l'écran (choisir une voiture en la touchant).
func car_at_screen(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for uid in _bay_cars:
		var node := _bay_cars[uid] as Node3D
		var sp := camera.unproject_position(node.global_position + Vector3(0, 0.7, 0))
		var d := sp.distance_to(p)
		if d < best_d:
			best_d = d
			best = uid
	var vp := get_viewport().get_visible_rect().size
	return best if best_d < minf(vp.x, vp.y) * 0.09 else -1
