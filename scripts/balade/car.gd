## Voiture de la balade : VehicleBody3D de Godot (suspensions et pneus simulés roue par
## roue) plus une couche « arcade » : 4x4, propulsion ou traction, adhérence selon le sol,
## frein à main et gaz qui font déraper l'arrière, contre-braquage automatique, garde-fou
## anti tête-à-queue, appui à haute vitesse, retour au sec si la voiture est sur le toit
## ou à la mer. L'avant est vers +Z (convention de VehicleBody3D).
extends VehicleBody3D

const WL = preload("res://scripts/core/world_layout.gd")
const Waves = preload("res://scripts/balade/waves.gd")

enum Drivetrain { ALL_WHEEL, REAR_WHEEL, FRONT_WHEEL }
const DRIVE_NAMES: Array[String] = ["4x4", "Propulsion", "Traction"]

## Voitures du « Low Poly Car Set » (BetelgeuseMan, CC-BY 4.0, crédits dans
## assets/cars/lowpoly/) : un seul fichier, chaque véhicule = un nœud sous « Root » avec ses
## quatre roues (« ..._WhFL », « _WhFR », « _WhBL », « _WhBR »).
## Valeur : nom du véhicule dans le pack, longueur réelle (m).
const PACK := "res://assets/cars/lowpoly/cars.glb"
const TOON := {
	"bolide": ["Car03_1_Racing", 4.6], "bolide_gt": ["Car03_2_Racing", 4.9],
	"puce": ["Car01_1", 3.6], "puce_carbone": ["Car01_1_Carbon", 3.6], "familiale": ["Car01_2", 3.8],
	"coupe": ["Car02_1", 4.5], "break": ["Car02_2", 4.7], "fourgon": ["Car02_3", 4.7],
	"berline": ["Car03_1", 4.7], "berline_longue": ["Car03_2", 5.0],
	# Circulation seulement (pas jouables) :
	"taxi": ["Car01_2_Taxi", 3.8], "police": ["Car03_1_Police", 4.8], "police_break": ["Car02_2_Police", 4.7],
	"police_puce": ["Car01_2_Police", 3.8], "ambulance": ["Car02_3_Ambulance", 4.7],
}
## Voitures que le joueur peut conduire (bouton VOITURE).
const MODELS: Array[String] = ["bolide", "bolide_gt", "puce", "puce_carbone", "familiale", "coupe", "break", "fourgon", "berline", "berline_longue"]
## Nom affiché de chaque voiture (noms de jeu, jamais de marque réelle).
const DISPLAY_NAMES := {
	"bolide": "Bolide", "bolide_gt": "Bolide GT", "puce": "Puce", "puce_carbone": "Puce Carbone",
	"familiale": "Familiale", "coupe": "Coupé", "break": "Break", "fourgon": "Fourgon",
	"berline": "Berline", "berline_longue": "Berline longue", "taxi": "Taxi", "police": "Police",
	"police_break": "Police", "police_puce": "Police", "ambulance": "Ambulance"}
## Roues du pack : repère dans le nom du nœud, dans l'ordre AvG, AvD, ArG, ArD.
const WHEEL_CODES: Array[String] = ["_WhFL", "_WhFR", "_WhBL", "_WhBR"]
## Noms possibles des roues, dans l'ordre avant gauche, avant droite, arrière gauche, arrière droite.
const WHEEL_NAMES: Array = [
	["wheel-front-left", "WheelFrontL"], ["wheel-front-right", "WheelFrontR"],
	["wheel-back-left", "WheelRearL"], ["wheel-back-right", "WheelRearR"]]
## Pièces masquées : plaques et logos (aucune marque à l'écran), et l'intérieur, invisible
## vu du drone (deux fois moins d'objets à dessiner).
const HIDDEN_PARTS: Array[String] = ["License Plate", "Numberplate", "Badges", "Emblem", "Logo", "Interior", "Engine", "Pedal", "Steering"]
## Repères des roues dans les noms des maillages : avant gauche, avant droite, arrière gauche, arrière droite.
const WHEEL_TAGS: Array = [["_FL"], ["_FR"], ["_RL", "_BL", "R L"], ["_RR", "_BR", "R R"]]
const WHEEL_TAGS_FRONT: Array = [["F L"], ["F R"]]


