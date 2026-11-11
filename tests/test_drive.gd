## Banc d'essai de la conduite, sans affichage : la balade tourne en vrai (monde, physique),
## avec des commandes simulées. Mesure l'accélération sur bitume et sur sable, le freinage,
## un dérapage au frein à main, et vérifie que la voiture ne se retourne pas.
##   godot --headless --path . -s tests/test_drive.gd [-- modèle]
extends SceneTree

const WL = preload("res://scripts/core/world_layout.gd")

var balade: Node
var car: VehicleBody3D
var t := 0.0
var phase := 0
var log_lines: Array[String] = []
var failures := 0
var _mark := 0.0
var _start := Vector3.ZERO
var _max_slip := 0.0
var _min_up := 1.0


func _init() -> void:
	var model := "puce"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		model = args[0]
	balade = load("res://scenes/balade.tscn").instantiate()
	balade.start_model = model
	root.add_child(balade)
	physics_frame.connect(_tick)


func _press(gas: float, brake: float, steer: float, hand: bool) -> void:
	for a in ["ci_gas", "ci_brake", "ci_left", "ci_right", "ci_drift"]:
		Input.action_release(a)
	if gas > 0.0: Input.action_press("ci_gas", gas)
	if brake > 0.0: Input.action_press("ci_brake", brake)
	if steer > 0.0: Input.action_press("ci_right", steer)
	if steer < 0.0: Input.action_press("ci_left", -steer)
	if hand: Input.action_press("ci_drift")


func _place(x: float, z: float, yaw: float) -> void:
	car.respawn(Vector3(x, 0, z), yaw)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("ÉCHEC : " + what)


func _tick() -> void:
	var dt := 1.0 / 60.0
	t += dt
	car = balade.car
	if car == null:
		return
	_min_up = minf(_min_up, car.global_basis.y.y)
	match phase:
		0:  # Bitume : rue nord-sud de la ville (x = -412, au milieu de la rue), vers +z.
			if t > 0.1:
				_place(-412.0, -300.0, 0.0)
				_press(1, 0, 0, false)
				phase = 1; _mark = t
		1:
			if t - _mark >= 5.0:
				log_lines.append("bitume : %d km/h après 5 s" % roundi(car.speed_kmh))
				check(car.speed_kmh > 70.0, "accélération sur bitume (%d km/h en 5 s)" % roundi(car.speed_kmh))
				_press(0, 1, 0, false)
				phase = 2; _mark = t; _start = car.global_position
		2:
			if car.speed_kmh < 2.0 or t - _mark > 6.0:
				var d := car.global_position.distance_to(_start)
				log_lines.append("freinage : %.1f s, %.0f m" % [t - _mark, d])
				check(t - _mark < 4.0, "freinage en moins de 4 s")
				_press(1, 0, 0, false)
				phase = 3; _mark = t
		3:  # Relance dans la terre (grand espace ouvert), puis dérapage au frein à main.
			if t - _mark < dt * 1.5:
				log_lines.append("le plus penché sur bitume : droite = %.2f" % _min_up)
				_min_up = 1.0
				_place(0.0, -300.0, 0.0)
				_press(1, 0, 0, false)
			if t - _mark >= 4.0:
				_press(0.6, 0, 1, true)
				phase = 4; _mark = t; _max_slip = 0.0
		4:
			_max_slip = maxf(_max_slip, absf(car.slip_angle))
			if t - _mark >= 1.2:
				_press(1, 0, 0, false)
				phase = 5; _mark = t
		5:
			_max_slip = maxf(_max_slip, absf(car.slip_angle))
			if t - _mark >= 2.5:
				log_lines.append("dérapage : glisse maxi %d°, encore %d km/h, le plus penché : %.2f" % [roundi(_max_slip), roundi(car.speed_kmh), _min_up])
				check(_min_up > 0.5, "pas de tonneau pendant le dérapage")
				_min_up = 1.0
				check(_max_slip > 20.0, "le frein à main fait déraper (%d°)" % roundi(_max_slip))
				check(_max_slip < 85.0, "pas de tête-à-queue (%d°)" % roundi(_max_slip))
				check(car.global_basis.y.y > 0.8, "pas de tonneau en dérapage")
				# Sable : départ des dunes, vers l'ouest.
				_place(WL.SPAWN_X, WL.SPAWN_Z, -PI / 2.0)
				_press(0, 0, 0, false)
				phase = 6; _mark = t
		6:
			if t - _mark >= 1.0:
				_press(1, 0, 0, false)
				phase = 7; _mark = t
		7:
			if t - _mark >= 5.0:
				log_lines.append("sable : %d km/h après 5 s (%s)" % [roundi(car.speed_kmh), WL.SURFACE_NAMES[car.wheel_surface[2]]])
				check(car.speed_kmh > 35.0, "on avance dans le sable (%d km/h en 5 s)" % roundi(car.speed_kmh))
				phase = 8
		8:
			log_lines.append("le plus penché dans les dunes : droite = %.2f" % _min_up)
			check(_min_up > 0.3, "pas de tonneau dans les dunes")
			for l in log_lines:
				print(l)
			print("%s : %d échec(s)" % [car.model_name, failures])
			quit(1 if failures > 0 else 0)
