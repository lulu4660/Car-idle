## Vraies vagues autour de la voiture : la surface de l'eau est simulée sur une grille de
## 64 m (50 cm par case) qui suit la voiture (shaders/water_sim.gdshader, équation des ondes
## en eau peu profonde, un pas par image). La caisse et les roues qui fendent l'eau la
## poussent : vague d'étrave, sillage en V, vagues qui ralentissent et meurent sur le sable.
## Deux SubViewports se passent le relais (l'un lit l'image de l'autre) ; la mer lit la
## dernière image (texture `texture()`, zone `rect()`).
extends Node

const WL = preload("res://scripts/core/world_layout.gd")

const SIZE := 128
const CELL := 0.5
const SPAN := SIZE * CELL            # 64 m
const RANGE := 1.0                    # hauteur codée : ±1 m
const SNAP := 0.5

var _vp: Array[SubViewport] = []
var _mat: Array[ShaderMaterial] = []
var _cur := 0
var _origin := Vector2.ZERO
var _pending_shift := Vector2i.ZERO
var active := false


func build(height_tex: Texture2D, data: RefCounted) -> void:
	var shader := load("res://shaders/water_sim.gdshader")
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var rect := ColorRect.new()
		rect.size = Vector2(SIZE, SIZE)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("height_tex", height_tex)
		m.set_shader_parameter("size", SIZE)
		m.set_shader_parameter("cell", CELL)
		m.set_shader_parameter("world_size", WL.SIZE)
		m.set_shader_parameter("res", data.res)
		m.set_shader_parameter("sea_level", WL.SEA_LEVEL)
		m.set_shader_parameter("range", RANGE)
		rect.material = m
		vp.add_child(rect)
		add_child(vp)
		_vp.append(vp)
		_mat.append(m)
	_mat[0].set_shader_parameter("state", _vp[1].get_texture())
	_mat[1].set_shader_parameter("state", _vp[0].get_texture())


## Un pas de simulation. `center` : où garder la zone ; `hull` : [centre, avant, demi-taille
## (x, z), enfoncement] ; `stirs` : roues dans l'eau (x, z, rayon, enfoncement).
func step(center: Vector3, hull_pos: Vector3, hull_fwd: Vector3, hull_half: Vector2, dip: float, stirs: Array[Vector4], dt: float) -> void:
	var want := Vector2(snappedf(center.x - SPAN / 2.0, SNAP), snappedf(center.z - SPAN / 2.0, SNAP))
	if not active:
		_origin = want
		_pending_shift = Vector2i(SIZE * 4, SIZE * 4)  # repart d'une eau calme
	elif (want - _origin).length() > SPAN * 0.2:
		_pending_shift = Vector2i(roundi((want.x - _origin.x) / CELL), roundi((want.y - _origin.y) / CELL))
		_origin = want
	active = true
	var nxt := 1 - _cur
	var m := _mat[nxt]
	m.set_shader_parameter("origin", _origin)
	m.set_shader_parameter("shift", _pending_shift)
	_pending_shift = Vector2i.ZERO
	m.set_shader_parameter("dt", clampf(dt, 1.0 / 120.0, 1.0 / 30.0))
	var f := Vector2(hull_fwd.x, hull_fwd.z).normalized()
	m.set_shader_parameter("hull", Vector4(hull_pos.x, hull_pos.z, 0, 0))
	m.set_shader_parameter("hull_axis", Vector4(f.x, f.y, hull_half.x, hull_half.y))
	m.set_shader_parameter("hull_dip", dip)
	var arr := PackedVector4Array(stirs)
	arr.resize(4)
	m.set_shader_parameter("stirs", arr)
	_vp[nxt].render_target_update_mode = SubViewport.UPDATE_ONCE
	_cur = nxt


func texture() -> Texture2D:
	return _vp[_cur].get_texture()


## Zone simulée (x, z, largeur, profondeur) en m.
func rect() -> Vector4:
	return Vector4(_origin.x, _origin.y, SPAN, SPAN) if active else Vector4(0, 0, -1, -1)
