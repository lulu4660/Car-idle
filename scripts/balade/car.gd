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


## « Car Kit » de Kenney (CC0, assets/cars/kenney/) : un fichier par véhicule, roues
## « wheel-front-left »… ; longueur réelle (m). Voitures du garage et de la circulation.
const KENNEY := {
	"sedan": 4.6, "sedan-sports": 4.5, "hatchback-sports": 4.1, "suv": 4.6, "suv-luxury": 4.9,
	"van": 5.0, "truck": 5.3, "truck-flat": 5.5, "delivery": 6.5, "delivery-flat": 6.5,
	"race": 4.8, "race-future": 4.8, "taxi": 4.6, "police": 4.7, "ambulance": 5.8,
	"firetruck": 8.5, "garbage-truck": 8.0,
}


## « Free Low Poly Vehicles Pack » de Rgsdev (CC0, assets/cars/rgsdev/) : un peu plus
## détaillé (proportions réalistes, phares, calandres), couleurs unies nommées (« body red »…),
## roues « … wheel front left »… Voitures conduites et circulation. Longueur réelle (m).
const RGSDEV := {
	"sedan": 4.7, "hatchback": 4.1, "muscle": 4.8, "muscle_2": 4.8, "sports": 4.5,
	"roadster": 4.1, "suv": 4.8, "pickup": 5.3, "van": 5.0, "taxi": 4.7, "police_sedan": 4.8,
	"ambulance": 5.8, "limousine": 7.2, "monster_truck": 5.0, "truck": 7.0, "bus": 11.5,
	"firetruck": 8.5,
}
## Noms des roues Rgsdev, dans l'ordre avant gauche, avant droite, arrière gauche, arrière droite.
const RGSDEV_WHEELS: Array[String] = ["wheel front left", "wheel front right", "wheel rear left", "wheel rear right"]


static func model_path(model: String) -> String:
	if model.begins_with("rgs:"):
		return "res://assets/cars/rgsdev/%s.fbx" % model.substr(4)
	return "res://assets/cars/kenney/%s.glb" % model if KENNEY.has(model) else PACK


static func length_of(model: String) -> float:
	if model.begins_with("rgs:"):
		return float(RGSDEV[model.substr(4)])
	return float(KENNEY[model]) if KENNEY.has(model) else float(TOON[model][1])