static func model_path(_model: String) -> String:
	return PACK

@export_group("Moteur et freins")
@export var engine_force_total := 16500.0
@export var brake_force := 40.0
@export var handbrake_force := 10.0
@export var top_speed_kmh := 185.0
@export var reverse_speed_kmh := 35.0
@export_group("Transmission")
@export var drive := Drivetrain.REAR_WHEEL
@export_range(0.0, 1.0) var awd_rear_share := 0.65
@export_group("Direction")
@export var max_steer_deg := 45.0
@export var min_steer_deg := 12.5
@export var steer_fade_kmh := 120.0
@export_group("Adhérence et dérapage")
## Adhérence des pneus sur le bitume (friction_slip de Godot) ; multipliée par le sol.
@export var tyre_grip := 1.0
## 0 = sage, 1 = très joueur : perte d'adhérence de l'arrière sous les gaz et au frein à main.
@export_range(0.0, 1.0) var drift := 0.75
## Les roues avant suivent la glisse : dérapages rattrapables au doigt.
@export_range(0.0, 1.0) var counter_steer := 0.79
@export var max_drift_deg := 80.0
@export var drift_yaw_assist := 2.2
@export var lateral_assist := 0.65
## Glisse qui garde la vitesse : en travers, gaz appuyé, la voiture est poussée dans le sens
## où elle va (compense le frottement des pneus de côté), comme dans un jeu de rallye.
@export var slide_keep := 1.4
@export var downforce := 2.0
## Aide à rester sur ses roues : redresse doucement la caisse et amortit le roulis.
@export var upright_assist := 2.5
## Façon jeux de drift : en glisse, les gaz règlent l'angle (plus de gaz = l'arrière sort
## plus, lever le pied = la voiture se redresse) …
@export_range(0.0, 1.0) var throttle_angle := 0.3
## … et le volant fait pivoter la voiture en travers (on « dessine » la ligne au doigt).
@export var drift_steer := 0.0
@export_group("Caisse (visuel)")
## Roulis de la caisse (degrés par g d'accélération latérale) : penche vers l'extérieur.
@export var body_roll := 9.0
## Tangage (degrés par g) : s'assoit à l'accélération, plonge au freinage.
@export var body_pitch := 6.0
## Fréquence des ressorts de caisse (Hz) : bas = très tendre, la caisse bouge lentement.
@export var body_freq := 1.3
## 0 = bien amortie, 1 = la caisse oscille longtemps avant de se poser.
@export_range(0.0, 1.0) var body_wobble := 0.55

## Couple → accélération angulaire : inertie de lacet d'une voiture ≈ 1,9 × sa masse (m²).
const YAW_INERTIA := 1.9

var controls: Node
## Pivot de la caisse dessinée (penche, se cabre, s'écrase à la réception).
var body_node: Node3D
var _roll := 0.0
var _roll_v := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _heave := 0.0
var _heave_v := 0.0
var _last_vel := Vector3.ZERO
var _last_ang := Vector3.ZERO
var _motion_ready := false
var wheels: Array[VehicleWheel3D] = []
var model_name := ""

# État lu par les effets, la caméra et l'affichage.
var speed_kmh := 0.0
var forward_speed := 0.0
var slip_angle := 0.0
var in_water := false
## Profondeur de la voiture dans l'eau (0 = au sec, 1 = caisse entièrement sous l'eau).
var submerged := 0.0
var _sunk_time := 0.0
## Flottaison : la voiture flotte un moment, tangue avec la houle, puis prend l'eau et coule.
@export var buoyancy := 1.25
## Secondes à flotter avant de prendre l'eau, puis durée de la descente.
@export var float_time := 5.0
@export var sink_time := 6.0
var _water_time := 0.0
var body_half := Vector3(0.9, 0.5, 2.1)
var body_bottom := 0.35
var wheel_surface: Array[int] = [WL.Surface.SAND, WL.Surface.SAND, WL.Surface.SAND, WL.Surface.SAND]
var wheel_slip: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Profondeur de l'ornière sous chaque roue (m), donnée par balade.gd : freine un peu plus.
var wheel_sink: Array[float] = [0.0, 0.0, 0.0, 0.0]
const WHEEL_REST := 0.32
# Résistance au roulement par sol (part du poids) : bitume, terre, sable, sable mouillé, eau.
const ROLLING := [0.012, 0.018, 0.045, 0.035, 0.0]

