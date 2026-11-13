## Point d'entrée de la balade : charge le monde précalculé, construit le décor, la voiture,
## la caméra drone, les commandes et l'affichage. Gère les effets de roues (traces,
## poussière) et la réception des sauts (le sable se creuse, gerbe, secousse).
## C (ou VOITURE) passe au modèle suivant du kit, pour comparer les réglages.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")
const WorldBuilder = preload("res://scripts/balade/world_builder.gd")
const Car = preload("res://scripts/balade/car.gd")
const CarModels = preload("res://scripts/game/car_models.gd")
const Settings = preload("res://scripts/balade/settings.gd")
## Numéro de version affiché (pour savoir quelle version tourne sur le téléphone : la
## version web peut rester en cache quelques minutes après une mise en ligne).
const VERSION := "0.14.2"

@export var start_model := "bolide"
## Conduire la voiture choisie au garage (sinon `start_model`, pour les tests).
@export var use_garage_car := true
## Voiture du garage conduite (uid), -1 : modèle du pack.
var drive_uid := -1
var spotting: Node3D
## Qualité : 1 = PC (tout), 0 = iPhone et web (réglée pour 60 images/s). -1 = automatique.
@export var force_quality := -1
var low_quality := false
var sun: DirectionalLight3D
## Réglages (graphismes, conduite) et leur écran.
var settings: RefCounted
var menu: CanvasLayer
## Valeurs de conduite d'origine de la voiture actuelle (pour « Réinitialiser »).
var car_base := {}
var water_sim_enabled := true
## Post-traitement « cinéma » (réglages Haut et Ultra) : rectangle collé à la caméra.
var post_level := 0
var _night_label := "NUIT"
var weather: Node
var _rain_mm: MultiMesh
var _rain_mat: ShaderMaterial
var _splash_mm: MultiMesh
var _splash_mat: ShaderMaterial
const RAIN_DROPS := 2200
const SPLASHES := 260
var _sun_timer := 0.0
## Résolution dynamique : la résolution 3D baisse un peu (jusqu'à 60 % du réglage) quand
## l'image prend plus de 18 ms, et remonte dès que ça redevient fluide.
var dynres_on := true
var dynres_base := 1.0
var _dyn_scale := 1.0
var _dyn_ms := 16.7
var _dyn_timer := 0.0
var _sea_materials: Array[ShaderMaterial] = []
var _wake_patch: MeshInstance3D
var water_sim: Node
var _plow_last: Array = []
var _plow_amount := 0.0
var _plow_point := Vector3.ZERO
var _plow_timer := 0.0
const Waves = preload("res://scripts/balade/waves.gd")

var data: RefCounted
var terrain: Node3D
var effects: Node3D
var ruts: Node3D
## Largeur d'un pneu (m) pour les ornières.
const TYRE_WIDTH := 0.28
const HALO = preload("res://shaders/halo.gdshader")
static var LIGHTS_MAT: ShaderMaterial = _make_mat("res://shaders/car_light.gdshader")
static var HALO_MAT: ShaderMaterial = _make_mat("res://shaders/halo.gdshader")


static func _make_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("use_vertex_color", true)
	return m
var decor: Node3D
var vegetation: Node3D
var town: Node3D
var lighting: Node
var sun_shadows: Node
var _shadow_hour := -100.0
var lamps: Node3D
var _car_lights: Array = []
var life: Node3D
var controls: CanvasLayer
var camera: Camera3D
var car: VehicleBody3D
var model_index := 0

# Réception de saut.
var _air_time := 0.0
var _fall_speed := 0.0
var _was_airborne := false

var hud: CanvasLayer
var audio: Node