## Le modèle est-il dans un fichier à lui (Kenney, Rgsdev) plutôt que dans le pack commun ?
static func is_single_file(model: String) -> bool:
	return KENNEY.has(model) or model.begins_with("rgs:")

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
## Aide à la stabilité (façon ESP) : garde la ligne droite et les petites corrections
## sous contrôle ; s'efface quand on veut déraper (volant tenu, frein à main, en travers).
@export_range(0.0, 2.0) var stability := 1.0
@export_group("Roulis (physique)")
## Part de la force des pneus qui fait rouler le châssis (Godot : wheel_roll_influence).
## 0 = la voiture ne penche jamais, 1 = physique réelle : la force de virage au sol, sous le
## centre de gravité, fait pencher la voiture vers l'extérieur sur ses suspensions.
@export_range(0.0, 1.0) var roll_physics := 0.7
## Hauteur du centre de gravité (m) : plus haut = plus de transfert de masse et de roulis.
@export var com_height := 0.42
## Amortissement du roulis et du tangage : plus haut = la voiture penche plus doucement.
@export var roll_damping := 2.4
## Amortissement du tangage (accélération, freinage) : plus haut = plus doux.
@export var pitch_damping := 3.5
## Part du transfert de masse avant/arrière reprise par les trains (0 = caisse qui cabre et
## plonge à fond, 1 = reste à plat).
@export_range(0.0, 1.0) var anti_pitch := 0.55
## Temps pour mettre les gaz à fond / freiner à fond (s).
@export var gas_rise := 0.35
@export var brake_rise := 0.18
@export_group("Caisse (visuel)")
## Roulis de la caisse (degrés par g d'accélération latérale) : penche vers l'extérieur.
@export var body_roll := 3.0
## Tangage (degrés par g) : s'assoit à l'accélération, plonge au freinage.
@export var body_pitch := 2.0
## Fréquence des ressorts de caisse (Hz) : bas = très tendre, la caisse bouge lentement.
@export var body_freq := 1.0
## 0 = bien amortie, 1 = la caisse oscille longtemps avant de se poser.
@export_range(0.0, 1.0) var body_wobble := 0.3

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
var _acc_f := Vector3.ZERO
var _gas_s := 0.0
var _steer_hold := 0.0
var _intent_mem := 0.0
## Sol mouillé par la pluie (0 à 1), donné par la météo.
var wetness := 0.0
var _brake_s := 0.0
var _last_fwd := 0.0
var _a_long_f := 0.0
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
## Boîte de vitesses simulée (son et affichage ; la poussée, elle, reste continue).
## rpm : 0 = ralenti, 1 = zone rouge. gear : 1 à 5, 0 = marche arrière.
const GEAR_TOPS := [0.2, 0.36, 0.55, 0.77, 1.02]
var rpm := 0.0
var gear := 1
var engine_load := 0.0
var shifted := false          # vrai pendant l'image d'un changement de rapport
var grounded_wheels := 0
var _shift_t := 0.0
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
	var keep := "" if is_single_file(model) else String(TOON[model][0])
	var root := visual.find_child("Root", true, false) if keep != "" else null
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
			# Rgsdev : « Sedan wheel front left »…
			for m in visual.find_children("*", "MeshInstance3D", true, false):
				if String(m.name).containsn(RGSDEV_WHEELS[k]):
					found = m
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
	var length: float = length_of(model)
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
	car.center_of_mass = Vector3(0.0, car.com_height, 0.1)
	car.continuous_cd = true

	for i in 4:
		var c := _center(wheel_nodes[i], car)
		car._wheel_rest.append(c)
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
		w.wheel_roll_influence = car.roll_physics
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
	_merge_body(car)

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
## Centre de chaque roue au repos, dans le repère de la caisse, et la place qu'il y a
## au-dessus (m) avant de toucher l'aile.
var _wheel_rest: Array[Vector3] = []
const WHEEL_ARCH_ROOM := 0.05


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
		var shift := up * _wheel_fix[i]
		# La roue dessinée ne remonte jamais dans l'aile : quand la suspension se tasse ou que
		# la caisse penche, on la retient sous son passage de roue (elle s'enfonce un peu
		# dans le sol à la place, invisible d'en haut). Les voitures du kit Kenney ont des
		# passages de roue très serrés.
		if body_node and i < _wheel_rest.size():
			var center := w.global_position + shift
			var in_body := body_node.global_transform.affine_inverse() * center
			var excess := in_body.y - (_wheel_rest[i].y + WHEEL_ARCH_ROOM)
			if excess > 0.0:
				shift -= body_node.global_basis.orthonormalized().y * excess
		mesh.position = base + w.global_basis.orthonormalized().inverse() * shift


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
	# Accélérations lissées (≈ 0,15 s) : pas d'à-coup quand la caisse change de côté.
	var raw := (inv * a_world).limit_length(80.0)
	_acc_f.x = lerpf(_acc_f.x, raw.x, minf(1.0, delta / 0.15))
	_acc_f.y = lerpf(_acc_f.y, raw.y, minf(1.0, delta / 0.08))
	# Avant/arrière plus lissé : le report de masse s'installe sur ≈ 0,3 s.
	_acc_f.z = lerpf(_acc_f.z, raw.z, minf(1.0, delta / 0.3))
	var a := _acc_f
	var fast := lerpf(0.1, 1.0, smoothstep(12.0, 90.0, speed_kmh))
	var alpha := inv * w_acc
	alpha = alpha.limit_length(60.0)
	var g := 9.8
	var k := pow(TAU * body_freq, 2.0)
	var zeta := lerpf(0.7, 0.12, body_wobble)
	var c := 2.0 * zeta * sqrt(k)
	# Roulis (autour de l'axe avant, +Z) : accélération vers +X (virage à gauche) -> le haut
	# de la caisse part vers -X, angle positif. Pente d'équilibre : body_roll degrés par g.
	var roll_eq := a.x / g * body_roll * fast
	_roll_v += (k * (roll_eq - _roll) - c * _roll_v - rad_to_deg(alpha.z)) * delta
	_roll = clampf(_roll + _roll_v * delta, -14.0, 14.0)
	# Tangage (autour de +X ; positif = nez qui plonge) : accélérer -> nez qui se lève.
	var pitch_eq := -a.z / g * body_pitch * fast
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
	# Le roulis vient avec la vitesse : presque rien en manœuvre, plein effet vers 80 km/h.
	var roll_k := roll_physics * lerpf(0.08, 1.0, smoothstep(12.0, 90.0, kmh))
	for w in wheels:
		w.wheel_roll_influence = roll_k

	var throttle := 0.0
	var brake_in := 0.0
	var steer := 0.0
	var handbrake := false
	if controls:
		throttle = controls.throttle
		brake_in = controls.brake
		steer = controls.steer
		handbrake = controls.handbrake
	# Gaz et frein montent progressivement (couple qui s'établit, pression de frein qui
	# monte) : la masse se reporte en douceur au lieu d'un coup.
	_gas_s = move_toward(_gas_s, throttle, delta / (gas_rise if throttle > _gas_s else 0.15))
	_brake_s = move_toward(_brake_s, brake_in, delta / (brake_rise if brake_in > _brake_s else 0.12))
	throttle = _gas_s
	brake_in = _brake_s

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
	# Intention de dérapage : volant tenu un moment, frein à main, ou déjà en travers.
	# Une petite correction de trajectoire n'en est pas une.
	if absf(steer) > 0.5:
		_steer_hold += delta
	else:
		_steer_hold = maxf(0.0, _steer_hold - delta * 3.0)
	var intent_now := clampf(smoothstep(0.12, 0.35, _steer_hold) + drifting * 1.5 + (1.0 if handbrake else 0.0), 0.0, 1.0)
	# L'intention dure un peu après une glisse : la bascule d'un côté à l'autre (le volant
	# repasse par le centre) n'est pas prise pour une simple correction.
	_intent_mem = maxf(intent_now, _intent_mem - delta * 0.8)
	var intent := _intent_mem
	var power_oversteer := drift * rear_share * maxf(drive_in, 0.0) * clampf((kmh - 20.0) / 30.0, 0.0, 1.0) * intent

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
			# Sol mouillé : bitume et terre glissent plus (boue), le sable mouillé tient mieux.
			if wetness > 0.0:
				match wheel_surface[i]:
					WL.Surface.ASPHALT: grip *= 1.0 - 0.18 * wetness
					WL.Surface.DIRT: grip *= 1.0 - 0.22 * wetness
					WL.Surface.SAND: grip *= 1.0 + 0.08 * wetness
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
		# Stabilité (façon ESP) : sans intention de dérapage, la voiture ne tourne pas plus vite
		# que ne le demandent les roues avant ; les petites corrections restent des
		# corrections. Elle s'efface dès qu'on tient le volant, qu'on tire le frein à main ou
		# qu'on est déjà en travers.
		var wheelbase := maxf(body_half.z * 1.4, 1.5)
		var want_yaw := forward_speed * tan(deg_to_rad(steer_deg)) / wheelbase
		var yaw_now := angular_velocity.dot(up)
		var esp := stability * (1.0 - intent) * clampf((kmh - 10.0) / 20.0, 0.0, 1.0)
		# Seulement contre une rotation en trop (survirage), jamais contre un virage voulu.
		var yaw_extra := yaw_now - want_yaw
		if esp > 0.0 and absf(yaw_now) > absf(want_yaw) and signf(yaw_extra) == signf(yaw_now):
			apply_torque(-up * yaw_extra * esp * 5.0 * mass * YAW_INERTIA)
		# Dérapage : frein à main ou gaz en propulsion font pivoter la voiture.
		var kick := (1.0 if handbrake else 0.0) + power_oversteer * 0.6
		if kick > 0.0 and kmh > 15.0:
			apply_torque(up * (-steer) * drift_yaw_assist * minf(1.0, kick) * mass * YAW_INERTIA)
		# En travers : le volant pivote la voiture (garder ou ouvrir l'angle au doigt).
		if drifting > 0.0 and drift_steer > 0.0 and kmh > 15.0:
			apply_torque(up * (-steer) * drift_steer * drifting * mass * YAW_INERTIA)
		# Roulis : la caisse est ramenée vers la verticale, le roulis est amorti.
		# N'agit qu'au-delà de 14° de penché : en dessous, la caisse roule librement sur ses
		# suspensions (vraie prise de roulis dans les virages, sur les bosses).
		var tilt_axis := up.cross(Vector3.UP)
		var tilt := tilt_axis.length()
		var excess := 0.0
		if tilt > 0.001:
			excess = maxf(0.0, asin(minf(tilt, 1.0)) - deg_to_rad(14.0)) / asin(minf(tilt, 1.0))
		# Amortisseurs de caisse : le roulis et le tangage s'installent doucement, sans à-coup.
		var roll_rate := angular_velocity.dot(fwd)
		var pitch_rate := angular_velocity.dot(right)
		apply_torque((tilt_axis * excess * upright_assist * 4.0 - fwd * roll_rate * roll_damping - right * pitch_rate * pitch_damping) * mass * YAW_INERTIA)
		# Transfert de masse avant/arrière : la force d'accélération ou de freinage agit au
		# sol, sous le centre de gravité ; ce bras de levier fait cabrer ou plonger la caisse.
		# Les trains roulants d'une vraie voiture en reprennent une partie (anti-plongée,
		# anti-cabrage) : on applique le couple inverse, en part `anti_pitch`.
		var a_long := (forward_speed - _last_fwd) / delta
		_a_long_f = lerpf(_a_long_f, clampf(a_long, -15.0, 15.0), minf(1.0, delta / 0.1))
		var lever := up.cross(fwd) * com_height * mass * _a_long_f
		apply_torque(lever * anti_pitch)
		# Garde-fou : au-delà de l'angle maxi, on freine la rotation.
		var over := absf(slip_angle) - max_drift_deg
		if over > 0.0:
			var yaw_rate := angular_velocity.dot(up)
			if signf(yaw_rate) == -signf(slip_angle):
				apply_torque(-up * yaw_rate * minf(1.0, over / 12.0) * 12.0 * mass * YAW_INERTIA)

	_last_fwd = forward_speed
	_gearbox(delta, drive_in, grounded, handbrake)
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


