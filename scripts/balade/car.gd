## Voiture de la balade : VehicleBody3D de Godot (suspensions et pneus simulés roue par
## roue) plus une couche « arcade » : 4x4, propulsion ou traction, adhérence selon le sol,
## frein à main et gaz qui font déraper l'arrière, contre-braquage automatique, garde-fou
## anti tête-à-queue, appui à haute vitesse, retour au sec si la voiture est sur le toit
## ou à la mer. L'avant est vers +Z (convention de VehicleBody3D).
extends VehicleBody3D

const WL = preload("res://scripts/core/world_layout.gd")

enum Drivetrain { ALL_WHEEL, REAR_WHEEL, FRONT_WHEEL }
const DRIVE_NAMES: Array[String] = ["4x4", "Propulsion", "Traction"]

## Modèles jouables : la « Car Concept » de Khronos (CC-BY 4.0, voiture réaliste sans marque)
## et le Car Kit de Kenney (CC0, low poly), provisoires.
## Voitures « street » (Sketchfab, Daniel Zhabotinsky, CC-BY 4.0) : détaillées et légères
## (18 000 à 28 000 triangles, textures 512 px), noms inventés, plaques et badges masqués.
const STREET: Array[String] = ["tiara", "phoenix", "kiri", "lasley", "lightbody", "bokaroo"]
## Voitures « toon » (style low poly en couleurs unies) : citadine et berline du pack
## « 4 Low Poly Toon City Cars » (Viktor Tselikov) et pick-up (farooq.smurf), CC-BY 4.0.
## Valeur : fichier, nom des pièces à garder dans le pack, longueur réelle (m).
const TOON := {
	"toon_hatchback": ["res://assets/cars/toon/toon4.glb", "Hatchback", 3.7],
	"toon_sedan": ["res://assets/cars/toon/toon4.glb", "Sedan", 4.0],
	"toon_pickup": ["res://assets/cars/toon/pickup.glb", "", 4.4],
}
const MODELS: Array[String] = ["toon_hatchback", "toon_sedan", "toon_pickup", "tiara", "phoenix", "kiri", "lasley", "lightbody", "bokaroo", "concept", "hatchback-sports", "suv", "van"]
## Nom affiché de chaque voiture (noms de jeu, jamais de marque réelle).
const DISPLAY_NAMES := {
	"tiara": "Tiara GT '83", "phoenix": "Phoenix 455 '71", "kiri": "Kiri '86", "lasley": "Lasley '67",
	"lightbody": "Lightbody '85", "bokaroo": "Bokaroo '67", "concept": "Concept",
	"hatchback-sports": "Kit Sport", "suv": "Kit SUV", "van": "Kit Van",
	"toon_hatchback": "Citadine", "toon_sedan": "Berline", "toon_pickup": "Pick-up"}
const CAR_LENGTH := 4.4
## Noms possibles des roues, dans l'ordre avant gauche, avant droite, arrière gauche, arrière droite.
const WHEEL_NAMES: Array = [
	["wheel-front-left", "WheelFrontL"], ["wheel-front-right", "WheelFrontR"],
	["wheel-back-left", "WheelRearL"], ["wheel-back-right", "WheelRearR"]]
## Pièces masquées : plaques et logos (aucune marque à l'écran), et l'intérieur, invisible
## vu du drone (deux fois moins d'objets à dessiner).
const HIDDEN_PARTS: Array[String] = ["License Plate", "Numberplate", "Badges", "Emblem", "Logo", "Interior", "Engine", "Pedal", "Steering"]
## Repères des roues dans les noms des modèles « street » : avant gauche, avant droite, arrière gauche, arrière droite.
const WHEEL_TAGS: Array = [["_FL"], ["_FR"], ["_RL", "_BL", "R L"], ["_RR", "_BR", "R R"]]
const WHEEL_TAGS_FRONT: Array = [["F L"], ["F R"]]


