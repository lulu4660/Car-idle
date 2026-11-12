## Plan du monde de la balade : une vallée ouverte sur la mer. D'ouest en est : ville au pied
## des montagnes, banlieue, prairies et fermes, forêt sur les collines, garrigue sèche,
## dunes, plage, mer. Des montagnes ferment la vallée à l'ouest, au nord et au sud (roche,
## neige au sommet) et descendent en caps rocheux dans la mer à l'est. Coordonnées en mètres, x vers l'est, z vers le SUD (repère Godot :
## le nord est vers -z), origine au centre ; hauteur absolue.
## Fonctions pures et déterministes : le même relief sert au terrain précalculé
## (tools/bake_world.gd), à la caméra, au replacement de la voiture et aux tests.
extends RefCounted

enum Surface { ASPHALT, DIRT, SAND, WET_SAND, WATER }

## Côté du monde carré, en mètres.
const SIZE := 1024.0
## Hauteur maximale que peut prendre le relief.
const MAX_HEIGHT := 110.0
const SEA_LEVEL := 10.0
## Hauteur du sol de la ville (et de la base des autres zones).
const GROUND_LEVEL := 13.0

# Limites des zones le long de x (la plage ondule un peu le long de z).
const CITY_END := -180.0
## La ville commence au pied des montagnes de l'ouest et reste dans la vallée.
const CITY_START := -420.0
const VALLEY_HALF := 420.0
## Largeur de la chaîne de montagnes sur les bords (m).
const MOUNTAIN_WIDTH := 80.0
const DIRT_END := 110.0
const DUNES_END := 330.0
const BEACH_END := 395.0

# Rues de la ville : un pâté de maisons tous les 60 m, rues de 16 m.
const BLOCK_SIZE := 60.0
const STREET_WIDTH := 16.0

## Départ de la voiture : au pied des dunes, au bord de la plage (la mer à l'est).
const SPAWN_X := 360.0
const SPAWN_Z := 0.0

const SURFACE_NAMES: Array[String] = ["Bitume", "Terre", "Sable", "Sable mouillé", "Eau"]

## Spéciale de rallye : une piste de terre en boucle (points de passage, lissés en courbe),
## du départ sur la plage, à travers les dunes, la forêt, et retour. Demi-largeur (m).
const ROAD_HALF := 5.0
const ROAD_POINTS: Array[Vector2] = [
	Vector2(360, 0), Vector2(362, -140), Vector2(310, -290), Vector2(215, -385),
	Vector2(120, -320), Vector2(40, -360), Vector2(-60, -300), Vector2(-125, -170),
	Vector2(-70, -50), Vector2(15, 50), Vector2(-50, 190), Vector2(-125, 320),
	Vector2(-10, 415), Vector2(140, 385), Vector2(225, 270), Vector2(170, 140),
	Vector2(255, 70), Vector2(335, 110)]


## La piste en ligne brisée (un point tous les ~3 m), boucle fermée (Catmull-Rom).
static func road_polyline() -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ROAD_POINTS.size()
	for i in n:
		var p0 := ROAD_POINTS[(i - 1 + n) % n]
		var p1 := ROAD_POINTS[i]
		var p2 := ROAD_POINTS[(i + 1) % n]
		var p3 := ROAD_POINTS[(i + 2) % n]
		var steps := maxi(4, int(p1.distance_to(p2) / 3.0))
		for k in steps:
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


static func height(x: float, z: float) -> float:
	var city := GROUND_LEVEL
	# Terre : collines douces (±4 m).
	var dirt := GROUND_LEVEL + 8.0 * (fbm(x / 110.0 + 3.1, z / 110.0 - 7.3) - 0.5)
	var dunes := dune_height(x, z)

	var h := lerpf(city, dirt, smooth(CITY_END - 25.0, CITY_END + 25.0, x))
	h = lerpf(h, dunes, smooth(DIRT_END - 45.0, DIRT_END + 45.0, x))

	# Plage puis fond marin : la côte ondule le long de z.
	var coast := shore_offset(z)
	var shore_start := DUNES_END - 20.0 + coast
	var beach_end := BEACH_END + coast
	var shore := GROUND_LEVEL - (x - shore_start) * (GROUND_LEVEL - (SEA_LEVEL - 0.4)) / (beach_end - shore_start)
	if x > beach_end:
		shore = SEA_LEVEL - 0.4 - (x - beach_end) * 0.06
	h = lerpf(h, shore, smooth(shore_start - 10.0, shore_start + 25.0, x))
	# Montagnes qui ferment la vallée (et caps rocheux dans la mer).
	h += mountain_height(x, z)
	return clampf(h, 0.5, MAX_HEIGHT - 0.5)


## 0 dans la vallée, 1 au cœur de la chaîne de montagnes (bords ouest, nord et sud). Le pied
## des montagnes ondule ; vers l'est, la chaîne s'abaisse et finit en caps dans la mer.
static func mountain_factor(x: float, z: float) -> float:
	var half := SIZE / 2.0
	var d := minf(half - absf(z), x + half)
	d += 20.0 * (fbm(x / 90.0 + 31.0, z / 90.0 - 17.0) - 0.5)
	var m := 1.0 - smooth(6.0, MOUNTAIN_WIDTH, d)
	m *= 1.0 - smooth(BEACH_END - 40.0, BEACH_END + 95.0, x)
	return m