var world_data: RefCounted
var _upside_down := 0.0
var _safe_pos := Vector3.ZERO
var _safe_yaw := 0.0
var _safe_timer := 0.0


## Fabrique une voiture à partir d'un modèle du kit : remise dans le bon sens d'après la
## position des roues, mise à la taille d'une vraie voiture, corps physique et 4 roues.
static func create(model: String, controls_node: Node) -> VehicleBody3D:
	var scene: PackedScene = load(model_path(model))
	var visual: Node3D = scene.instantiate()
	# Pack de plusieurs véhicules : on ne garde que le nœud du véhicule demandé.
	var keep := String(TOON[model][0])
	var root := visual.find_child("Root", true, false)
	var vehicle: Node = null
	if root:
		for n in root.get_children():
			if String(n.name) == keep:
				vehicle = n
			else:
				root.remove_child(n)
				n.queue_free()
	var car: VehicleBody3D = load("res://scripts/balade/car.gd").new()
	car.name = "Voiture"
	car.model_name = model
	car.controls = controls_node
	car.mass = 1400.0
	# La caisse dessinée est sous un pivot à part : elle penche et rebondit (visuel seulement)
	# pendant que les roues restent posées.
	var body_node := Node3D.new()
	body_node.name = "Caisse"
	car.add_child(body_node)
	car.body_node = body_node
	body_node.add_child(visual)

	# Les matériaux du pack sont « sans éclairage » (toujours en pleine lumière) : on les
	# éclaire vraiment, avec un léger brillant de carrosserie (ombres, nuit, phares).
	var lit := {}
	for part in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(si) as BaseMaterial3D
			if src == null:
				continue
			if not lit.has(src):
				var m := src.duplicate() as BaseMaterial3D
				m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				m.roughness = 0.45
				m.metallic_specular = 0.4
				lit[src] = m
			mi.set_surface_override_material(si, lit[src])
	for part in visual.find_children("*", "MeshInstance3D", true, false):
		for h in HIDDEN_PARTS:
			if String(part.name).containsn(h):
				part.queue_free()
				part.get_parent().remove_child(part)
				break
	var wheel_nodes: Array[Node3D] = []
	for k in 4:
		var found: Node3D = null
		var whole: Node3D = null
		if vehicle:
			for c in vehicle.get_children():
				if String(c.name).contains(WHEEL_CODES[k]):
					whole = c as Node3D
					break
		if whole:
			wheel_nodes.append(whole)
			continue
		for n in WHEEL_NAMES[k]:
			found = visual.find_child(n, true, false) as Node3D
			if found:
				break
		if found == null:
			# Sinon : maillage dont le nom contient « Wheel » (ou « Tire ») et le repère de la roue.
			var tags: Array = WHEEL_TAGS[k] + (WHEEL_TAGS_FRONT[k] if k < 2 else [])
			for m in visual.find_children("*", "MeshInstance3D", true, false):
				var nm := String(m.name)
				if not (nm.containsn("Wheel") or nm.containsn("Tire")) or nm.containsn("Steering"):
					continue
				for tag in tags:
					if nm.contains(tag):
						found = m
						break
				if found:
					break
		wheel_nodes.append(found)

	# 1. Sens : l'avant est du côté des roues avant.
	var front := (_center(wheel_nodes[0], car) + _center(wheel_nodes[1], car)) / 2.0
	var back := (_center(wheel_nodes[2], car) + _center(wheel_nodes[3], car)) / 2.0
	var fwd := Vector3(front.x - back.x, 0.0, front.z - back.z)
	visual.rotate_y(fwd.signed_angle_to(Vector3.BACK, Vector3.UP))
	# 2. Taille : longueur réelle d'une voiture.
	var b := _bounds(visual, car)
	var length: float = TOON[model][1]
	var s := length / maxf(b.size.z, 0.01)
	visual.scale *= s
	visual.position *= s
	# 3. Centrée, le bas des roues à y = 0.
	b = _bounds(visual, car)
	visual.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)
	b = _bounds(visual, car)
	# Modèle en miroir : la roue « gauche » doit être à gauche (+X quand on regarde vers +Z).
	if _center(wheel_nodes[0], car).x < _center(wheel_nodes[1], car).x:
		wheel_nodes = [wheel_nodes[1], wheel_nodes[0], wheel_nodes[3], wheel_nodes[2]]

	var radius := 0.0
	for w in wheel_nodes:
		radius += _node_bounds(w, car).size.y / 8.0
	var axle := radius

	# Carrosserie : une boîte au-dessus des essieux (les roues sont des rayons).
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bottom := axle + 0.05
	box.size = Vector3(b.size.x * 0.92, b.end.y - bottom, b.size.z * 0.96)
	shape.shape = box
	shape.position = Vector3(b.get_center().x, (bottom + b.end.y) / 2.0, b.get_center().z)
	car.body_half = box.size / 2.0
	car.body_bottom = bottom
	car.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.05
	car.physics_material_override = pm
	# Centre de gravité bas : la voiture se renverse moins.
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = Vector3(0.0, axle * 0.6, 0.1)
	car.continuous_cd = true

	for i in 4:
		var c := _center(wheel_nodes[i], car)
		var w := VehicleWheel3D.new()
		w.name = WHEEL_NAMES[i][0]
		w.position = c + Vector3.UP * WHEEL_REST * 0.6
		w.wheel_radius = radius
		w.wheel_rest_length = WHEEL_REST
		w.suspension_travel = 0.5
		w.suspension_stiffness = 15.0
		w.suspension_max_force = 80000.0
		w.damping_compression = 0.3
		w.damping_relaxation = 0.4
		w.wheel_roll_influence = 0.04
		w.wheel_friction_slip = 3.2
		w.use_as_steering = i < 2
		car.add_child(w)
		# Le dessin de la roue devient enfant de la roue physique : Godot le fait tourner et braquer.
		var rel := _rel(wheel_nodes[i], car)
		wheel_nodes[i].owner = null
		wheel_nodes[i].get_parent().remove_child(wheel_nodes[i])
		w.add_child(wheel_nodes[i])
		wheel_nodes[i].transform = Transform3D(rel.basis, Vector3.ZERO)
		car.wheels.append(w)
	# Le dessin des roues est placé par rapport au centre de la roue physique.
	for i in 4:
		var mesh := car.wheels[i].get_child(0) as Node3D
		var c := _node_bounds(mesh, car.wheels[i])
		mesh.position -= c.get_center()
		car._wheel_base.append(mesh.position)

	car.drive = _drivetrain_of(model)
	if model in ["fourgon", "berline_longue"]:
		car.drift = 0.6
		# Longues et hautes : un peu plus d'aide pour rester sur leurs roues.
		car.upright_assist = 3.5
	return car


