## Sons de la balade (tous synthétisés par tools/make_audio.py, assets/audio) :
## - moteur : deux boucles (grave, aiguë) fondues selon le régime de la boîte simulée de
##   car.gd, plus fortes et plus claires sous les gaz ; « clac » au changement de rapport ;
## - pneus : crissement sur le bitume selon la glisse, roulage et cailloux sur terre et sable ;
## - vent selon la vitesse, remous dans l'eau, gerbe à l'entrée, coup sourd aux chocs et aux
##   réceptions de saut ;
## - ambiance : ressac près de la mer, grillons la nuit.
## Lecteurs non spatialisés (la caméra suit toujours la voiture) : léger sur iPhone et web.
extends Node

const WL = preload("res://scripts/core/world_layout.gd")
const DIR := "res://assets/audio/"

var game: Node
var _loops := {}
var _shots := {}
var _vol := {}          # volume lissé (linéaire) de chaque boucle
var _was_in_water := false
var _last_speed := 0.0
var _impact_cool := 0.0


func _ready() -> void:
	for n in ["engine_low", "engine_high", "skid", "gravel", "wind", "sea", "water", "crickets"]:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + n + ".wav")
		p.volume_db = -80.0
		add_child(p)
		p.play()
		_loops[n] = p
		_vol[n] = 0.0
	for n in ["impact", "land", "splash", "shift", "click", "score"]:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + n + ".wav")
		add_child(p)
		_shots[n] = p


## Joue un son court (volume 0 à 1, hauteur relative).
func shot(n: String, volume := 1.0, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _shots.get(n)
	if p == null or volume <= 0.01:
		return
	p.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
	p.pitch_scale = pitch
	p.play()


func _loop(n: String, target: float, delta: float, pitch := -1.0, speed := 8.0) -> void:
	var v: float = lerpf(_vol[n], clampf(target, 0.0, 1.0), minf(1.0, delta * speed))
	_vol[n] = v
	var p: AudioStreamPlayer = _loops[n]
	p.volume_db = linear_to_db(maxf(v, 0.0001))
	if pitch > 0.0:
		p.pitch_scale = clampf(pitch, 0.3, 3.0)


func _process(delta: float) -> void:
	var car: VehicleBody3D = game.car if game else null
	if car == null or not is_instance_valid(car):
		return
	var kmh: float = car.speed_kmh
	var sunk: float = car.submerged
	# Moteur : régime réel en tr/min (ralenti 900, zone rouge 7 200) ; les boucles ont été
	# synthétisées à 1 500 et 4 980 tr/min. Noyé : le moteur s'étouffe.
	var r: float = lerpf(900.0, 7200.0, car.rpm)
	var load: float = car.engine_load
	var mix := smoothstep(1800.0, 4600.0, r)
	var alive := 1.0 - clampf(sunk * 1.4 - 0.4, 0.0, 1.0)
	var gain := lerpf(0.42, 0.9, load) * alive
	_loop("engine_low", gain * (1.0 - mix), delta, minf(r / 1500.0, 2.4), 14.0)
	_loop("engine_high", gain * mix * lerpf(0.55, 1.0, load), delta, r / 4980.0, 14.0)
	if car.shifted:
		shot("shift", 0.5, randf_range(0.9, 1.1))

	# Pneus : glisse moyenne des roues au sol, bitume ou sol meuble.
	var slip := 0.0
	var soft := 0.0
	var contact := 0
	for i in 4:
		if (car.wheels[i] as VehicleWheel3D).is_in_contact():
			contact += 1
			slip += car.wheel_slip[i]
			soft += 1.0 if WL.is_soft(car.wheel_surface[i]) else 0.0
	if contact > 0:
		slip /= contact
		soft /= contact
	var sliding := clampf((absf(car.slip_angle) - 7.0) / 22.0, 0.0, 1.0) * clampf(kmh / 30.0, 0.0, 1.0)
	sliding = maxf(sliding, clampf((slip - 0.25) * 1.6, 0.0, 1.0) * clampf(kmh / 15.0, 0.2, 1.0))
	var on_ground := 1.0 if contact > 0 and not car.in_water else 0.0
	_loop("skid", sliding * (1.0 - soft) * on_ground * 0.7, delta, 0.85 + 0.25 * clampf(kmh / 120.0, 0.0, 1.0) + 0.1 * sliding, 10.0)
	var roll := clampf(kmh / 70.0, 0.0, 1.0) * 0.45 + sliding * 0.55
	_loop("gravel", roll * soft * on_ground * 0.8, delta, 0.7 + 0.6 * clampf(kmh / 110.0, 0.0, 1.0), 10.0)
	_loop("wind", pow(clampf(kmh / 170.0, 0.0, 1.0), 1.6) * 0.75, delta, 0.8 + 0.5 * clampf(kmh / 170.0, 0.0, 1.0), 4.0)

	# Eau.
	_loop("water", (clampf(kmh / 25.0, 0.15, 1.0) if car.in_water else 0.0) * 0.6, delta, 0.9 + 0.3 * clampf(kmh / 40.0, 0.0, 1.0), 5.0)
	if car.in_water and not _was_in_water and kmh > 8.0:
		shot("splash", clampf(kmh / 50.0, 0.3, 1.0), randf_range(0.9, 1.1))
	_was_in_water = car.in_water

	# Choc : la vitesse tombe bien plus vite qu'au freinage.
	_impact_cool = maxf(0.0, _impact_cool - delta)
	var drop := _last_speed - kmh
	if delta > 0.0 and drop / delta > 90.0 and drop > 4.0 and _impact_cool <= 0.0:
		shot("impact", clampf(drop / 25.0, 0.3, 1.0), randf_range(0.85, 1.15))
		_impact_cool = 0.25
	_last_speed = kmh

	# Ambiance : la mer s'entend depuis la plage ; les grillons la nuit, hors de l'eau.
	var p := car.global_position
	var shore: float = WL.BEACH_END + WL.shore_offset(p.z)
	var near_sea := 1.0 - clampf((shore - p.x) / 140.0, 0.0, 1.0)
	_loop("sea", near_sea * 0.55, delta, 1.0, 1.5)
	var night: float = game.lighting.glow if game.lighting else 0.0
	_loop("crickets", night * (1.0 - near_sea * 0.7) * 0.3, delta, 1.0, 1.0)


## Réception de saut (0 à 1).
func land(k: float) -> void:
	shot("land", lerpf(0.35, 1.0, k), lerpf(1.15, 0.85, k))
