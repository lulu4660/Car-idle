## Point d'entrée de la balade : charge le monde précalculé, construit le décor, la voiture,
## la caméra drone, les commandes et l'affichage. Gère les effets de roues (traces,
## poussière) et la réception des sauts (le sable se creuse, gerbe, secousse).
## C (ou VOITURE) passe au modèle suivant du kit, pour comparer les réglages.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")
const WorldBuilder = preload("res://scripts/balade/world_builder.gd")
const Car = preload("res://scripts/balade/car.gd")

@export var start_model := "concept"
## Qualité : 1 = PC (tout), 0 = iPhone et web (réglée pour 60 images/s). -1 = automatique.
@export var force_quality := -1
var low_quality := false

var data: RefCounted
var terrain: Node3D
var effects: Node3D
var ruts: Node3D
## Largeur d'un pneu (m) pour les ornières.
const TYRE_WIDTH := 0.28
var decor: Node3D
var controls: CanvasLayer
var camera: Camera3D
var car: VehicleBody3D
var model_index := 0

# Réception de saut.
var _air_time := 0.0
var _fall_speed := 0.0
var _was_airborne := false

var _hud_speed: Label
var _hud_info: Label


func _ready() -> void:
	data = WorldData.load_baked()
	if data == null:
		return
	low_quality = force_quality == 0 or (force_quality < 0 and (OS.has_feature("web") or OS.has_feature("mobile")))
	var sun := WorldBuilder.build_environment(self)
	_apply_quality(sun)
	terrain = load("res://scripts/balade/terrain.gd").new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.near_range = 130.0 if low_quality else 180.0
	terrain.build(data)
	terrain.material().set_shader_parameter("low_quality", low_quality)
	ruts = load("res://scripts/balade/ruts.gd").new()
	ruts.name = "Ornieres"
	add_child(ruts)
	ruts.mesh_step = 0.2 if low_quality else 0.125
	ruts.build(terrain.material())
	WorldBuilder.build_sea(self, data, terrain.height_texture())
	WorldBuilder.build_far_ground(self)
	WorldBuilder.build_walls(self)
	WorldBuilder.build_city(self)
	WorldBuilder.build_rocks(self, data)

	effects = load("res://scripts/balade/effects.gd").new()
	effects.name = "Effets"
	add_child(effects)
	effects.set_sun(WorldBuilder.sun_direction(), WorldBuilder.SUN_COLOR)

	controls = load("res://scripts/balade/controls.gd").new()
	add_child(controls)

	camera = load("res://scripts/balade/drone_camera.gd").new()
	camera.name = "Camera"
	camera.far = 3000.0
	camera.near = 0.3
	camera.world_data = data
	add_child(camera)
	camera.make_current()

	decor = load("res://scripts/balade/decor.gd").new()
	decor.name = "Decor"
	add_child(decor)

	_build_hud()
	model_index = maxi(0, Car.MODELS.find(start_model))
	var y: float = data.height_at(WL.SPAWN_X, WL.SPAWN_Z) + 1.2
	# Départ au bord de la plage, vers le nord, le long du rivage : la caméra drone, côté
	# dunes, voit la voiture, la plage et la mer d'un seul coup d'œil.
	_spawn(Vector3(WL.SPAWN_X, y, WL.SPAWN_Z), PI)


## Réglages selon l'appareil. iPhone et web : image calculée à 70 % de la résolution (le
## texte et les boutons restent nets), pas de MSAA (FXAA à la place), ombres sur 90 m
## avec une carte plus petite, pas de halo, terrain sans seconde échelle de texture.
func _apply_quality(sun: DirectionalLight3D) -> void:
	var vp := get_viewport()
	if low_quality:
		vp.scaling_3d_scale = 0.7
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 90.0
		for n in get_children():
			if n is WorldEnvironment:
				(n as WorldEnvironment).environment.glow_enabled = false
				(n as WorldEnvironment).environment.ssao_enabled = false
	else:
		vp.msaa_3d = Viewport.MSAA_2X


func _spawn(pos: Vector3, yaw: float) -> void:
	car = Car.create(Car.MODELS[model_index], controls)
	car.world_data = data
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	camera.target = car
	camera.snap()
	if decor.data == null:
		decor.low_quality = low_quality
		decor.build(data, car)
	else:
		decor.target = car


func _process(delta: float) -> void:
	if car == null:
		return
	if controls.camera_requested:
		camera.next_mode()
	if controls.next_car_requested:
		model_index = (model_index + 1) % Car.MODELS.size()
		var pos := car.global_position + Vector3.UP * 0.5
		var yaw := car.rotation.y
		car.queue_free()
		_spawn(pos, yaw)
		return
	_wheel_effects(delta)
	ruts.follow(car.global_position)
	_hud_speed.text = "%d km/h" % roundi(car.speed_kmh)
	var ground: String = "Eau" if car.in_water else WL.SURFACE_NAMES[car.wheel_surface[2]]
	_hud_info.text = "%s  ·  %s  ·  %s  ·  %s  ·  %d i/s" % [ground, car.model_name, Car.DRIVE_NAMES[car.drive], camera.MODE_NAMES[camera.mode], Engine.get_frames_per_second()]


