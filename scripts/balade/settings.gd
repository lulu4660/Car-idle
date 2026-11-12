## Réglages de la balade : graphismes (préréglages de Très bas à Ultra, chaque valeur
## modifiable) et conduite (paramètres de la voiture, modifiables en roulant).
## Enregistrés dans user://settings.cfg. Données et application ; l'écran est settings_menu.gd.
extends RefCounted

const PATH := "user://settings.cfg"
const PRESETS: Array[String] = ["Très bas", "Bas", "Moyen", "Haut", "Ultra"]
const HALO = preload("res://shaders/halo.gdshader")

## Graphismes : clé, nom affiché, min, max, pas (0 = case à cocher), valeur pour chaque préréglage.
## Le levier le plus fort sur iPhone est la résolution 3D (moitié moins de pixels à 0,7) ;
## viennent ensuite les distances d'affichage (appels de dessin) et l'herbe.
const GRAPHICS := [
	["scale", "Résolution 3D", 0.5, 1.0, 0.05, [0.6, 0.8, 1.0, 1.0, 1.0]],
	["msaa", "Anticrénelage (MSAA ×2, ×4)", 0.0, 2.0, 1.0, [0.0, 0.0, 0.0, 1.0, 2.0]],
	["range", "Distance d'affichage", 0.4, 1.6, 0.05, [0.5, 0.7, 1.0, 1.0, 1.4]],
	["terrain", "Relief détaillé jusqu'à (m)", 60.0, 260.0, 10.0, [60.0, 80.0, 100.0, 180.0, 240.0]],
	["grass", "Herbe", 0.0, 1.0, 0.05, [0.2, 0.5, 0.8, 1.0, 1.0]],
	["life", "Circulation et passants", 0.0, 1.0, 0.05, [0.3, 0.6, 1.0, 1.0, 1.0]],
	["shadows", "Ombres temps réel (m, 0 = précalculées seules)", 0.0, 150.0, 10.0, [0.0, 0.0, 0.0, 0.0, 80.0]],
	["water", "Vagues simulées autour de la voiture", 0.0, 1.0, 0.0, [0.0, 1.0, 1.0, 1.0, 1.0]],
	["halos", "Halos des lumières", 0.0, 1.0, 0.0, [0.0, 1.0, 1.0, 1.0, 1.0]],
	["glow", "Bloom plein écran (coûteux)", 0.0, 1.0, 0.0, [0.0, 0.0, 0.0, 1.0, 1.0]],
	["ssao", "Occlusion ambiante (PC)", 0.0, 1.0, 0.0, [0.0, 0.0, 0.0, 0.0, 1.0]],
	# Ambiance (hors préréglages : null) : 0 = aucun, 1 = brume légère d'origine, 8 = purée de pois.
	["fog", "Brouillard", 0.0, 8.0, 0.1, null],
]

## Conduite : clé (propriété de car.gd, ou mass / susp_* pour la caisse et les roues),
## nom affiché, min, max, pas.
const CAR := [
	["engine_force_total", "Puissance moteur", 4000.0, 25000.0, 250.0],
	["top_speed_kmh", "Vitesse max (km/h)", 80.0, 250.0, 5.0],
	["brake_force", "Freins", 10.0, 100.0, 1.0],
	["handbrake_force", "Frein à main", 2.0, 40.0, 0.5],
	["max_steer_deg", "Braquage (°)", 15.0, 45.0, 0.5],
	["min_steer_deg", "Braquage à fond (°)", 3.0, 20.0, 0.5],
	["tyre_grip", "Adhérence des pneus", 1.0, 5.0, 0.05],
	["drift", "Dérapage (arrière qui décroche)", 0.0, 1.0, 0.01],
	["counter_steer", "Contre-braquage auto", 0.0, 1.0, 0.01],
	["max_drift_deg", "Angle de dérive max (°)", 20.0, 80.0, 1.0],
	["drift_yaw_assist", "Aide à la rotation", 0.0, 3.0, 0.05],
	["lateral_assist", "Retenue latérale", 0.0, 2.0, 0.01],
	["slide_keep", "Élan gardé en travers", 0.0, 3.0, 0.05],
	["downforce", "Appui", 0.0, 6.0, 0.1],
	["upright_assist", "Anti-tonneau", 0.0, 6.0, 0.1],
	["drive", "Transmission (4x4 / Propulsion / Traction)", 0.0, 2.0, 1.0],
	["mass", "Masse (kg)", 800.0, 2500.0, 25.0],
	["susp_stiffness", "Raideur des suspensions", 15.0, 90.0, 1.0],
	["susp_damping", "Amortissement", 0.3, 2.5, 0.05],
	["susp_travel", "Débattement (m)", 0.1, 0.5, 0.01],
]

var preset := 2
var graphics := {}
## Valeurs de conduite changées par le joueur (les autres restent celles du modèle).
var car_tuning := {}


func _init(default_preset: int) -> void:
	set_preset(default_preset)


func set_preset(i: int) -> void:
	preset = clampi(i, 0, PRESETS.size() - 1)
	for g in GRAPHICS:
		if g[5] != null:
			graphics[g[0]] = float(g[5][preset])
		elif not graphics.has(g[0]):
			graphics[g[0]] = 1.0