static func model_path(model: String) -> String:
	if model == "concept":
		return "res://assets/cars/concept/CarConcept.glb"
	if model in STREET:
		return "res://assets/cars/street/%s.glb" % model
	if TOON.has(model):
		return TOON[model][0]
	return "res://assets/cars/kenney/%s.glb" % model

@export_group("Moteur et freins")
@export var engine_force_total := 10000.0
@export var brake_force := 40.0
@export var handbrake_force := 10.0
@export var top_speed_kmh := 150.0
@export var reverse_speed_kmh := 35.0
@export_group("Transmission")
@export var drive := Drivetrain.REAR_WHEEL
@export_range(0.0, 1.0) var awd_rear_share := 0.65
@export_group("Direction")
@export var max_steer_deg := 32.0
@export var min_steer_deg := 8.0
@export var steer_fade_kmh := 120.0
@export_group("Adhérence et dérapage")
## Adhérence des pneus sur le bitume (friction_slip de Godot) ; multipliée par le sol.
@export var tyre_grip := 3.2
## 0 = sage, 1 = très joueur : perte d'adhérence de l'arrière sous les gaz et au frein à main.
@export_range(0.0, 1.0) var drift := 0.6
## Les roues avant suivent la glisse : dérapages rattrapables au doigt.
@export_range(0.0, 1.0) var counter_steer := 0.55
@export var max_drift_deg := 48.0
@export var drift_yaw_assist := 1.2
@export var lateral_assist := 0.9
@export var downforce := 2.0
## Aide à rester sur ses roues : redresse doucement la caisse et amortit le roulis.
@export var upright_assist := 2.5

## Couple → accélération angulaire : inertie de lacet d'une voiture ≈ 1,9 × sa masse (m²).
const YAW_INERTIA := 1.9

var controls: Node
var wheels: Array[VehicleWheel3D] = []
var model_name := ""

# État lu par les effets, la caméra et l'affichage.
var speed_kmh := 0.0
var forward_speed := 0.0
var slip_angle := 0.0
var in_water := false
var wheel_surface: Array[int] = [WL.Surface.SAND, WL.Surface.SAND, WL.Surface.SAND, WL.Surface.SAND]
var wheel_slip: Array[float] = [0.0, 0.0, 0.0, 0.0]

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
	# Pack de plusieurs voitures : on ne garde que les pièces de celle demandée.
	if TOON.has(model) and String(TOON[model][1]) != "":
		var keep := String(TOON[model][1])
		for m in visual.find_children("*", "MeshInstance3D", true, false):
			if not String(m.name).contains(keep):
				m.get_parent().remove_child(m)
				m.queue_free()
	var car: VehicleBody3D = load("res://scripts/balade/car.gd").new()
	car.name = "Voiture"
	car.model_name = model
	car.controls = controls_node
	car.mass = 1400.0
	car.add_child(visual)

	for part in visual.find_children("*", "MeshInstance3D", true, false):
		for h in HIDDEN_PARTS:
			if String(part.name).containsn(h):
				part.queue_free()
				part.get_parent().remove_child(part)
				break
	var wheel_nodes: Array[Node3D] = []
	for k in 4:
		var found: Node3D = null
		for n in WHEEL_NAMES[k]:
			found = visual.find_child(n, true, false) as Node3D
			if found:
				break
		if found == null:
			# Modèles « street » : maillage dont le nom contient « Wheel » et le repère de la roue.
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
	var length: float = TOON[model][2] if TOON.has(model) else CAR_LENGTH
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
	car.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.05
	car.physics_material_override = pm
	# Centre de gravité bas : la voiture se renverse moins.
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = Vector3(0.0, axle * 0.6, 0.1)
	car.continuous_cd = true

	const REST := 0.32
	for i in 4:
		var c := _center(wheel_nodes[i], car)
		var w := VehicleWheel3D.new()
		w.name = WHEEL_NAMES[i][0]
		w.position = c + Vector3.UP * REST * 0.6
		w.wheel_radius = radius
		w.wheel_rest_length = REST
		w.suspension_travel = 0.28
		w.suspension_stiffness = 38.0
		w.suspension_max_force = 80000.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.2
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

	if model == "concept":
		_fix_glass(visual)
	elif not model in STREET and not TOON.has(model):
		_paint(visual)
	car.drive = _drivetrain_of(model)
	if model in ["van", "suv", "lightbody", "bokaroo"]:
		car.drift = 0.4
	elif model == "tiara":
		car.drift = 0.8
	return car