## Au-delà des bords de la carte (décor lointain) : la chaîne continue et monte encore,
## et s'enfonce dans la mer à l'est comme dans la carte.
static func far_height(x: float, z: float) -> float:
	var half := SIZE / 2.0
	var out := maxf(maxf(absf(z) - half, -x - half), 0.0)
	var m := 1.0 - smooth(BEACH_END - 40.0, BEACH_END + 95.0, x)
	if m <= 0.001:
		return 0.0
	var ridge := 1.0 - absf(2.0 * fbm(x / 60.0 + 13.0, z / 60.0 - 21.0) - 1.0)
	var peaks := 0.55 * fbm(x / 170.0 - 4.0, z / 170.0 + 8.0) + 0.45 * ridge
	var h := GROUND_LEVEL + pow(m, 1.45) * (34.0 + 58.0 * peaks)
	h += m * minf(out * 0.25, 70.0) * (0.6 + 0.8 * fbm(x / 240.0, z / 240.0))
	return h


static func mountain_height(x: float, z: float) -> float:
	var m := mountain_factor(x, z)
	if m <= 0.0:
		return 0.0
	# Crêtes (bruit « en arête ») et sommets plus hauts par endroits.
	var ridge := 1.0 - absf(2.0 * fbm(x / 60.0 + 13.0, z / 60.0 - 21.0) - 1.0)
	var peaks := 0.55 * fbm(x / 170.0 - 4.0, z / 170.0 + 8.0) + 0.45 * ridge
	return pow(m, 1.45) * (34.0 + 58.0 * peaks)


## Dunes du désert : crêtes perpendiculaires au vent (qui vient de l'ouest), pente douce
## et bombée face au vent, crête vive, versant abrupt (≈ 30°) sous le vent, creux arrondis.
## Les crêtes ondulent et leur hauteur varie (6 à 13 m).
static func dune_height(x: float, z: float) -> float:
	const WAVELENGTH := 105.0
	const WINDWARD := 0.68
	var warp := 0.55 * sin(z * 0.011 + 0.8) + 0.9 * (fbm(x / 160.0 + 4.0, z / 90.0) - 0.5)
	var u := x / WAVELENGTH + warp
	var p := u - floorf(u)
	var profile: float
	if p < WINDWARD:
		var t := p / WINDWARD
		profile = 1.0 - (1.0 - t) * (1.0 - t)
	else:
		var t := (p - WINDWARD) / (1.0 - WINDWARD)
		profile = pow(1.0 - t, 1.35)
	var amplitude := 6.0 + 7.0 * fbm(x / 230.0 - 2.0, z / 150.0 + 6.0)
	var small := 1.2 * pow(absf(sin((x * 0.6 + z * 0.8) * 0.045 + 3.0 * fbm(x / 50.0, z / 50.0))), 2.0)
	return GROUND_LEVEL + amplitude * profile + small + 1.5 * (fbm(x / 45.0 + 11.0, z / 45.0) - 0.5)


## Décalage de la côte vers l'est ou l'ouest selon z (±15 m).
static func shore_offset(z: float) -> float:
	return 15.0 * sin(z * 0.01) + 6.0 * sin(z * 0.031 + 1.3)


static func surface_at(x: float, z: float, h: float) -> int:
	if h < SEA_LEVEL - 0.05:
		return Surface.WATER
	if x > DUNES_END + shore_offset(z) and h < SEA_LEVEL + 0.7:
		return Surface.WET_SAND
	# Montagnes : terre et roche (la couleur de la roche et de la neige vient du shader).
	if mountain_factor(x, z) > 0.04:
		return Surface.DIRT
	# Frontières un peu irrégulières entre les zones.
	var jitter := 20.0 * (fbm(x / 35.0 + 5.0, z / 35.0 + 9.0) - 0.5)
	if x < CITY_END + jitter * 0.3:
		return Surface.ASPHALT
	if x < DIRT_END + jitter:
		return Surface.DIRT
	return Surface.SAND


## Adhérence relative du sol (1 = bitume sec).
static func grip(s: int) -> float:
	match s:
		Surface.ASPHALT: return 1.0
		Surface.DIRT: return 0.8
		Surface.WET_SAND: return 0.7
		Surface.SAND: return 0.6
	return 0.35


## Le sol garde-t-il des traces et soulève-t-il de la poussière sans dérapage ?
static func is_soft(s: int) -> bool:
	return s == Surface.DIRT or s == Surface.SAND or s == Surface.WET_SAND


## Ce point de la ville est-il une rue (et non un pâté de maisons) ?
static func is_street(x: float, z: float) -> bool:
	return fposmod(x, BLOCK_SIZE) < STREET_WIDTH or fposmod(z, BLOCK_SIZE) < STREET_WIDTH


# --- Bruit déterministe (identique à la version C# et au serveur) -------------------

## Bruit fractal dans [0, 1], lisse.
static func fbm(x: float, y: float) -> float:
	return 0.55 * _value_noise(x, y) + 0.3 * _value_noise(x * 2.03 + 17.0, y * 2.03 - 5.0) + 0.15 * _value_noise(x * 4.1 - 3.0, y * 4.1 + 11.0)


static func _value_noise(x: float, y: float) -> float:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(xi, yi)
	var b := _hash(xi + 1, yi)
	var c := _hash(xi, yi + 1)
	var d := _hash(xi + 1, yi + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _hash(x: int, y: int) -> float:
	var h := ((x & 0xFFFFFFFF) * 374761393 + (y & 0xFFFFFFFF) * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFFFF) / 16777215.0


static func smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
