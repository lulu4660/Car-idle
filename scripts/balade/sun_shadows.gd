## Ombres du décor qui suivent le soleil (et la lune) en continu.
## La carte graphique les calcule (shaders/sun_shadow.gdshader, à partir des obstacles
## précalculés assets/balade/occluders.png) dans une fenêtre de 256 m autour de la voiture
## (512², 50 cm par pixel) ; le terrain et l'herbe la lisent (static_shadow_tex, zone
## donnée par le paramètre global shadow_rect ; au-delà, les ombres s'effacent).
## Deux images se relaient : pendant qu'on regarde l'une, l'autre est refaite par
## morceaux de 64 m (un par image, toute la fenêtre en 16 images), centrée sur la voiture
## et un peu devant elle, pour la position de l'astre du moment ; puis elles s'échangent.
## Petites images : sur iPhone, la carte graphique recharge toute l'image qu'on retouche,
## même pour un petit morceau (une image de toute la carte, 16 Mo, faisait saccader).
## Quand l'heure saute, toute la fenêtre est refaite d'un coup.
extends Node

const WL = preload("res://scripts/core/world_layout.gd")

const RES := 2048                    # carte des obstacles (toute la carte)
const TEXEL := WL.SIZE / RES         # 0,5 m
const WIN := 512                     # fenêtre calculée (256 m)
const TILE := 128
const TILES := WIN / TILE            # 4 × 4 morceaux
## Portée maximale d'une ombre (soleil bas) et pas du calcul.
const MAX_REACH := 60.0
const STEP := 0.5
const MAX_TOP := 25.5

## Matériaux qui lisent les ombres (terrain, ornières, herbe).
var materials: Array = []
var _vp: Array[SubViewport] = []
var _rects: Array = []
var _fulls: Array = []
var _mat: ShaderMaterial
var _front := 0
var _tile := -1                      # morceau en cours de la passe (-1 : aucune passe)
var _origin := Vector2i.ZERO         # coin de la fenêtre en cours de calcul (pixels de la carte)
var _shown_origin := Vector2i(-100000, 0)
var _shown_dir := Vector3.ZERO
var _pass_dir := Vector3.ZERO


func build() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sun_shadow.gdshader")
	_mat.set_shader_parameter("occ_tex", load("res://assets/balade/occluders.png"))
	_mat.set_shader_parameter("map_px", float(RES))
	_mat.set_shader_parameter("texel", TEXEL)
	_mat.set_shader_parameter("step_len", STEP)
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(WIN, WIN)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rs: Array[ColorRect] = []
		for k in 4:
			var r := ColorRect.new()
			r.size = Vector2(TILE, TILE)
			r.material = _mat
			r.visible = false
			vp.add_child(r)
			rs.append(r)
		var full := ColorRect.new()
		full.size = Vector2(WIN, WIN)
		full.material = _mat
		full.visible = false
		vp.add_child(full)
		add_child(vp)
		_vp.append(vp)
		_rects.append(rs)
		_fulls.append(full)


func texture() -> Texture2D:
	return _vp[_front].get_texture()


## `light` : direction vers l'astre qui éclaire ; `focus` : où centrer (la voiture, un peu
## devant) ; `full` : tout refaire d'un coup (l'heure a sauté) ; `fast` : l'heure défile
## vite (bouton NUIT/JOUR), 4 morceaux par image.
func update(light: Vector3, focus: Vector3, full: bool, fast: bool) -> void:
	var back := 1 - _front
	for r in _rects[back]:
		(r as ColorRect).visible = false
	(_fulls[back] as ColorRect).visible = false
	if full:
		_start_pass(light, focus)
		(_fulls[back] as ColorRect).visible = true
		_vp[back].render_target_update_mode = SubViewport.UPDATE_ONCE
		_swap()
		return
	if _tile < 0:
		# Rien à refaire si l'astre n'a pas bougé et que la voiture reste au milieu.
		var c := Vector2(focus.x, focus.z) - _rect_center(_shown_origin)
		if light.distance_squared_to(_shown_dir) < 1e-10 and maxf(absf(c.x), absf(c.y)) < WIN * TEXEL * 0.2:
			return
		_start_pass(light, focus)
	var count := 4 if fast else 1
	for k in count:
		var t := _tile
		var r := _rects[back][k] as ColorRect
		r.position = Vector2((t % TILES) * TILE, (t / TILES) * TILE)
		r.visible = true
		_tile += 1
		if _tile >= TILES * TILES:
			break
	_vp[back].render_target_update_mode = SubViewport.UPDATE_ONCE
	if _tile >= TILES * TILES:
		# Les morceaux de cette image seront dessinés avant que la mer et le terrain ne la
		# lisent : l'échange peut se faire tout de suite.
		_swap()


func _start_pass(light: Vector3, focus: Vector3) -> void:
	_tile = 0
	_pass_dir = light
	var px := Vector2((focus.x + WL.SIZE / 2.0) / TEXEL, (focus.z + WL.SIZE / 2.0) / TEXEL)
	_origin = Vector2i(clampi(int(px.x) - WIN / 2, 0, RES - WIN) & ~1, clampi(int(px.y) - WIN / 2, 0, RES - WIN) & ~1)
	_mat.set_shader_parameter("origin_px", Vector2(_origin))
	var flat := Vector2(light.x, light.z)
	var l := flat.length()
	var rise := maxf(light.y, 0.02) / maxf(l, 1e-4)
	var reach := minf(MAX_TOP / rise, MAX_REACH)
	_mat.set_shader_parameter("sun_xz", flat / maxf(l, 1e-4))
	_mat.set_shader_parameter("rise", rise)
	_mat.set_shader_parameter("steps", maxi(1, int(ceil(reach / STEP))))


func _swap() -> void:
	_front = 1 - _front
	_tile = -1
	_shown_origin = _origin
	_shown_dir = _pass_dir
	var tex := _vp[_front].get_texture()
	for m in materials:
		(m as ShaderMaterial).set_shader_parameter("static_shadow_tex", tex)
	var o := Vector2(_origin) * TEXEL - Vector2.ONE * WL.SIZE / 2.0
	RenderingServer.global_shader_parameter_set("shadow_rect", Vector4(o.x, o.y, WIN * TEXEL, 0.0))


func _rect_center(origin: Vector2i) -> Vector2:
	return (Vector2(origin) + Vector2.ONE * WIN / 2.0) * TEXEL - Vector2.ONE * WL.SIZE / 2.0