func _ready() -> void:
	data = WorldData.load_baked()
	if data == null:
		return
	# La balade lit les doigts elle-même (boutons multi-doigts) : pas de souris émulée.
	Input.emulate_mouse_from_touch = false
	low_quality = force_quality == 0 or (force_quality < 0 and (OS.has_feature("web") or OS.has_feature("mobile")))
	sun = WorldBuilder.build_environment(self)
	_apply_quality(sun)
	lighting = load("res://scripts/balade/lighting.gd").new()
	lighting.name = "Lumiere"
	add_child(lighting)
	lighting.no_glow = low_quality
	for n in get_children():
		if n is WorldEnvironment:
			lighting.setup((n as WorldEnvironment).environment, sun, self)
	sun_shadows = load("res://scripts/balade/sun_shadows.gd").new()
	sun_shadows.name = "OmbresSoleil"
	add_child(sun_shadows)
	sun_shadows.build()
	terrain = load("res://scripts/balade/terrain.gd").new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.near_range = 100.0 if low_quality else 180.0
	terrain.cast_shadows = false
	terrain.build(data)
	terrain.material().set_shader_parameter("low_quality", low_quality)
	ruts = load("res://scripts/balade/ruts.gd").new()
	ruts.name = "Ornieres"
	add_child(ruts)
	ruts.mesh_step = 0.3
	ruts.build(terrain.material())
	_sea_materials = WorldBuilder.build_sea(self, data, terrain.height_texture())
	_build_wake_patch()
	WorldBuilder.build_far_ground(self)
	WorldBuilder.build_walls(self)
	town = load("res://scripts/balade/town.gd").new()
	town.name = "Ville"
	add_child(town)
	town.build(data)
	life = load("res://scripts/balade/life.gd").new()
	life.name = "Vie"
	add_child(life)
	life.build(data, town, null)
	lamps = load("res://scripts/balade/lamps.gd").new()
	lamps.name = "Reverberes"
	add_child(lamps)
	lamps.build(data, town)
	WorldBuilder.build_rocks(self, data)

	weather = load("res://scripts/balade/weather.gd").new()
	weather.name = "Meteo"
	add_child(weather)
	lighting.weather = weather
	_build_rain()
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
	vegetation = load("res://scripts/balade/vegetation.gd").new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(data)

	_build_hud()
	# Réglages : Moyen par défaut sur iPhone et le web, Haut sur PC.
	settings = Settings.new(2 if low_quality else 3)
	if force_quality < 0:
		settings.load_file()
	menu = load("res://scripts/balade/settings_menu.gd").new()
	menu.game = self
	menu.settings = settings
	add_child(menu)
	model_index = maxi(0, Car.MODELS.find(start_model))
	var game_state := get_node_or_null("/root/Game")
	if use_garage_car and game_state and not game_state.get_car(game_state.selected).is_empty():
		drive_uid = game_state.selected
	var y: float = data.height_at(WL.SPAWN_X, WL.SPAWN_Z) + 1.2
	# Départ au bord de la plage, vers le nord, le long du rivage : la caméra drone, côté
	# dunes, voit la voiture, la plage et la mer d'un seul coup d'œil.
	_spawn(Vector3(WL.SPAWN_X, y, WL.SPAWN_Z), PI)
	spotting = load("res://scripts/balade/spotting.gd").new()
	spotting.name = "Spots"
	add_child(spotting)
	spotting.build(data, car, camera)
	settings.apply_graphics(self)
	settings.apply_controls(controls)
	controls.set_drift_indicator(settings.mode == 0)
	# Vue principale : le drone (vue 2).
	camera.mode = 1
	if force_quality < 0:
		_start_warmup()


## Réglages selon l'appareil. iPhone et web : pleine résolution, pas de MSAA (FXAA à la place), ombres sur 90 m
## avec une carte plus petite, pas de halo, terrain sans seconde échelle de texture.
func _apply_quality(sun: DirectionalLight3D) -> void:
	var vp := get_viewport()
	if low_quality:
		vp.scaling_3d_scale = 1.0
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			# Web : ce rendu n'a pas de FXAA (il ne faisait rien). Le MSAA ×2 coûterait
			# beaucoup au banc d'essai ; à essayer sur un vrai iPhone avant de l'activer.
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		else:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 70.0
		# Filtre d'ombre le moins cher qui reste lisse (le filtre « dur » crénelle les bords).
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
		for n in get_children():
			if n is WorldEnvironment:
				# Halo gardé (version simplifiée sur le web) : il fait briller les lumières de nuit.
				(n as WorldEnvironment).environment.ssao_enabled = false
	else:
		vp.msaa_3d = Viewport.MSAA_2X


func _spawn(pos: Vector3, yaw: float) -> void:
	var game_state := get_node_or_null("/root/Game")
	var garage_car: Dictionary = game_state.get_car(drive_uid) if game_state and drive_uid >= 0 else {}
	if garage_car.is_empty():
		# Sans partie : modèle du pack, ou du kit Kenney si demandé (tests).
		car = Car.create(start_model if Car.KENNEY.has(start_model) else Car.MODELS[model_index], controls)
	else:
		car = Car.create(CarModels.kit_for(String(garage_car["model"])), controls)
		CarModels.repaint(car, CarModels.color_of(garage_car), CarModels.kit_for(String(garage_car["model"])))
	car.world_data = data
	settings.apply_mode(car)
	car_base.clear()
	for c in Settings.CAR:
		car_base[c[0]] = Settings.car_value(car, c[0])
	settings.apply_car(car)
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	camera.target = car
	if life:
		life.target = car
	if spotting:
		spotting.target = car
	_add_car_lights()
	settings.apply_halos(car)
	_apply_varnish()
	camera.snap()
	if decor.data == null:
		decor.low_quality = low_quality
		decor.effects = effects
		decor.build(data, car)
	else:
		decor.target = car