func _wheel_effects(delta: float) -> void:
	var speed: float = car.speed_kmh
	var drift := clampf((absf(car.slip_angle) - 8.0) / 25.0, 0.0, 1.0)
	var heading: Vector3 = car.global_basis.z
	for i in 4:
		var w: VehicleWheel3D = car.wheels[i]
		if not w.is_in_contact():
			effects.lift(i)
			ruts.lift(i)
			continue
		var p := w.get_contact_point()
		var n := w.get_contact_normal()
		var s: int = car.wheel_surface[i]
		var slip: float = car.wheel_slip[i]
		var soft := WL.is_soft(s)
		# Sable et terre : la roue creuse une vraie ornière. Bitume : trace de gomme si ça glisse.
		if soft:
			effects.lift(i)
			ruts.dig(i, p, s, TYRE_WIDTH, 1.0, clampf(slip + drift * 0.6, 0.0, 1.0))
		elif s == WL.Surface.ASPHALT and speed > 2.0 and (slip > 0.35 or drift > 0.2):
			ruts.lift(i)
			effects.track(i, p, n, heading, s, w.wheel_radius * 1.2)
		else:
			effects.lift(i)
			ruts.lift(i)
		# Poussière : sur le bitume seulement quand ça glisse ; panache en dérapage.
		var amount := 0.0
		if s == WL.Surface.ASPHALT:
			amount = clampf((slip - 0.5) * 1.5 + drift * 0.6, 0.0, 1.0) * clampf(speed / 30.0, 0.0, 1.0)
		else:
			amount = clampf(speed / 70.0, 0.0, 1.0) * (1.0 if i >= 2 else 0.5) + clampf(slip - 0.3, 0.0, 1.0)
			amount += drift * 1.5 * (1.0 if i >= 2 else 0.3)
		if s == WL.Surface.WET_SAND:
			amount *= 0.4
		var rate := amount * 55.0 * delta
		var count := int(rate) + (1 if randf() < fmod(rate, 1.0) else 0)
		var c: Color = effects.DUST_COLORS[s]
		for k in count:
			var back := -heading * randf_range(0.5, 2.5) * clampf(speed / 40.0, 0.0, 1.0)
			var v := back + Vector3.UP * randf_range(0.6, 4.0 if s == WL.Surface.WATER else 1.6) + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 1.2
			var size := randf_range(1.0, 2.0) * (1.6 if s == WL.Surface.SAND else 1.0) * (1.0 + drift * 0.6)
			effects.dust(p + Vector3.UP * 0.2, v, Color(c.r, c.g, c.b, c.a * randf_range(0.6, 1.0)), size, randf_range(1.6, 3.4) * (0.45 if s == WL.Surface.WATER else 1.0))


func _physics_process(delta: float) -> void:
	if car == null:
		return
	var grounded := 0
	for w in car.wheels:
		if w.is_in_contact():
			grounded += 1
	var vy := car.linear_velocity.y
	if grounded == 0:
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -vy)
		_was_airborne = true
		return
	if _was_airborne and _air_time >= 0.25 and _fall_speed >= 4.5:
		_land(_fall_speed)
	_was_airborne = false
	_air_time = 0.0
	_fall_speed = 0.0


## Réception d'un saut : cuvette sous chaque roue (plus large et profonde si l'arrivée est
## rapide), la caisse marque aussi le sable si le choc est très fort, gerbe, secousse.
func _land(speed: float) -> void:
	var k := clampf((speed - 4.5) / 10.0, 0.0, 1.0)
	var depth := lerpf(0.08, 0.5, k)
	var radius := lerpf(0.8, 1.8, k)
	for i in 4:
		var w: VehicleWheel3D = car.wheels[i]
		if not w.is_in_contact():
			continue
		var s: int = car.wheel_surface[i]
		if not WL.is_soft(s):
			continue
		var p := w.get_contact_point()
		terrain.dent(p, radius, depth * (0.5 if s == WL.Surface.DIRT else 1.0))
		effects.burst(p, s, 0.5 + k)
	if k > 0.6:
		terrain.dent(car.global_position, radius * 1.6, depth * 0.5)
	camera.shake(0.3 + k * 0.7)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-300, 8)
	box.size = Vector2(600, 100)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	layer.add_child(box)
	_hud_speed = Label.new()
	_hud_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_speed.add_theme_font_size_override("font_size", 44)
	_hud_speed.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15))
	_hud_speed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hud_speed.add_theme_constant_override("outline_size", 6)
	box.add_child(_hud_speed)
	_hud_info = Label.new()
	_hud_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_info.add_theme_font_size_override("font_size", 16)
	_hud_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hud_info.add_theme_constant_override("outline_size", 4)
	box.add_child(_hud_info)
