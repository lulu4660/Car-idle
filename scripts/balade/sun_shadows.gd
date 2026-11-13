## Ombres du décor qui suivent le soleil (et la lune) en continu.
## La carte graphique les calcule dans une image de 2048² qui couvre toute la carte
## (shaders/sun_shadow.gdshader, à partir des obstacles précalculés
## assets/balade/occluders.png) ; le terrain et l'herbe la lisent comme avant
## (static_shadow_tex). Pour ne rien coûter, l'image est refaite par morceaux de 64 m, un
## par image : deux fois sur trois autour de la voiture (les 9 voisins se relaient : chacun
## refait environ 5 fois par seconde), sinon ailleurs sur la carte (toute la carte en une
## dizaine de secondes, hors de vue). Le soleil avance d'un quart de degré par seconde : les morceaux
## refaits l'un après l'autre ne se voient pas. Quand l'heure saute, tout est refait d'un
## coup.
extends Node

const WL = preload("res://scripts/core/world_layout.gd")

const RES := 2048
const TILE := 128
const TILES := RES / TILE
const TEXEL := WL.SIZE / RES
## Portée maximale d'une ombre (soleil bas) et pas du calcul.
const MAX_REACH := 60.0
const STEP := 0.5
const MAX_TOP := 25.5

var _vp: SubViewport
var _rects: Array[ColorRect] = []
var _full: ColorRect
var _mat: ShaderMaterial
var _cycle := 0
var _near := 0
var _turn := 0
var _dir := Vector3.ZERO
## Morceaux refaits depuis le dernier changement de direction (arrêt quand tout est à jour).
var _clean := 0


func build() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(RES, RES)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sun_shadow.gdshader")
	_mat.set_shader_parameter("occ_tex", load("res://assets/balade/occluders.png"))
	_mat.set_shader_parameter("map_px", float(RES))
	_mat.set_shader_parameter("texel", TEXEL)
	_mat.set_shader_parameter("step_len", STEP)
	for i in 10:
		var r := ColorRect.new()
		r.size = Vector2(TILE, TILE)
		r.material = _mat
		r.visible = false
		_vp.add_child(r)
		_rects.append(r)
	_full = ColorRect.new()
	_full.size = Vector2(RES, RES)
	_full.material = _mat
	_full.visible = false
	_vp.add_child(_full)
	add_child(_vp)


func texture() -> Texture2D:
	return _vp.get_texture()


## `light` : direction vers l'astre qui éclaire ; `focus` : la voiture ; `full` : tout
## refaire (l'heure a sauté) ; `fast` : l'heure défile vite (bouton NUIT/JOUR).
func update(light: Vector3, focus: Vector3, full: bool, fast: bool) -> void:
	if light.distance_squared_to(_dir) > 1e-9:
		_dir = light
		_clean = 0
		_set_light(light)
	elif not full and _clean >= TILES * TILES:
		return
	for r in _rects:
		r.visible = false
	_full.visible = full
	if not full:
		var ft := Vector2i(clampi(int((focus.x + WL.SIZE / 2.0) / TEXEL) / TILE, 0, TILES - 1), clampi(int((focus.z + WL.SIZE / 2.0) / TEXEL) / TILE, 0, TILES - 1))
		if fast:
			# L'heure défile : les 9 morceaux autour de la voiture à chaque image.
			for j in 9:
				_place(j, ft + Vector2i(j % 3 - 1, j / 3 - 1))
		else:
			# Un seul morceau par image : deux fois sur trois autour de la voiture.
			_turn = (_turn + 1) % 3
			if _turn < 2:
				_place(0, ft + Vector2i(_near % 3 - 1, _near / 3 - 1))
				_near = (_near + 1) % 9
			else:
				_place(0, Vector2i(_cycle % TILES, _cycle / TILES))
				_cycle = (_cycle + 1) % (TILES * TILES)
				_clean += 1
	else:
		_clean = TILES * TILES
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _place(k: int, t: Vector2i) -> void:
	if t.x < 0 or t.y < 0 or t.x >= TILES or t.y >= TILES:
		return
	_rects[k].position = Vector2(t * TILE)
	_rects[k].visible = true


func _set_light(light: Vector3) -> void:
	var flat := Vector2(light.x, light.z)
	var l := flat.length()
	var rise := maxf(light.y, 0.02) / maxf(l, 1e-4)
	var reach := minf(MAX_TOP / rise, MAX_REACH)
	_mat.set_shader_parameter("sun_xz", flat / maxf(l, 1e-4))
	_mat.set_shader_parameter("rise", rise)
	_mat.set_shader_parameter("steps", maxi(1, int(ceil(reach / STEP))))