func _process(delta: float) -> void:
	if car == null:
		return
	if _warm > 0:
		_warm -= 1
		if _warm == 0:
			_end_warmup()
		return
	if menu.visible == controls.visible:
		controls.set_enabled(not menu.visible)
	# Bouton Drift (façon ESP) : bascule entre Drift et Grip, la voiture est refaite sur place.
	if controls.mode_requested:
		settings.mode = 1 - settings.mode
		settings.save_file()
		controls.set_drift_indicator(settings.mode == 0)
		audio.shot("click")
		rebuild_car()
		return
	if controls.garage_requested:
		_go_garage()
		return
	if controls.settings_requested:
		audio.shot("click")
		menu.open()
		controls.set_enabled(false)
	if controls.camera_requested:
		camera.next_mode()
	if controls.next_car_requested:
		# Voiture suivante du garage (ou du pack, sans partie).
		var gs := get_node_or_null("/root/Game")
		if drive_uid >= 0 and gs and gs.cars.size() > 0:
			var i := 0
			for k in gs.cars.size():
				if int(gs.cars[k]["uid"]) == drive_uid:
					i = k
			drive_uid = int(gs.cars[(i + 1) % gs.cars.size()]["uid"])
			gs.select(drive_uid)
		else:
			model_index = (model_index + 1) % Car.MODELS.size()
		var pos := car.global_position + Vector3.UP * 0.5
		var yaw := car.rotation.y
		car.queue_free()
		_spawn(pos, yaw)
		return
	_follow_wake_patch(delta)
	_update_rain()
	_dynamic_resolution(delta)
	_update_car_shadow()
	_update_sun_shadows(false)
	if controls.night_requested:
		lighting.set_night(not lighting.is_night())
	# Le bouton indique où il emmène : vers la nuit le jour, vers le jour la nuit.
	var nlabel := "JOUR" if lighting.is_night() else "NUIT"
	if nlabel != _night_label:
		_night_label = nlabel
		controls.set_label("ci_night", nlabel)
	# Poussière à contre-jour : suit le soleil (ou la lune).
	_sun_timer -= delta
	if _sun_timer <= 0.0:
		_sun_timer = 0.25
		effects.set_sun(lighting.light_direction(), lighting.sun.light_color if lighting.sun.visible else lighting.moon.light_color)

	for m in _sea_materials:
		m.set_shader_parameter("now", Waves.now())
	_wheel_effects(delta)
	_splash(delta)
	ruts.follow(car.global_position, car.linear_velocity / 15.0)


## Ornières : creusées au rythme fixe de la physique (60 fois par seconde), pour un tracé
## continu même quand l'affichage ralentit.
func _dig_ruts() -> void:
	var drift := clampf((absf(car.slip_angle) - 8.0) / 25.0, 0.0, 1.0)
	for i in 4:
		var w: VehicleWheel3D = car.wheels[i]
		var s: int = car.wheel_surface[i]
		if not w.is_in_contact() or not WL.is_soft(s):
			ruts.lift(i)
			car.wheel_sink[i] = 0.0
			continue
		var p := w.get_contact_point()
		ruts.dig(i, p, s, TYRE_WIDTH, 1.0, clampf(car.wheel_slip[i] + drift * 0.6, 0.0, 1.0))
		# La roue roule dans le creux qu'elle vient de faire.
		car.wheel_sink[i] = ruts.depth_at(p)


## Gerbes d'eau : deux nappes de gouttes, une de chaque côté de l'avant, qui partent
## vers l'extérieur et retombent dans l'eau. Plus on va vite, plus il y en a.
func _splash(delta: float) -> void:
	if not car.in_water or car.speed_kmh < 6.0:
		return
	var rate: float = clampf(car.speed_kmh / 40.0, 0.2, 1.2) * 40.0 * delta
	var count := int(rate) + (1 if randf() < fmod(rate, 1.0) else 0)
	var fwd: Vector3 = car.global_basis.z
	var side: Vector3 = car.global_basis.x
	var h: Vector3 = car.body_half
	var push := clampf(car.speed_kmh / 40.0, 0.4, 1.2)
	for k in count:
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var p: Vector3 = car.global_position + fwd * h.z * 0.7 + side * sgn * h.x
		var surf: float = Waves.surface(p.x, p.z, 10.0)
		p.y = surf + 0.05
		var v: Vector3 = side * sgn * randf_range(1.5, 2.5) * push + Vector3.UP * randf_range(1.8, 2.8) * push + car.linear_velocity * 0.2
		effects.dust(p, v, Color(0.93, 0.98, 1.0, 0.8), randf_range(0.3, 0.5), 1.0, effects.Kind.WATER, surf)