static func _drivetrain_of(model: String) -> int:
	match model:
		"puce", "puce_carbone", "familiale", "break": return Drivetrain.FRONT_WHEEL
		"fourgon", "bolide_gt": return Drivetrain.ALL_WHEEL
	return Drivetrain.REAR_WHEEL


static func _mesh_bounds(m: MeshInstance3D, ref: Node3D) -> AABB:
	# Boîte du maillage dans le repère de `ref` (les nœuds ne sont pas encore dans l'arbre).
	var xf := _rel(m, ref)
	return xf * m.get_aabb()


static func _rel(n: Node3D, ref: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ref:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _center(n: Node3D, ref: Node3D) -> Vector3:
	return _node_bounds(n, ref).get_center()


## Boîte d'un nœud et de tous les maillages qu'il contient, dans le repère de `ref`.
static func _node_bounds(n: Node3D, ref: Node3D) -> AABB:
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	var out := AABB()
	var first := true
	for m in meshes:
		var b := _mesh_bounds(m, ref)
		out = b if first else out.merge(b)
		first = false
	return out


static func _bounds(visual: Node3D, ref: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		var b := _mesh_bounds(m, ref)
		out = b if first else out.merge(b)
		first = false
	return out


func _ready() -> void:
	_safe_pos = global_position
	_safe_yaw = rotation.y


## Dessin des roues : posées exactement sur le sol (ou au fond de leur ornière). La roue
## physique de Godot se dessine quelques centimètres dans le sol ; on corrige seulement le
## dessin, le long de l'axe vertical de la voiture (le décalage est exprimé dans le repère de
## la roue, qui tourne : sans ça la roue tournerait en ovale).
var _wheel_fix: Array[float] = [0.0, 0.0, 0.0, 0.0]
# Recentrage du dessin de chaque roue sur son axe (certains modèles ont le pivot ailleurs).
var _wheel_base: Array[Vector3] = []


func _process(delta: float) -> void:
	var up := global_basis.y
	for i in wheels.size():
		var w := wheels[i]
		var mesh := w.get_child(0) as Node3D
		if mesh == null:
			continue
		var want := _wheel_fix[i]
		if w.is_in_contact():
			var gap := (w.global_position - w.get_contact_point()).dot(up) - w.wheel_radius
			want = clampf(-gap - clampf(wheel_sink[i], 0.0, 0.12), -0.25, 0.25)
		_wheel_fix[i] = lerpf(_wheel_fix[i], want, minf(1.0, delta * 20.0))
		var base: Vector3 = _wheel_base[i] if i < _wheel_base.size() else Vector3.ZERO
		mesh.position = base + w.global_basis.orthonormalized().inverse() * (up * _wheel_fix[i])


## Caisse suspendue (visuel) : la caisse dessinée est une masse posée sur des ressorts très
## tendres au-dessus du châssis physique. Dans le repère du châssis, elle subit l'inverse de
## ses accélérations (inertie) : en virage elle part vers l'extérieur, au freinage elle
## plonge, à l'accélération elle s'assoit, sur une bosse le châssis monte et tourne d'un
## coup et la caisse suit en retard puis oscille. Trois ressorts amortis (roulis, tangage,
## pompage), intégrés au pas fixe de la physique.
func _body_motion(delta: float) -> void:
	if body_node == null or delta <= 0.0:
		return
	var b := global_basis.orthonormalized()
	var inv := b.inverse()
	# Accélérations du châssis dans le monde (la gravité n'y est pas : au repos, zéro),
	# puis dans son propre repère.
	var a_world := (linear_velocity - _last_vel) / delta
	var w_acc := (angular_velocity - _last_ang) / delta
	_last_vel = linear_velocity
	_last_ang = angular_velocity
	if not _motion_ready:
		_motion_ready = true
		return
	var a := (inv * a_world).limit_length(80.0)
	var alpha := inv * w_acc
	alpha = alpha.limit_length(60.0)
	var g := 9.8
	var k := pow(TAU * body_freq, 2.0)
	var zeta := lerpf(0.7, 0.12, body_wobble)
	var c := 2.0 * zeta * sqrt(k)
	# Roulis (autour de l'axe avant, +Z) : accélération vers +X (virage à gauche) -> le haut
	# de la caisse part vers -X, angle positif. Pente d'équilibre : body_roll degrés par g.
	var roll_eq := a.x / g * body_roll
	_roll_v += (k * (roll_eq - _roll) - c * _roll_v - rad_to_deg(alpha.z)) * delta
	_roll = clampf(_roll + _roll_v * delta, -14.0, 14.0)
	# Tangage (autour de +X ; positif = nez qui plonge) : accélérer -> nez qui se lève.
	var pitch_eq := -a.z / g * body_pitch
	_pitch_v += (k * (pitch_eq - _pitch) - c * _pitch_v - rad_to_deg(alpha.x)) * delta
	_pitch = clampf(_pitch + _pitch_v * delta, -9.0, 9.0)
	# Pompage : le châssis monte d'un coup (bosse, réception) -> la caisse s'enfonce.
	_heave_v += (-k * _heave - c * _heave_v - a.y * 0.6) * delta
	_heave = clampf(_heave + _heave_v * delta, -0.14, 0.1)
	var rot := Basis.from_euler(Vector3(deg_to_rad(_pitch), 0.0, deg_to_rad(_roll)))
	# Pivot : axe de roulis bas, au niveau des moyeux (la caisse bascule au-dessus).
	var pivot := Vector3(0.0, body_bottom * 0.7, 0.0)
	body_node.transform = Transform3D(rot, pivot - rot * pivot + Vector3.UP * _heave)


func _physics_process(delta: float) -> void:
	_body_motion(delta)
	var vel := linear_velocity
	var fwd := global_basis.z
	var up := global_basis.y
	var right := -global_basis.x
	forward_speed = vel.dot(fwd)
	speed_kmh = vel.length() * 3.6
	var kmh := absf(forward_speed) * 3.6

	var throttle := 0.0
	var brake_in := 0.0
	var steer := 0.0
	var handbrake := false
	if controls:
		throttle = controls.throttle
		brake_in = controls.brake
		steer = controls.steer
		handbrake = controls.handbrake

	# Le bouton frein freine en avançant, puis passe en marche arrière à l'arrêt.
	var drive_in := 0.0
	var braking := 0.0
	if throttle > 0.01:
		if forward_speed < -1.0:
			braking = throttle
		else:
			drive_in = throttle
	if brake_in > 0.01:
		if forward_speed > 1.0:
			braking = maxf(braking, brake_in)
		else:
			drive_in = -brake_in * 0.7
	if drive_in > 0.0 and kmh > top_speed_kmh:
		drive_in = 0.0
	if drive_in < 0.0 and kmh > reverse_speed_kmh:
		drive_in = 0.0

	# Angle de glisse : la voiture va-t-elle là où pointe son nez ?
	var flat := vel - up * vel.dot(up)
	slip_angle = 0.0
	if flat.length() > 3.0 and forward_speed > 0.0:
		slip_angle = rad_to_deg(fwd.signed_angle_to(flat, up))
	var drifting := clampf((absf(slip_angle) - 6.0) / 20.0, 0.0, 1.0)

	# Braquage (positif = à gauche) : réduit avec la vitesse, plus contre-braquage en glisse.
	# steer > 0 = à droite pour le joueur, d'où le signe moins.
	var max_steer := lerpf(max_steer_deg, min_steer_deg, clampf(kmh / steer_fade_kmh, 0.0, 1.0))
	var steer_deg := -steer * lerpf(max_steer, max_steer_deg, drifting)
	steer_deg += slip_angle * counter_steer * drifting
	steer_deg = clampf(steer_deg, -max_steer_deg - 10.0, max_steer_deg + 10.0)

	var rear_share := 1.0 if drive == Drivetrain.REAR_WHEEL else (0.0 if drive == Drivetrain.FRONT_WHEEL else awd_rear_share)
	var power_oversteer := drift * rear_share * maxf(drive_in, 0.0) * clampf((kmh - 20.0) / 30.0, 0.0, 1.0)

	var grounded := 0
	for i in 4:
		var w := wheels[i]
		var front := i < 2
		if front:
			w.steering = deg_to_rad(steer_deg)
		var grip := 1.0
		if w.is_in_contact():
			grounded += 1
			var p := w.get_contact_point()
			var body := w.get_contact_body()
			wheel_surface[i] = WL.surface_at(p.x, p.z, p.y) if body and body.is_in_group("terrain") else WL.Surface.ASPHALT
			# Sur la piste de rallye : terre tassée.
			if world_data and wheel_surface[i] != WL.Surface.WATER and world_data.road_distance(p.x, p.z) < WL.ROAD_HALF + 0.5:
				wheel_surface[i] = WL.Surface.DIRT
			grip = WL.grip(wheel_surface[i])
			wheel_slip[i] = 1.0 - w.get_skidinfo()
		else:
			wheel_slip[i] = 0.0
		var loss := 1.0
		if not front:
			# L'arrière décroche un peu avant l'avant : la voiture pivote et glisse.
			loss *= 0.92
			if handbrake:
				loss = lerpf(0.45, 0.25, drift)
			loss *= 1.0 - 0.5 * power_oversteer
			loss *= 1.0 - 0.25 * drift * drifting
			# En glisse, l'angle se règle aux gaz.
			loss *= 1.0 - 0.3 * throttle_angle * drifting * maxf(drive_in, 0.0) * rear_share
		w.wheel_friction_slip = tyre_grip * grip * loss
		var share := (1.0 - rear_share) if front else rear_share
		# Force répartie entre les deux roues de l'essieu ; un peu moins sur sol mou.
		w.engine_force = drive_in * engine_force_total * share * 0.5 * lerpf(0.92, 1.0, grip)
		var b := braking * brake_force
		if not front and handbrake:
			b = maxf(b, handbrake_force)
		w.brake = b

	if grounded > 0:
		# Appui : la voiture colle au sol à haute vitesse.
		apply_central_force(-up * downforce * vel.length_squared())
		# Stabilité : on gomme une partie du glissement latéral, moins pendant un dérapage.
		var lateral := vel.dot(right)
		var assist := lateral_assist * (0.1 if handbrake else lerpf(1.0, 0.25, drifting * drift))
		# Rallye : sur terre et sable, l'aide lâche plus tôt, la voiture glisse plus longtemps.
		var loose := 0.0
		for ws in wheel_surface:
			loose += 0.25 if WL.is_soft(ws) else 0.0
		assist *= lerpf(1.0, 0.6, loose)
		apply_central_force(-right * lateral * assist * mass)
		# Sable et terre : les roues patinent beaucoup avec des pneus glissants ; une petite
		# poussée vers l'avant sous les gaz garde la voiture vive, sans toucher à l'adhérence
		# de côté (le dérapage reste le même).
		if drive_in > 0.0 and loose > 0.0 and kmh < 90.0:
			apply_central_force(fwd * drive_in * loose * 3.0 * (1.0 - kmh / 90.0) * mass)
		# En travers sous les gaz : on garde l'élan au lieu de le perdre dans le frottement.
		if slide_keep > 0.0 and drive_in > 0.0 and flat.length() > 5.0:
			var keep := slide_keep * 9.8 * clampf((absf(slip_angle) - 5.0) / 25.0, 0.0, 1.0) * drive_in
			apply_central_force(flat.normalized() * keep * mass)
		# Dérapage : frein à main ou gaz en propulsion font pivoter la voiture.
		var kick := (1.0 if handbrake else 0.0) + power_oversteer * 0.6
		if kick > 0.0 and kmh > 15.0:
			apply_torque(up * (-steer) * drift_yaw_assist * minf(1.0, kick) * mass * YAW_INERTIA)
		# En travers : le volant pivote la voiture (garder ou ouvrir l'angle au doigt).
		if drifting > 0.0 and drift_steer > 0.0 and kmh > 15.0:
			apply_torque(up * (-steer) * drift_steer * drifting * mass * YAW_INERTIA)
		# Roulis : la caisse est ramenée vers la verticale, le roulis est amorti.
		var tilt_axis := up.cross(Vector3.UP)
		var roll_rate := angular_velocity.dot(fwd)
		apply_torque((tilt_axis * upright_assist * 4.0 - fwd * roll_rate * upright_assist) * mass * YAW_INERTIA)
		# Garde-fou : au-delà de l'angle maxi, on freine la rotation.
		var over := absf(slip_angle) - max_drift_deg
		if over > 0.0:
			var yaw_rate := angular_velocity.dot(up)
			if signf(yaw_rate) == -signf(slip_angle):
				apply_torque(-up * yaw_rate * minf(1.0, over / 12.0) * 12.0 * mass * YAW_INERTIA)

	_ground_resistance(delta)
	_float(delta)

	_safe_timer += delta
	if grounded >= 3 and not in_water and up.y > 0.7 and _safe_timer > 1.5:
		_safe_timer = 0.0
		_safe_pos = global_position
		_safe_yaw = rotation.y

	_upside_down = _upside_down + delta if up.y < 0.3 else 0.0
	# Au fond depuis longtemps (la voiture a pris l'eau et coulé) : retour au sec.
	var drowned := _sunk_time > 3.0
	var requested: bool = controls != null and controls.reset_requested
	if _upside_down > 2.0 or drowned:
		respawn(_safe_pos, _safe_yaw)
	elif requested:
		respawn(global_position, rotation.y)


## Flottaison : 12 sondes réparties sous la caisse (3 de large × 4 de long). Chacune porte
## une colonne de caisse ; sa part immergée sous la vraie surface (houle) donne une poussée
## d'Archimède à cet endroit : la voiture tangue et roule avec les vagues, pique du nez en
## entrant dans l'eau. Résistance de l'eau calculée par rapport à l'eau qui bouge (vagues,
## ressac) et selon le sens : la caisse glisse vers l'avant, résiste de côté et surtout à
## la verticale (amortit les rebonds). La poussée faiblit quand la voiture prend l'eau.
const PROBES_X := [-0.8, 0.0, 0.8]
const PROBES_Z := [-0.85, -0.3, 0.3, 0.85]
# Résistance de l'eau (linéaire, quadratique) selon l'axe de la voiture : côté, haut, avant.
const WATER_LIN := Vector3(1.6, 2.2, 0.5)
const WATER_QUAD := Vector3(0.9, 1.2, 0.18)


func _float(delta: float) -> void:
	var xf := global_transform
	var basis_n := xf.basis.orthonormalized()
	var total := 0.0
	var n := PROBES_X.size() * PROBES_Z.size()
	var height := body_half.y * 2.0
	var leak := clampf(1.0 - maxf(0.0, _water_time - float_time) / sink_time, 0.2, 1.0)
	var weight_share := mass * 9.8 / n
	for px in PROBES_X:
		for pz in PROBES_Z:
			var p: Vector3 = xf * Vector3(px * body_half.x, body_bottom, pz * body_half.z)
			var ground: float = world_data.height_at(p.x, p.z) if world_data else WL.height(p.x, p.z)
			var depth := WL.SEA_LEVEL - ground
			if depth <= 0.0:
				continue
			var ws := Waves.surface(p.x, p.z, depth)
			var k := clampf((ws - p.y) / height, 0.0, 1.0)
			if k <= 0.0:
				continue
			total += k / n
			var offset := p - global_position
			var lift := weight_share * buoyancy * leak * k * 1.6
			# Vitesse de la caisse par rapport à l'eau, dans le repère de la voiture.
			var rel := linear_velocity + angular_velocity.cross(offset) - Waves.velocity(p.x, p.z, depth)
			var lv := basis_n.inverse() * rel
			var f := -(WATER_LIN * lv + WATER_QUAD * lv * lv.abs()) * mass / n * k
			apply_force(Vector3.UP * lift + basis_n * f, offset)
	submerged = total
	in_water = total > 0.05
	if in_water:
		_water_time += delta
	else:
		_water_time = maxf(0.0, _water_time - delta * 2.0)
	_sunk_time = _sunk_time + delta if total > 0.9 else 0.0
	angular_damp = lerpf(0.5, 1.2, total)
	linear_damp = 0.05


## Sol meuble et eau peu profonde :
## - résistance au roulement selon le sol, plus forte dans une ornière profonde ;
## - dans l'eau, chaque roue pousse l'eau devant elle (frein qui croît avec la vitesse au
##   carré et la hauteur d'eau).
func _ground_resistance(delta: float) -> void:
	var g := mass * 9.8 / 4.0
	for i in 4:
		var w := wheels[i]
		if not w.is_in_contact():
			continue
		var p := w.get_contact_point()
		var offset := p - global_position
		var v := linear_velocity + angular_velocity.cross(offset)
		v.y = 0.0
		var speed := v.length()
		if speed < 0.05:
			continue
		var dir := v / speed
		var coef: float = ROLLING[wheel_surface[i]] + clampf(wheel_sink[i], 0.0, 0.2) * 0.8
		apply_force(-dir * coef * g * minf(1.0, speed), offset)
		if p.y < WL.SEA_LEVEL + 0.6:
			var depth: float = WL.SEA_LEVEL - (world_data.height_at(p.x, p.z) if world_data else WL.height(p.x, p.z))
			var water := clampf(Waves.surface(p.x, p.z, depth) - p.y, 0.0, 0.8)
			if water > 0.0:
				apply_force(-dir * speed * speed * 260.0 * water, offset)


func respawn(pos: Vector3, yaw: float) -> void:
	_motion_ready = false
	_roll = 0.0
	_roll_v = 0.0
	_pitch = 0.0
	_pitch_v = 0.0
	_heave = 0.0
	_heave_v = 0.0
	var ground: float = world_data.height_at(pos.x, pos.z) if world_data else WL.height(pos.x, pos.z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, maxf(ground, WL.SEA_LEVEL) + 1.2, pos.z))
	_upside_down = 0.0
	_water_time = 0.0
	_sunk_time = 0.0
