## Caméra « drone », comme une vidéo filmée au-dessus des dunes. Quatre plans (V ou bouton
## CAMÉRA) : drone haut presque vertical, poursuite, travelling latéral, vue plongeante.
## Mouvements amortis, léger balancement, recul avec la vitesse ; elle suit la direction
## réelle de la voiture (on voit venir le virage en dérapage), ne passe jamais sous le sol
## et tremble à la réception des sauts.
extends Camera3D

const WL = preload("res://scripts/core/world_layout.gd")

enum Mode { RALLY, DRONE, CHASE, SIDE, TOP }
const MODE_NAMES: Array[String] = ["Rallye", "Drone", "Poursuite", "Travelling", "Plongée"]

# Par plan : recul (m), recul à fond, hauteur, hauteur à fond, angle autour de la voiture (°), champ (°).
const SHOTS := {
	# Rallye (par défaut) : très haut, regard plongeant (~60°), la voiture dans le tiers bas
	# de l'écran et le virage suivant bien visible devant elle.
	Mode.RALLY: [8.0, 11.0, 15.0, 19.0, 0.0, 40.0],
	# Drone : haut et loin, presque à la verticale, comme une vidéo de drone.
	Mode.DRONE: [15.0, 19.0, 17.0, 21.0, -40.0, 50.0],
	Mode.CHASE: [10.0, 15.0, 4.6, 6.5, 22.0, 48.0],
	Mode.SIDE: [13.0, 16.0, 4.0, 5.0, 95.0, 45.0],
	Mode.TOP: [6.0, 10.0, 26.0, 32.0, 25.0, 50.0],
}

var target: VehicleBody3D
var world_data: RefCounted
var mode := Mode.RALLY
var speed_for_max := 140.0
var follow_time := 0.35
var yaw_sharpness := 2.0
var sway := 0.35

var _vel := Vector3.ZERO
var _yaw := 0.0
var _placed := false
var _shake := 0.0


func next_mode() -> void:
	mode = (mode + 1) % MODE_NAMES.size()


func snap() -> void:
	_placed = false
	_vel = Vector3.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, clampf(amount, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	# La voiture bouge au rythme de la physique : la caméra aussi, sans saccade.
	if target == null:
		return
	var shot: Array = SHOTS[mode]
	var t := target.global_transform
	var car_vel := target.linear_velocity
	var heading := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
	var flat := Vector3(car_vel.x, 0.0, car_vel.z)
	if flat.length() > 4.0 and target.forward_speed > 0.0:
		heading = heading.slerp(flat.normalized(), 0.6)
	var target_yaw := atan2(heading.x, heading.z)

	var k := clampf(target.speed_kmh / speed_for_max, 0.0, 1.0)
	var dist := lerpf(shot[0], shot[1], k)
	var height := lerpf(shot[2], shot[3], k)

	if not _placed:
		_yaw = target_yaw
		_placed = true
		global_position = _desired(t.origin, dist, height, shot[4])
		_vel = Vector3.ZERO
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * delta))

	var now := Time.get_ticks_msec() / 1000.0
	var desired := _desired(t.origin, dist, height, shot[4])
	desired += Vector3(sin(now * 0.37), sin(now * 0.53 + 1.0) * 0.6, sin(now * 0.29 + 2.0)) * sway
	var pos := _smooth_damp(global_position, desired, delta)
	var ground: float = world_data.height_at(pos.x, pos.z) if world_data else WL.height(pos.x, pos.z)
	pos.y = maxf(pos.y, maxf(ground, WL.SEA_LEVEL) + 2.5)
	if _shake > 0.001:
		var a := _shake * _shake * 0.6
		pos += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * a
		_shake = move_toward(_shake, 0.0, delta * 2.5)
	global_position = pos

	var ahead := 0.18
	if mode == Mode.TOP or mode == Mode.DRONE:
		ahead = 0.3
	elif mode == Mode.RALLY:
		# On regarde devant la voiture : plus loin quand elle va vite.
		ahead = 0.42
	var look := t.origin + Vector3.UP * 0.8 + flat * ahead
	if look.distance_to(pos) > 0.1:
		var want := global_transform.looking_at(look, Vector3.UP)
		global_basis = global_basis.slerp(want.basis, 1.0 - exp(-8.0 * delta)).orthonormalized()
	# Téléphone tenu droit : le champ est réglé en largeur (sinon la route sort de l'écran).
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	var want_fov: float = shot[5] + k * 6.0
	if portrait:
		want_fov += 6.0
	fov = lerpf(fov, want_fov, 1.0 - exp(-3.0 * delta))


func _desired(car: Vector3, dist: float, height: float, side_deg: float) -> Vector3:
	var yaw := _yaw + deg_to_rad(side_deg)
	# Derrière la voiture : à l'opposé de son avant (+Z local).
	return car + Vector3(-sin(yaw) * dist, height, -cos(yaw) * dist)


## Lissage critique (comme SmoothDamp) : rattrape la cible sans dépasser.
func _smooth_damp(cur: Vector3, goal: Vector3, delta: float) -> Vector3:
	var omega := 2.0 / follow_time
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - goal
	var temp := (_vel + omega * change) * delta
	_vel = (_vel - omega * temp) * e
	return goal + (change + temp) * e