static func _drivetrain_of(model: String) -> int:
	match model:
		"concept", "tiara", "phoenix": return Drivetrain.REAR_WHEEL
		"kiri", "lasley", "toon_hatchback": return Drivetrain.FRONT_WHEEL
		"toon_sedan": return Drivetrain.REAR_WHEEL
		"toon_pickup": return Drivetrain.ALL_WHEEL
		"lightbody", "bokaroo": return Drivetrain.ALL_WHEEL
		"suv": return Drivetrain.ALL_WHEEL
		"taxi", "van": return Drivetrain.FRONT_WHEEL
	return Drivetrain.REAR_WHEEL


## Peinture vernie : reflète le ciel et le soleil.
static func _paint(visual: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/cars/kenney/Textures/colormap.png")
	mat.roughness = 0.28
	mat.metallic = 0.25
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.clearcoat_roughness = 0.15
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat


## Vitres : le verre du modèle (réfraction) passe mal sur mobile et sur le web ; on le
## remplace par un verre fumé simple, transparent et brillant.
static func _fix_glass(visual: Node3D) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.05, 0.06, 0.88)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.6
	glass.roughness = 0.04
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var n := String(mi.name)
		var is_glass := n.containsn("Window") or n.containsn("Windshield")
		if is_glass and not n.containsn("Gasket") and not n.containsn("Wiper"):
			mi.material_override = glass


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


func _physics_process(delta: float) -> void:
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
			grip = WL.grip(wheel_surface[i])
			wheel_slip[i] = 1.0 - w.get_skidinfo()
		else:
			wheel_slip[i] = 0.0
		var loss := 1.0
		if not front:
			if handbrake:
				loss = lerpf(0.45, 0.25, drift)
			loss *= 1.0 - 0.5 * power_oversteer
			loss *= 1.0 - 0.25 * drift * drifting
		w.wheel_friction_slip = tyre_grip * grip * loss
		var share := (1.0 - rear_share) if front else rear_share
		# Force répartie entre les deux roues de l'essieu ; un peu moins sur sol mou.
		w.engine_force = drive_in * engine_force_total * share * 0.5 * lerpf(0.75, 1.0, grip)
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
		apply_central_force(-right * lateral * assist * mass)
		# Dérapage : frein à main ou gaz en propulsion font pivoter la voiture.
		var kick := (1.0 if handbrake else 0.0) + power_oversteer * 0.6
		if kick > 0.0 and kmh > 15.0:
			apply_torque(up * (-steer) * drift_yaw_assist * minf(1.0, kick) * mass * YAW_INERTIA)
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

	# Mer : la voiture freine fort dans l'eau.
	in_water = global_position.y < WL.SEA_LEVEL + 0.1
	linear_damp = 2.5 if in_water else 0.05
	angular_damp = 3.0 if in_water else 0.5

	_safe_timer += delta
	if grounded >= 3 and not in_water and up.y > 0.7 and _safe_timer > 1.5:
		_safe_timer = 0.0
		_safe_pos = global_position
		_safe_yaw = rotation.y

	_upside_down = _upside_down + delta if up.y < 0.3 else 0.0
	var drowned := global_position.y < WL.SEA_LEVEL - 1.5
	var requested: bool = controls != null and controls.reset_requested
	if _upside_down > 2.0 or drowned:
		respawn(_safe_pos, _safe_yaw)
	elif requested:
		respawn(global_position, rotation.y)


func respawn(pos: Vector3, yaw: float) -> void:
	var ground: float = world_data.height_at(pos.x, pos.z) if world_data else WL.height(pos.x, pos.z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, maxf(ground, WL.SEA_LEVEL) + 1.2, pos.z))
	_upside_down = 0.0