func _wheel_effects(delta: float) -> void:
	var speed: float = car.speed_kmh
	var drift := clampf((absf(car.slip_angle) - 8.0) / 25.0, 0.0, 1.0)
	var heading: Vector3 = car.global_basis.z
	for i in 4:
		var w: VehicleWheel3D = car.wheels[i]
		if not w.is_in_contact():
			effects.lift(i)
			continue
		var p := w.get_contact_point()
		var n := w.get_contact_normal()
		var s: int = car.wheel_surface[i]
		var slip: float = car.wheel_slip[i]
		var soft := WL.is_soft(s)
		# Sable et terre : la roue creuse une vraie ornière. Bitume : trace de gomme si ça glisse.
		if s == WL.Surface.ASPHALT and speed > 2.0 and (slip > 0.35 or drift > 0.2):
			effects.track(i, p, n, heading, s, w.wheel_radius * 1.2)
		else:
			effects.lift(i)
		# Poussière : sur le bitume seulement quand ça glisse ; panache en dérapage.
		var amount := 0.0
		if s == WL.Surface.ASPHALT:
			amount = clampf((slip - 0.5) * 1.5 + drift * 0.6, 0.0, 1.0) * clampf(speed / 30.0, 0.0, 1.0)
		else:
			amount = clampf(speed / 70.0, 0.0, 1.0) * (1.0 if i >= 2 else 0.5) + clampf(slip - 0.3, 0.0, 1.0)
			amount += drift * 1.5 * (1.0 if i >= 2 else 0.3)
		if s == WL.Surface.WET_SAND:
			amount *= 0.4
		# Sol mouillé : presque plus de poussière, mais des gerbes d'eau derrière les roues.
		var wet: float = weather.wet
		amount *= 1.0 - 0.85 * wet
		if wet > 0.25 and speed > 15.0 and s != WL.Surface.WATER:
			var spray := wet * clampf(speed / 80.0, 0.0, 1.0) * (1.0 if i >= 2 else 0.5) * 30.0 * delta
			var sn := int(spray) + (1 if randf() < fmod(spray, 1.0) else 0)
			for k2 in sn:
				var sv := car.linear_velocity * 0.25 + Vector3.UP * randf_range(1.0, 2.5) + car.global_basis.x * randf_range(-1.2, 1.2)
				effects.dust(p + Vector3.UP * 0.15, sv, Color(0.85, 0.88, 0.92, 0.55), randf_range(0.25, 0.45), randf_range(0.5, 0.9), effects.Kind.WATER, p.y)
		# Nuage selon la vitesse : peu de bouffées, mais grosses, d'autant plus grosses, nombreuses
		# et durables que la voiture va vite ; en dérapage, des panaches plus amples.
		var fast := clampf(speed / 110.0, 0.0, 1.0)
		var rate := amount * lerpf(3.0, 8.0, fast) * delta
		var count := int(rate) + (1 if randf() < fmod(rate, 1.0) else 0)
		var c: Color = effects.DUST_COLORS[s]
		for k in count:
			# Soulevée par la roue, elle garde un peu de l'élan de la voiture puis traîne derrière.
			var v := car.linear_velocity * randf_range(0.12, 0.25) + Vector3.UP * randf_range(0.4, 1.2) + car.global_basis.x * randf_range(-1.5, 1.5) * (0.6 + drift)
			# Petite à basse vitesse, ample à grande vitesse.
			var size := randf_range(1.4, 2.2) * lerpf(0.3, 1.8, pow(fast, 0.8)) * (1.2 if s == WL.Surface.SAND else 1.0) * (1.0 + drift * 0.6)
			effects.dust(p + Vector3.UP * 0.25, v, Color(c.r, c.g, c.b, c.a * randf_range(0.7, 1.0)), size, randf_range(1.8, 2.6) * lerpf(1.0, 1.5, fast))


func _physics_process(delta: float) -> void:
	if car == null:
		return
	_dig_ruts()
	_body_contact(delta)
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
	audio.land(k)
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


## Les dunes se déforment sous la caisse : quand le bas de caisse ou un pare-chocs touche
## le sable (dos de dune, nez planté dans une pente), il y laisse un sillon large, repousse
## le sable en bourrelets et en gerbe, et freine la voiture. Si ça frotte longtemps, la
## collision du sol est creusée aussi (la voiture s'enfonce et finit par passer).
const PLOW_POINTS := [
	Vector3(-0.75, 0.0, -0.85), Vector3(0.0, 0.0, -0.85), Vector3(0.75, 0.0, -0.85),
	Vector3(-0.75, 0.0, -0.3), Vector3(0.75, 0.0, -0.3), Vector3(-0.75, 0.0, 0.3), Vector3(0.75, 0.0, 0.3),
	Vector3(-0.75, 0.0, 0.85), Vector3(0.0, 0.0, 0.85), Vector3(0.75, 0.0, 0.85),
	# pare-chocs, un peu plus haut
	Vector3(-0.6, 0.35, 1.0), Vector3(0.0, 0.35, 1.0), Vector3(0.6, 0.35, 1.0),
	Vector3(-0.6, 0.35, -1.0), Vector3(0.6, 0.35, -1.0)]


