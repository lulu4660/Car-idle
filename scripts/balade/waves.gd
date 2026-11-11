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
	for i in 4:
		var d := DIRS[i].normalized()
		var k := TAU / LENS[i]
		var c := sqrt(9.8 / k)
		h += AMPS[i] * WAVE_HEIGHT * sin(k * (d.x * x + d.y * z - c * t))
	return WL.SEA_LEVEL + h * smoothstep(3.0, 7.0, depth) + wake_height(x, z) * clampf(depth / 0.3, 0.0, 1.0)


# --- Sillage : vagues créées par la voiture ---------------------------------------------
# Chaque source est une onde circulaire (un paquet de rides) qui part d'un point et s'élargit
# à la vitesse WAKE_SPEED en s'amortissant. Une voiture qui avance plus vite que les rides
# laisse derrière elle un sillage en V ; un plongeon fait des cercles. L'image (sea.gdshader)
# et la flottaison lisent les mêmes sources.
const WAKE_COUNT := 32
const WAKE_SPEED := 3.2          # m/s
const WAKE_LEN := 2.4            # longueur d'onde (m)
const WAKE_WIDTH := 2.2          # épaisseur du paquet (m)
const WAKE_DECAY := 0.55         # amortissement (1/s)
const WAKE_LIFE := 6.0

static var _wakes := PackedVector4Array()
static var _wake_next := 0


## Nouvelle onde en (x, z), d'amplitude `amp` (m).
static func emit(x: float, z: float, amp: float) -> void:
	if _wakes.size() != WAKE_COUNT:
		_wakes.resize(WAKE_COUNT)
		_wakes.fill(Vector4(0, 0, -100, 0))
	_wakes[_wake_next] = Vector4(x, z, now(), amp)
	_wake_next = (_wake_next + 1) % WAKE_COUNT


## Une onde du sillage est-elle encore visible ?
static func active() -> bool:
	var t := now()
	for w in _wakes:
		if t - w.z < WAKE_LIFE:
			return true
	return false


## Sources pour le shader (x, z, départ, amplitude).
static func wakes() -> PackedVector4Array:
	if _wakes.size() != WAKE_COUNT:
		_wakes.resize(WAKE_COUNT)
		_wakes.fill(Vector4(0, 0, -100, 0))
	return _wakes


## Hauteur du sillage en (x, z) (même formule que le shader).
static func wake_height(x: float, z: float) -> float:
	var t := now()
	var k := TAU / WAKE_LEN
	var h := 0.0
	for w in _wakes:
		var age := t - w.z
		if age <= 0.0 or age > WAKE_LIFE:
			continue
		var r := Vector2(x - w.x, z - w.y).length()
		var u := (r - WAKE_SPEED * age) / WAKE_WIDTH
		if absf(u) > 2.5:
			continue
		h += w.w * exp(-age * WAKE_DECAY) * exp(-u * u) * cos(k * (r - WAKE_SPEED * age)) / sqrt(1.0 + r * 0.4)
	return h
