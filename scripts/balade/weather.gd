## Météo de la balade : temps clair, nuageux, pluie, orage, brouillard.
## - Chaque temps a ses cibles (nuages, pluie, vent, brouillard) ; les valeurs y glissent
##   doucement (une vingtaine de secondes), jamais d'un coup.
## - Le sol se mouille sous la pluie et sèche lentement après (plus vite au soleil) ; les
##   flaques suivent avec retard.
## - Mode automatique : le temps change seul toutes les 3 à 6 minutes ; sinon, choisi dans
##   les réglages.
## Les valeurs sont données aux shaders par des paramètres globaux (project.godot,
## [shader_globals]) : weather_wet, weather_puddle, weather_rain, weather_clouds,
## weather_wind (direction x, z et force), cloud_offset (nuages qui défilent).
## La lumière, le ciel et la brume suivent via lighting.gd ; les sons via audio.gd.
extends Node

enum Kind { AUTO, CLEAR, CLOUDY, RAIN, STORM, FOG }
const NAMES: Array[String] = ["Auto", "Clair", "Nuageux", "Pluie", "Orage", "Brouillard"]
## Par temps : nuages, pluie, vent, brouillard en plus.
const TARGETS := {
	Kind.CLEAR: [0.08, 0.0, 0.2, 0.0],
	Kind.CLOUDY: [0.7, 0.0, 0.45, 0.2],
	Kind.RAIN: [0.85, 0.7, 0.5, 0.3],
	Kind.STORM: [1.0, 1.0, 0.95, 0.45],
	Kind.FOG: [0.45, 0.0, 0.05, 1.0],
}
## Tirage du mode automatique (poids).
const AUTO_WEIGHTS := {Kind.CLEAR: 40.0, Kind.CLOUDY: 25.0, Kind.RAIN: 15.0, Kind.STORM: 8.0, Kind.FOG: 12.0}

var mode := Kind.AUTO
var current := Kind.CLEAR
var clouds := 0.08
var rain := 0.0
var wind := 0.2
var fog := 0.0
## Sol mouillé (0 à 1) et flaques (0 à 1, suivent le sol avec retard).
var wet := 0.0
var puddle := 0.0
## Direction du vent (radians) : tourne lentement.
var wind_angle := 0.6
var cloud_offset := Vector2.ZERO
## Éclair : 1 au moment de l'éclair, retombe ; signal pour la lumière et le tonnerre.
var flash := 0.0
signal lightning(distance_s: float)

var _auto_timer := 240.0
var _bolt_timer := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_apply_globals()


## Choix du temps (réglages) ; AUTO laisse la météo changer seule.
func set_mode(k: int) -> void:
	mode = k
	if mode != Kind.AUTO:
		current = mode


func name_now() -> String:
	return NAMES[current]


func _process(delta: float) -> void:
	if mode == Kind.AUTO:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = _rng.randf_range(180.0, 360.0)
			current = _pick()
	var t: Array = TARGETS[current]
	var k := minf(1.0, delta / 20.0)
	clouds = lerpf(clouds, t[0], k)
	rain = lerpf(rain, t[1], minf(1.0, delta / 12.0))
	wind = lerpf(wind, t[2], k)
	fog = lerpf(fog, t[3], k)
	# Le sol se mouille vite sous la pluie, sèche lentement (plus vite sans nuages).
	if rain > 0.15:
		wet = minf(1.0, wet + delta * rain / 35.0)
	else:
		wet = maxf(0.0, wet - delta / lerpf(90.0, 240.0, clouds))
	puddle = lerpf(puddle, smoothstep(0.35, 1.0, wet), minf(1.0, delta / 25.0))
	wind_angle += delta * 0.01 * sin(Time.get_ticks_msec() * 0.00005)
	var wdir := Vector2(cos(wind_angle), sin(wind_angle))
	cloud_offset += wdir * (2.0 + wind * 10.0) * delta
	# Orage : éclairs de temps en temps.
	flash = maxf(0.0, flash - delta * 3.0)
	if rain > 0.85 and clouds > 0.9:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = _rng.randf_range(6.0, 18.0)
			flash = 1.0
			lightning.emit(_rng.randf_range(0.4, 3.0))
	_apply_globals()


func _pick() -> int:
	var total := 0.0
	for k in AUTO_WEIGHTS:
		if k != current:
			total += AUTO_WEIGHTS[k]
	var r := _rng.randf() * total
	for k in AUTO_WEIGHTS:
		if k == current:
			continue
		r -= AUTO_WEIGHTS[k]
		if r <= 0.0:
			return k
	return Kind.CLEAR


func wind_vector() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle)) * wind


func _apply_globals() -> void:
	RenderingServer.global_shader_parameter_set("weather_wet", wet)
	RenderingServer.global_shader_parameter_set("weather_puddle", puddle)
	RenderingServer.global_shader_parameter_set("weather_rain", rain)
	RenderingServer.global_shader_parameter_set("weather_clouds", clouds)
	var w := wind_vector()
	RenderingServer.global_shader_parameter_set("weather_wind", Vector3(w.x, w.y, wind))
	RenderingServer.global_shader_parameter_set("cloud_offset", cloud_offset)