func _body_contact(delta: float) -> void:
	if _plow_last.size() != PLOW_POINTS.size():
		_plow_last.resize(PLOW_POINTS.size())
	var xf := car.global_transform
	var h: Vector3 = car.body_half
	var speed: float = car.linear_velocity.length()
	var touching := 0
	var deepest := 0.0
	for i in PLOW_POINTS.size():
		var lp: Vector3 = PLOW_POINTS[i]
		var q: Vector3 = xf * Vector3(lp.x * h.x, car.body_bottom + lp.y, lp.z * h.z)
		var g: float = data.height_at(q.x, q.z)
		var pen := g - q.y + 0.06
		var s := WL.surface_at(q.x, q.z, g)
		if pen <= 0.0 or not WL.is_soft(s):
			_plow_last[i] = null
			continue
		touching += 1
		var depth := clampf(pen * 0.8 + 0.03 + speed * 0.004, 0.03, 0.28)
		var a: Variant = _plow_last[i]
		var from: Vector3 = q if a == null or (a as Vector3).distance_to(q) > 3.0 else a
		ruts.plow(from, q, 0.42, depth * (0.6 if s == WL.Surface.DIRT else 1.0))
		_plow_last[i] = q
		if pen > deepest:
			deepest = pen
			_plow_point = q
	if touching == 0:
		_plow_amount = maxf(0.0, _plow_amount - delta)
		return
	# Le sable freine la caisse qui frotte (plus fort à grande vitesse).
	var k := float(touching) / PLOW_POINTS.size()
	car.apply_central_force(-car.linear_velocity * car.mass * 0.9 * k)
	_plow_amount += delta * (0.5 + deepest * 4.0) * (0.3 + speed * 0.1)
	_plow_timer -= delta
	if _plow_amount > 0.35 and _plow_timer <= 0.0:
		_plow_timer = 0.4
		_plow_amount = 0.0
		var s2 := WL.surface_at(_plow_point.x, _plow_point.z, _plow_point.y)
		terrain.dent(_plow_point, 1.1, clampf(deepest + 0.05, 0.05, 0.2) * (0.5 if s2 == WL.Surface.DIRT else 1.0))


## Grille fine de la mer (128 m, un sommet tous les 1,6 m) qui suit la voiture : houle
## en facettes et vagues simulées autour de la voiture. La mer plate ne se dessine pas
## dessous.
const NEAR_SEA := 128.0
const NEAR_SEA_STEP := 1.6


func _build_wake_patch() -> void:
	water_sim = load("res://scripts/balade/water_sim.gd").new()
	water_sim.name = "SimulationEau"
	add_child(water_sim)
	water_sim.build(terrain.height_texture(), data)
	var pm := PlaneMesh.new()
	pm.size = Vector2(NEAR_SEA, NEAR_SEA)
	var n := int(NEAR_SEA / NEAR_SEA_STEP)
	pm.subdivide_width = n - 1
	pm.subdivide_depth = n - 1
	_wake_patch = MeshInstance3D.new()
	_wake_patch.name = "MerProche"
	_wake_patch.mesh = pm
	_wake_patch.material_override = _sea_materials[0]
	_wake_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake_patch.extra_cull_margin = 2.0
	_wake_patch.visible = false
	add_child(_wake_patch)
	for m in _sea_materials:
		m.set_shader_parameter("sim_size", water_sim.SIZE)
		m.set_shader_parameter("sim_range", water_sim.RANGE)


## Près de la mer : la grille fine se cale sur la voiture (sur une grille fixe, sinon les
## facettes ondulent en la suivant) et la simulation avance d'un pas (caisse et roues qui
## poussent l'eau). Loin de la mer : rien à faire.
func _follow_wake_patch(delta: float) -> void:
	var p := car.global_position
	var near: bool = p.x > WL.BEACH_END - 90.0 or data.height_at(p.x, p.z) < WL.SEA_LEVEL + 3.0
	var near_rect := Vector4(0, 0, -1, -1)
	var sim_rect := Vector4(0, 0, -1, -1)
	if near:
		var g := NEAR_SEA_STEP * 4.0
		var c := Vector3(snappedf(p.x, g), WL.SEA_LEVEL, snappedf(p.z, g))
		_wake_patch.position = c
		near_rect = Vector4(c.x - NEAR_SEA / 2.0, c.z - NEAR_SEA / 2.0, NEAR_SEA, NEAR_SEA)
		var in_reach: bool = water_sim_enabled and data.height_at(p.x, p.z) < WL.SEA_LEVEL + 1.0
		if in_reach:
			var depth: float = WL.SEA_LEVEL - data.height_at(p.x, p.z)
			var surf := Waves.surface(p.x, p.z, depth)
			var dip := clampf(surf - (p.y + car.body_bottom), 0.0, 1.2)
			var stirs: Array[Vector4] = []
			for w in car.wheels:
				var wv := w as VehicleWheel3D
				if wv.is_in_contact():
					var cp := wv.get_contact_point()
					var wd := clampf(Waves.surface(cp.x, cp.z, WL.SEA_LEVEL - cp.y) - cp.y, 0.0, 0.8)
					stirs.append(Vector4(cp.x, cp.z, 0.6, wd))
				else:
					stirs.append(Vector4.ZERO)
			var h: Vector3 = car.body_half
			water_sim.step(p, p, car.global_basis.z, Vector2(h.x, h.z), dip, stirs, delta)
			sim_rect = water_sim.rect()
		else:
			water_sim.active = false
	else:
		water_sim.active = false
	_wake_patch.visible = near
	# La mer plate s'arrête un peu avant le bord de la grille fine (pas de fente entre les deux).
	var hole := near_rect
	if near:
		hole = Vector4(near_rect.x + 0.5, near_rect.y + 0.5, near_rect.z - 1.0, near_rect.w - 1.0)
	_sea_materials[0].set_shader_parameter("near_rect", near_rect)
	_sea_materials[1].set_shader_parameter("hole_rect", hole)
	for m in _sea_materials:
		m.set_shader_parameter("sim_rect", sim_rect)
		m.set_shader_parameter("sim_tex", water_sim.texture())