## Le préréglage dont toutes les valeurs correspondent, ou -1 (réglage personnalisé).
func matching_preset() -> int:
	for i in PRESETS.size():
		var same := true
		for g in GRAPHICS:
			if g[5] != null and not is_equal_approx(float(graphics[g[0]]), float(g[5][i])):
				same = false
		if same:
			return i
	return -1


func load_file() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	set_preset(int(cf.get_value("graphismes", "preset", preset)))
	for g in GRAPHICS:
		graphics[g[0]] = float(cf.get_value("graphismes", g[0], graphics[g[0]]))
	for c in CAR:
		if cf.has_section_key("conduite", c[0]):
			car_tuning[c[0]] = float(cf.get_value("conduite", c[0]))


func save_file() -> void:
	var cf := ConfigFile.new()
	cf.set_value("graphismes", "preset", preset)
	for k in graphics:
		cf.set_value("graphismes", k, graphics[k])
	for k in car_tuning:
		cf.set_value("conduite", k, car_tuning[k])
	cf.save(PATH)


# ------------------------------------------------------------------ graphismes

## Applique les graphismes à la balade, en direct.
func apply_graphics(game: Node) -> void:
	var g := graphics
	var vp: Viewport = game.get_viewport()
	vp.scaling_3d_scale = float(g["scale"])
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(g["msaa"])]
	var sun: DirectionalLight3D = game.sun
	var sh := float(g["shadows"])
	sun.shadow_enabled = sh > 0.0
	if sh > 0.0:
		sun.directional_shadow_max_distance = sh
	game.lighting.no_glow = g["glow"] < 0.5
	game.lighting.fog_amount = float(g["fog"])
	game.lighting.refresh()
	var is_forward: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	game.lighting.env.ssao_enabled = g["ssao"] > 0.5 and is_forward
	game.water_sim_enabled = g["water"] > 0.5
	# Relief : seuil entre la grille fine (2 m) et la grossière (4 m).
	var near := float(g["terrain"])
	for c in game.terrain.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.visibility_range_end > 0.0:
				mi.visibility_range_end = near
			elif mi.visibility_range_begin > 0.0:
				mi.visibility_range_begin = near
	# Distances d'affichage du décor (ville, végétation, réverbères, vie, herbe).
	for root in [game.town, game.vegetation, game.lamps, game.life, game.decor]:
		_scale_ranges(root, float(g["range"]))
	game.decor.set_grass_density(float(g["grass"]))
	game.life.set_density(float(g["life"]))
	apply_halos(game)


func apply_halos(game: Node) -> void:
	var on: bool = float(graphics["halos"]) > 0.5
	_set_halos(game, on)


static func _set_halos(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			var m := (c as GeometryInstance3D).material_override
			if m is ShaderMaterial and (m as ShaderMaterial).shader == HALO:
				(c as Node3D).visible = on
		if c.get_child_count() > 0:
			_set_halos(c, on)


static func _scale_ranges(n: Node, f: float) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			var gi := c as GeometryInstance3D
			if gi.visibility_range_end > 0.0:
				if not gi.has_meta("base_range"):
					gi.set_meta("base_range", gi.visibility_range_end)
				gi.visibility_range_end = float(gi.get_meta("base_range")) * f
		if c.get_child_count() > 0:
			_scale_ranges(c, f)


# ------------------------------------------------------------------ conduite

static func car_value(car: VehicleBody3D, key: String) -> float:
	match key:
		"mass":
			return car.mass
		"susp_stiffness":
			return (car.wheels[0] as VehicleWheel3D).suspension_stiffness
		"susp_damping":
			return (car.wheels[0] as VehicleWheel3D).damping_compression
		"susp_travel":
			return (car.wheels[0] as VehicleWheel3D).suspension_travel
	return float(car.get(key))


static func set_car_value(car: VehicleBody3D, key: String, v: float) -> void:
	match key:
		"mass":
			car.mass = v
		"susp_stiffness", "susp_damping", "susp_travel":
			for w in car.wheels:
				var wv := w as VehicleWheel3D
				if key == "susp_stiffness":
					wv.suspension_stiffness = v
				elif key == "susp_damping":
					wv.damping_compression = v
					wv.damping_relaxation = v * 1.33
				else:
					wv.suspension_travel = v
		"drive":
			car.set("drive", int(v))
		_:
			car.set(key, v)


## Applique les réglages du joueur à une voiture qui vient d'apparaître.
func apply_car(car: VehicleBody3D) -> void:
	for k in car_tuning:
		set_car_value(car, k, float(car_tuning[k]))


## Texte à copier et à envoyer : toutes les valeurs, celles changées marquées d'un « * ».
func car_text(car: VehicleBody3D, base: Dictionary) -> String:
	var lines: Array[String] = ["Réglages conduite (%s) :" % car.model_name]
	for c in CAR:
		var k: String = c[0]
		var v := car_value(car, k)
		var mark := "  *" if car_tuning.has(k) else ""
		var was := ""
		if car_tuning.has(k) and base.has(k):
			was = " (avant %s)" % fmt(float(base[k]), float(c[4]))
		lines.append("%s = %s%s%s" % [k, fmt(v, float(c[4])), was, mark])
	return "\n".join(lines)


static func fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(roundi(v))
	if step >= 0.1:
		return "%.1f" % v
	return "%.2f" % v