## Régime et rapport d'après la vitesse : le rapport monte près de la zone rouge, descend
## quand le régime tombe ; le moteur s'emballe quand les roues patinent ou en l'air.
func _gearbox(delta: float, drive_in: float, grounded: int, handbrake: bool) -> void:
	shifted = false
	grounded_wheels = grounded
	engine_load = move_toward(engine_load, maxf(drive_in, 0.0) if drive_in >= 0.0 else -drive_in, delta * 6.0)
	var top := maxf(top_speed_kmh, 1.0)
	var kmh := absf(forward_speed) * 3.6
	if forward_speed < -0.5 and drive_in < 0.0:
		gear = 0
		rpm = lerpf(rpm, clampf(kmh / maxf(reverse_speed_kmh, 1.0), 0.0, 1.0) * 0.7 + 0.1 * engine_load, minf(1.0, delta * 8.0))
		return
	if gear == 0:
		gear = 1
	_shift_t = maxf(0.0, _shift_t - delta)
	var lo: float = GEAR_TOPS[gear - 2] * top * 0.62 if gear > 1 else 0.0
	var hi: float = GEAR_TOPS[gear - 1] * top
	var by_speed := clampf(kmh / hi, 0.0, 1.05)
	if _shift_t <= 0.0:
		if by_speed > 0.94 and gear < 5 and drive_in > 0.1:
			gear += 1
			_shift_t = 0.22
			shifted = true
		elif kmh < lo and gear > 1:
			gear -= 1
			_shift_t = 0.15
			shifted = true
	var target := clampf(kmh / (float(GEAR_TOPS[gear - 1]) * top), 0.0, 1.0)
	# Patinage (dérapage sous les gaz, frein à main) ou roues en l'air : le régime grimpe.
	var spin := clampf(absf(slip_angle) / 35.0, 0.0, 1.0) * engine_load
	if grounded == 0:
		spin = engine_load
	target = maxf(target, spin * 0.88)
	if handbrake and engine_load > 0.1:
		target = maxf(target, 0.75 * engine_load)
	# Limiteur : petite oscillation en zone rouge.
	if target > 0.97:
		target = 0.94 + 0.04 * sin(Time.get_ticks_msec() * 0.045)
	rpm = lerpf(rpm, target, minf(1.0, delta * (5.0 if target > rpm else 7.0)))


## Carrosserie fusionnée : toutes les pièces fixes (hors roues, déjà rattachées aux roues
## physiques) réunies en un seul maillage, une surface par matière : la voiture passe d'une
## quinzaine d'appels de dessin à quelques-uns. Matières gardées telles quelles.
static func _merge_body(car: VehicleBody3D) -> void:
	var root: Node3D = car.body_node
	var groups := {}
	var order: Array = []
	var parts := root.find_children("*", "MeshInstance3D", true, false)
	for m in parts:
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != root:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mi.mesh.surface_get_material(si)
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
				order.append(mat)
			(groups[mat] as SurfaceTool).append_from(mi.mesh, si, xf)
	if order.is_empty():
		return
	var mesh := ArrayMesh.new()
	for mat in order:
		(groups[mat] as SurfaceTool).commit(mesh)
	var merged := MeshInstance3D.new()
	merged.name = "Carrosserie"
	merged.mesh = mesh
	for i in order.size():
		merged.set_surface_override_material(i, order[i])
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	root.add_child(merged)


func respawn(pos: Vector3, yaw: float) -> void:
	_motion_ready = false
	_acc_f = Vector3.ZERO
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