## Feux de la voiture du joueur (blancs devant, rouges derrière, avec halo). Le faisceau des
## phares au sol est calculé par le terrain et l'herbe (car_shadow.gdshaderinc), sans vraie
## lumière : une vraie lumière redessine chaque objet qu'elle touche (trop cher sur iPhone).
func _add_car_lights() -> void:
	_car_lights.clear()
	var shape: CollisionShape3D = null
	for c in car.get_children():
		if c is CollisionShape3D:
			shape = c
			break
	var c0: Vector3 = shape.position if shape else Vector3(0, 0.9, 0)
	var h: Vector3 = car.body_half
	var y: float = car.body_bottom + 0.25
	# Feux sur la caisse : ils penchent avec elle.
	add_lamps_to(car.body_node if car.body_node else car, Vector3(c0.x, y, c0.z), h)


## Feux d'une voiture (joueur ou circulation) : deux blancs à l'avant, deux rouges à
## l'arrière, et leurs halos. Deux objets en tout (un maillage pour les quatre feux, un
## MultiMesh pour les quatre halos) : deux appels de dessin par voiture.
static func add_lamps_to(node: Node3D, center: Vector3, half: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spots: Array = []
	for side in [-1.0, 1.0]:
		for f in [1.0, -1.0]:
			var p: Vector3 = center + Vector3(side * half.x * 0.62, 0.0, f * (half.z + 0.02))
			var col := Color(1.0, 0.95, 0.85) if f > 0.0 else Color(1.0, 0.12, 0.08)
			_light_box(st, p, Vector3(0.32, 0.14, 0.06), col)
			spots.append([p + Vector3(0, 0, f * 0.15), col, 1.6 if f > 0.0 else 1.1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = LIGHTS_MAT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(spots[i][2])), spots[i][0]))
		mm.set_instance_color(i, spots[i][1])
	mm.custom_aabb = AABB(center - half * 2.0 - Vector3.ONE * 2.0, half * 4.0 + Vector3.ONE * 4.0)
	var hmi := MultiMeshInstance3D.new()
	hmi.multimesh = mm
	hmi.material_override = HALO_MAT
	hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(hmi)


static func _light_box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var b := BoxMesh.new()
	b.size = size
	var arr := b.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(col)
		st.add_vertex(verts[i] + c)


## Matériaux qui reçoivent les ombres (terrain, pièce des ornières, herbe).
var _shadow_mats: Array[ShaderMaterial] = []
var _car_shape: CollisionShape3D


func _setup_shadows() -> void:
	var tex: Texture2D = sun_shadows.texture()
	_shadow_mats = [terrain.material()]
	for m in ruts._materials:
		if not _shadow_mats.has(m):
			_shadow_mats.append(m)
	if decor.grass_material:
		_shadow_mats.append(decor.grass_material)
	var night_tex: Texture2D = load("res://assets/balade/lights.png")
	for m in _shadow_mats:
		m.set_shader_parameter("static_shadow_tex", tex)
		m.set_shader_parameter("night_light_tex", night_tex)
	lighting.shadow_materials = _shadow_mats
	sun_shadows.materials = _shadow_mats
	lighting.refresh()


