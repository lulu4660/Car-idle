## Houle de la mer, partagée par l'image (shaders/sea.gdshader) et la physique (flottaison
## de la voiture, objets qui flottent) : mêmes vagues, même horloge.
extends RefCounted

const WL = preload("res://scripts/core/world_layout.gd")

const WAVE_HEIGHT := 0.25
const DIRS: Array[Vector2] = [Vector2(-1, 0.15), Vector2(-0.8, -0.55), Vector2(-0.95, 0.35), Vector2(-0.4, 0.9)]
const LENS: Array[float] = [38.0, 21.0, 11.0, 6.5]
const AMPS: Array[float] = [1.0, 0.5, 0.25, 0.12]


## Horloge commune (secondes depuis le lancement).
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Hauteur de la surface de l'eau au point (x, z) ; `depth` = profondeur d'eau au repos.
## Près du bord la surface reste plane (comme dans le shader).
static func surface(x: float, z: float, depth: float) -> float:
	var h := 0.0
	var t := now()
	for i in 4:
		var d := DIRS[i].normalized()
		var k := TAU / LENS[i]
		var c := sqrt(9.8 / k)
		h += AMPS[i] * WAVE_HEIGHT * sin(k * (d.x * x + d.y * z - c * t))
	return WL.SEA_LEVEL + h * smoothstep(3.0, 7.0, depth)
