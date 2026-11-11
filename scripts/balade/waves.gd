## Houle de la mer, partagée par l'image (shaders/sea.gdshader) et la physique (flottaison
## de la voiture, objets qui flottent) : mêmes vagues, même horloge.
extends RefCounted

const WL = preload("res://scripts/core/world_layout.gd")

const WAVE_HEIGHT := 0.25
const DIRS: Array[Vector2] = [Vector2(-1, 0.15), Vector2(-0.8, -0.55), Vector2(-0.95, 0.35), Vector2(-0.4, 0.9)]
const LENS: Array[float] = [38.0, 21.0, 11.0, 6.5]
const AMPS: Array[float] = [1.0, 0.5, 0.25, 0.12]


## Horloge commune : le temps de la physique (secondes), pour que l'image et la flottaison
## restent d'accord même quand l'affichage ralentit.
static func now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second


## Hauteur de la surface de l'eau au point (x, z) ; `depth` = profondeur d'eau au repos.
## Près du bord la surface reste plane (comme dans le shader).
static func surface(x: float, z: float, depth: float) -> float:
	var h := 0.0
	var t := now()
	# Les deux grandes vagues, celles qui ont du relief à l'image.
	for i in 2:
		var d := DIRS[i].normalized()
		var k := TAU / LENS[i]
		var c := sqrt(9.8 / k)
		h += AMPS[i] * WAVE_HEIGHT * sin(k * (d.x * x + d.y * z - c * t))
	return WL.SEA_LEVEL + h * smoothstep(3.0, 7.0, depth)


## Vitesse de l'eau au point (x, z) : mouvement orbital des deux grandes vagues (la voiture
## qui flotte est soulevée et poussée d'avant en arrière par chaque vague) et une légère
## dérive vers la plage (le ressac ramène ce qui flotte).
static func velocity(x: float, z: float, depth: float) -> Vector3:
	var v := Vector3.ZERO
	var t := now()
	var k_depth := smoothstep(3.0, 7.0, depth)
	for i in 2:
		var d := DIRS[i].normalized()
		var k := TAU / LENS[i]
		var c := sqrt(9.8 / k)
		var a := AMPS[i] * WAVE_HEIGHT * k * c * k_depth
		var ph := k * (d.x * x + d.y * z - c * t)
		v += Vector3(d.x, 0.0, d.y) * a * sin(ph) + Vector3.UP * (-a * cos(ph))
	return v + Vector3(-0.35, 0.0, 0.03) * clampf(depth / 2.0, 0.2, 1.0)