## Ombres du décor : refaites en continu pour la position de l'astre ; tout d'un coup
## quand l'heure saute (réglages, démarrage).
func _update_sun_shadows(force_full: bool) -> void:
	var h: float = lighting.hour
	var gap := absf(fposmod(h - _shadow_hour + 12.0, 24.0) - 12.0)
	var fast: bool = lighting.is_scrubbing()
	var full := force_full or (gap > 0.25 and not fast)
	_shadow_hour = h
	# Fenêtre centrée un peu devant la voiture (la caméra regarde devant).
	var v := car.linear_velocity * 1.5
	var lead := Vector3(v.x, 0.0, v.z).limit_length(50.0)
	sun_shadows.update(lighting.light_direction(), car.global_position + lead, full, fast)


## Ombre de la voiture : sa position, son orientation et deux boîtes (bas de caisse,
## habitacle) dans son repère, données aux matériaux qui la reçoivent.
func _update_car_shadow() -> void:
	if _shadow_mats.is_empty():
		_setup_shadows()
	if _car_shape == null or not is_instance_valid(_car_shape) or _car_shape.get_parent() != car:
		_car_shape = null
		for c in car.get_children():
			if c is CollisionShape3D:
				_car_shape = c
				break
	var xf := car.global_transform
	var inv := xf.affine_inverse()
	var sun_l: Vector3 = (xf.basis.inverse() * lighting.light_direction()).normalized()
	var c: Vector3 = _car_shape.position if _car_shape else Vector3(0, 0.9, 0)
	var h: Vector3 = car.body_half
	var bottom: float = car.body_bottom
	var top := c.y + h.y
	var b1_min := Vector3(c.x - h.x, 0.15, c.z - h.z)
	var b1_max := Vector3(c.x + h.x, bottom + (top - bottom) * 0.5, c.z + h.z)
	var b2_min := Vector3(c.x - h.x * 0.86, bottom, c.z - h.z * 0.55)
	var b2_max := Vector3(c.x + h.x * 0.86, top, c.z + h.z * 0.3)
	var fwd: Vector3 = xf.basis.z.normalized()
	var head := xf * Vector3(c.x, bottom + 0.35, c.z + h.z + 0.2)
	RenderingServer.global_shader_parameter_set("head_pos", head)
	# Le décor s'efface entre la caméra et la voiture (shaders/see_through.gdshaderinc).
	RenderingServer.global_shader_parameter_set("see_pos", xf.origin + Vector3.UP * 0.8)
	RenderingServer.global_shader_parameter_set("head_dir", (fwd - Vector3.UP * 0.12).normalized())
	# Deux phares, au même écart que les feux dessinés (add_lamps_to).
	RenderingServer.global_shader_parameter_set("head_side", xf.basis.x.normalized() * h.x * 0.62)
	for m in _shadow_mats:
		m.set_shader_parameter("car_inv", Projection(inv))
		m.set_shader_parameter("car_sun", sun_l)
		m.set_shader_parameter("car_pos", xf.origin)
		m.set_shader_parameter("box1_min", b1_min)
		m.set_shader_parameter("box1_max", b1_max)
		m.set_shader_parameter("box2_min", b2_min)
		m.set_shader_parameter("box2_max", b2_max)


## Refait la voiture actuelle sur place (changement de mode de conduite).
## Retour au garage (la partie est sauvegardée ; les boutons du garage se touchent au doigt).
func _go_garage() -> void:
	var gs := get_node_or_null("/root/Game")
	if gs:
		gs.save_game(gs.now())
	Input.emulate_mouse_from_touch = true
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func rebuild_car() -> void:
	var pos := car.global_position + Vector3.UP * 0.3
	var yaw := car.rotation.y
	car.queue_free()
	_spawn(pos, yaw)
	settings.apply_halos(car)


## Vernis de carrosserie (couche brillante) dans les réglages Moyen à Ultra.
func set_varnish(on: bool) -> void:
	post_level = 1 if on else 0
	_apply_varnish()


func _apply_varnish() -> void:
	if car == null:
		return
	for m in car.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for si in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(si) as BaseMaterial3D
			if mat == null:
				continue
			mat.clearcoat_enabled = post_level > 0
			mat.clearcoat = 0.8
			mat.clearcoat_roughness = 0.12
			mat.roughness = 0.32 if post_level > 0 else 0.45


func _dynamic_resolution(delta: float) -> void:
	var vp := get_viewport()
	# Outils de mesure et de capture (qualité forcée) : résolution fixe, pour comparer.
	if not dynres_on or force_quality >= 0:
		if not is_equal_approx(vp.scaling_3d_scale, dynres_base):
			vp.scaling_3d_scale = dynres_base
		_dyn_scale = 1.0
		return
	_dyn_ms = lerpf(_dyn_ms, delta * 1000.0, 0.08)
	_dyn_timer -= delta
	if _dyn_timer > 0.0:
		return
	_dyn_timer = 0.5
	if _dyn_ms > 18.5:
		_dyn_scale = maxf(0.6, _dyn_scale - 0.05)
	elif _dyn_ms < 15.0:
		_dyn_scale = minf(1.0, _dyn_scale + 0.05)
	var want := dynres_base * _dyn_scale
	if absf(vp.scaling_3d_scale - want) > 0.001:
		vp.scaling_3d_scale = want


## Préchauffage : sur la version web, un objet qui apparaît pour la première fois oblige le
## navigateur à compiler son shader, ce qui fige le jeu un instant (immeubles, eau,
## piétons…). Au démarrage, derrière un écran « Chargement », on affiche une fois tout le
## décor (distances d'affichage levées, caméra très haut au-dessus de la carte) : tout est
## compilé avant de rouler.
var _warm := 0
var _warm_saved: Array = []
var _loading: CanvasLayer


func _start_warmup() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.065, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var lbl := Label.new()
	lbl.text = "CHARGEMENT"
	lbl.add_theme_font_override("font", load("res://assets/fonts/RussoOne-Regular.ttf"))
	var u := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y)
	lbl.add_theme_font_size_override("font_size", int(u * 0.06))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.52, 0.12))
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.add_child(lbl)
	add_child(_loading)
	_warm_saved.clear()
	for n in find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0 or gi.visibility_range_begin > 0.0:
			_warm_saved.append([gi, gi.visibility_range_begin, gi.visibility_range_end])
			gi.visibility_range_begin = 0.0
			gi.visibility_range_end = 0.0
	_wake_patch.visible = true
	_update_sun_shadows(true)
	# Pluie et éclaboussures : quelques-unes, pour que leurs shaders soient prêts.
	_rain_mm.visible_instance_count = 16
	_splash_mm.visible_instance_count = 16
	for vp in water_sim._vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.far = 4000.0
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), Vector3(0.0, 950.0, 0.0))
	_warm = 4


func _end_warmup() -> void:
	for e in _warm_saved:
		var gi: GeometryInstance3D = e[0]
		if is_instance_valid(gi):
			gi.visibility_range_begin = e[1]
			gi.visibility_range_end = e[2]
	_warm_saved.clear()
	_wake_patch.visible = false
	camera.far = 3000.0
	camera.set_process(true)
	camera.set_physics_process(true)
	camera.snap()
	# L'écran de chargement s'efface en douceur.
	var tw := create_tween()
	for c in _loading.get_children():
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_loading.queue_free)


## Pluie autour de la voiture : gouttes (rain.gdshader) et éclaboussures au sol
## (splash.gdshader), toutes animées par la carte graphique ; le nombre affiché suit la
## force de la pluie.
func _build_rain() -> void:
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://shaders/rain.gdshader")
	var q := QuadMesh.new()
	_rain_mm = MultiMesh.new()
	_rain_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rain_mm.mesh = q
	_rain_mm.instance_count = RAIN_DROPS
	_rain_mm.visible_instance_count = 0
	_rain_mm.custom_aabb = AABB(Vector3(-3000, -200, -3000), Vector3(6000, 600, 6000))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Pluie"
	mi.multimesh = _rain_mm
	mi.material_override = _rain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = load("res://shaders/splash.gdshader")
	_splash_mat.set_shader_parameter("height_tex", terrain.height_texture())
	_splash_mat.set_shader_parameter("sea_level", WL.SEA_LEVEL)
	_splash_mm = MultiMesh.new()
	_splash_mm.transform_format = MultiMesh.TRANSFORM_3D
	_splash_mm.mesh = q
	_splash_mm.instance_count = SPLASHES
	_splash_mm.visible_instance_count = 0
	_splash_mm.custom_aabb = _rain_mm.custom_aabb
	var si := MultiMeshInstance3D.new()
	si.name = "Eclaboussures"
	si.multimesh = _splash_mm
	si.material_override = _splash_mat
	si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(si)


func _update_rain() -> void:
	var r: float = weather.rain
	var n := int(RAIN_DROPS * clampf(r, 0.0, 1.0))
	if _rain_mm.visible_instance_count != n:
		_rain_mm.visible_instance_count = n
	var m := int(SPLASHES * clampf(r * 1.2, 0.0, 1.0))
	if _splash_mm.visible_instance_count != m:
		_splash_mm.visible_instance_count = m
	if n > 0:
		var c := car.global_position.lerp(camera.global_position, 0.35)
		_rain_mat.set_shader_parameter("center", c + Vector3(0, 6, 0))
		_rain_mat.set_shader_parameter("strength", clampf(r * 1.5, 0.3, 1.0))
		_splash_mat.set_shader_parameter("center", car.global_position)
	car.wetness = weather.wet


func car_display_name() -> String:
	return Car.DISPLAY_NAMES.get(car.model_name, car.model_name)


func _build_hud() -> void:
	audio = load("res://scripts/balade/audio.gd").new()
	audio.name = "Sons"
	audio.game = self
	add_child(audio)
	weather.lightning.connect(audio.thunder)
	hud = load("res://scripts/balade/hud.gd").new()
	hud.game = self
	add_child(hud)
