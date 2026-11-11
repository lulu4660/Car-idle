## Effets de roues pour toute la balade, dessinés par la carte graphique :
## - traces de pneus : empreintes posées au sol (sillons dans le sable et la terre dès qu'on
##   roule, gomme sur le bitume quand ça glisse), qui s'effacent avec le temps ;
## - poussière, panaches de sable à contre-jour, gerbes et éclaboussures.
## Chaque élément est une instance d'un MultiMesh (anneau réutilisé), animée dans un shader.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")

const MAX_STAMPS := 6000
const MAX_DUST := 2500
const STAMP_SPACING := 0.35

# Couleur des traces par sol (alpha = force de la marque).
const MARK_COLORS: Array[Color] = [
	Color(0.05, 0.05, 0.05, 0.55), Color(0.22, 0.15, 0.10, 0.5),
	Color(0.42, 0.31, 0.19, 0.6), Color(0.33, 0.26, 0.18, 0.5), Color(0, 0, 0, 0)]
const MARK_LIFE: Array[float] = [8.0, 25.0, 35.0, 15.0, 0.0]
# Poussière soulevée, par sol (alpha = densité).
const DUST_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.75, 0.30), Color(0.62, 0.48, 0.34, 0.45),
	Color(0.92, 0.78, 0.58, 0.55), Color(0.70, 0.62, 0.50, 0.3), Color(0.92, 0.97, 1.0, 0.6)]

var _stamps: MultiMesh
var _stamp_next := 0
var _dust: MultiMesh
var _dust_next := 0
var _dust_material: ShaderMaterial
var _last_stamp: Array[Vector3] = []
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -1000, 0))
var _clock := 0.0
var _track_material: ShaderMaterial


func _ready() -> void:
	_track_material = ShaderMaterial.new()
	_track_material.shader = load("res://shaders/stamps.gdshader")
	_track_material.set_shader_parameter("tex", _track_texture())
	_stamps = _ring(MAX_STAMPS, _stamp_mesh(), _track_material)

	_dust_material = ShaderMaterial.new()
	_dust_material.shader = load("res://shaders/dust.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_dust = _ring(MAX_DUST, quad, _dust_material)
	for i in 4:
		_last_stamp.append(Vector3.INF)


func set_sun(dir: Vector3, color: Color) -> void:
	_dust_material.set_shader_parameter("sun_dir", dir)
	_dust_material.set_shader_parameter("sun_color", color)


func _ring(count: int, mesh: Mesh, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, _hidden)
		mm.set_instance_custom_data(i, Color(-1000, 0.01, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3000, -100, -3000), Vector3(6000, 400, 6000))
	add_child(mmi)
	return mm


## Une empreinte : petit rectangle couché (0,4 × 0,4 m), long selon z.
func _stamp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.5
	var l := 0.5
	var pts := [Vector3(-w, 0, -l), Vector3(w, 0, -l), Vector3(w, 0, l), Vector3(-w, 0, l)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	return st.commit()


## Bande de pneu : bords doux, sculptures du pneu.
func _track_texture() -> ImageTexture:
	var img := Image.create(32, 64, true, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var u := (x + 0.5) / 32.0 * 2.0 - 1.0
			var band := clampf((1.0 - absf(u)) * 3.0, 0.0, 1.0)
			var tread := 0.75 + 0.25 * signf(sin(y / 64.0 * TAU * 4.0 + absf(u) * 3.0))
			img.set_pixel(x, y, Color(1, 1, 1, band * tread))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Horloge propre aux effets, partagée avec les shaders (TIME du moteur démarre plus tôt
## que le jeu et ne peut pas servir de référence pour les poses).
func _process(delta: float) -> void:
	_clock += delta
	_track_material.set_shader_parameter("now", _clock)
	_dust_material.set_shader_parameter("now", _clock)


func _now() -> float:
	return _clock


## Prolonge la trace d'une roue : un segment du dernier point au point actuel, posé à plat,
## orienté selon le vrai trajet de la roue (une bande continue, même en dérapage).
func track(wheel: int, point: Vector3, normal: Vector3, _heading: Vector3, surface: int, width: float) -> void:
	var life: float = MARK_LIFE[surface]
	if life <= 0.0:
		return
	var last: Vector3 = _last_stamp[wheel]
	if last == Vector3.INF:
		_last_stamp[wheel] = point
		return
	var seg := point - last
	var length := seg.length()
	if length < STAMP_SPACING:
		return
	_last_stamp[wheel] = point
	if length > 3.0:
		return  # saut ou téléportation : pas de trait à travers le vide
	var z := (seg - normal * seg.dot(normal)).normalized()
	var x := normal.cross(z).normalized()
	var basis := Basis(x * width, normal, z * (length + 0.06))
	_stamps.set_instance_transform(_stamp_next, Transform3D(basis, (last + point) * 0.5 + normal * 0.03))
	_stamps.set_instance_color(_stamp_next, MARK_COLORS[surface])
	_stamps.set_instance_custom_data(_stamp_next, Color(_now(), life, 0, 0))
	_stamp_next = (_stamp_next + 1) % MAX_STAMPS


## La roue a quitté le sol : la prochaine trace repart de zéro.
func lift(wheel: int) -> void:
	_last_stamp[wheel] = Vector3.INF


## Types de particules (même ordre que dans shaders/dust.gdshader).
enum Kind { DUST, SAND, WATER }
const DRAG: Array[float] = [1.6, 0.7, 0.5]
const GRAVITY: Array[float] = [-0.5, 7.0, 9.8]
const WIND := Vector3(0.6, 0.0, 0.25)

# Copie côté jeu de l'état de chaque particule, pour que la voiture puisse la souffler.
var _p_origin := PackedVector3Array()
var _p_vel := PackedVector3Array()
var _p_start := PackedFloat32Array()
var _p_kind := PackedInt32Array()
var _p_floor := PackedFloat32Array()
var _p_end := PackedFloat32Array()


## Une particule : départ, vitesse, couleur, taille (m), durée (s), type, hauteur du sol.
func dust(pos: Vector3, vel: Vector3, color: Color, size: float, life: float, kind := Kind.DUST, floor_y := -1000.0) -> void:
	if _p_origin.size() != MAX_DUST:
		_p_origin.resize(MAX_DUST); _p_vel.resize(MAX_DUST); _p_start.resize(MAX_DUST)
		_p_kind.resize(MAX_DUST); _p_floor.resize(MAX_DUST); _p_end.resize(MAX_DUST)
	var i := _dust_next
	var t := _now()
	if floor_y < -999.0:
		floor_y = pos.y - 0.3
	_p_origin[i] = pos; _p_vel[i] = vel; _p_start[i] = t; _p_kind[i] = kind; _p_floor[i] = floor_y; _p_end[i] = t + life
	_write(i)
	_dust.set_instance_color(i, color)
	_dust.set_instance_custom_data(i, Color(t, life, size, randf()))
	_dust_next = (_dust_next + 1) % MAX_DUST


## Écrit la trajectoire de la particule i dans le MultiMesh (vitesse, départ, type, sol).
func _write(i: int) -> void:
	var basis := Basis(_p_vel[i], Vector3(_p_start[i], _p_kind[i], _p_floor[i]), Vector3.BACK)
	_dust.set_instance_transform(i, Transform3D(basis, _p_origin[i]))


## Position et vitesse de la particule i maintenant (même calcul que le shader).
func _state(i: int, t_now: float) -> Array:
	var k := _p_kind[i]
	var dr: float = DRAG[k]
	var g: float = GRAVITY[k]
	var t := maxf(t_now - _p_start[i], 0.0)
	var e := exp(-dr * t)
	var pos := _p_origin[i] + _p_vel[i] * (1.0 - e) / dr - Vector3(0, g, 0) * (t / dr - (1.0 - e) / (dr * dr))
	var vel := _p_vel[i] * e - Vector3(0, g, 0) * (1.0 - e) / dr
	if k == Kind.DUST:
		pos += WIND * t * smoothstep(0.0, 1.5, t)
	elif pos.y <= _p_floor[i]:
		pos.y = _p_floor[i]
		vel = Vector3.ZERO
	return [pos, vel]


## La voiture traverse un nuage : les particules proches sont soufflées (entraînées dans
## son sens et écartées sur les côtés), les grains posés au sol sont relancés.
func push_from(center: Vector3, velocity: Vector3, radius: float) -> void:
	var speed := velocity.length()
	if speed < 3.0 or _p_origin.size() != MAX_DUST:
		return
	var t := _now()
	var r2 := radius * radius
	for i in MAX_DUST:
		if _p_end[i] < t or _p_origin[i].distance_squared_to(center) > (radius + 14.0) * (radius + 14.0):
			continue
		var st := _state(i, t)
		var pos: Vector3 = st[0]
		var d2 := pos.distance_squared_to(center)
		if d2 > r2:
			continue
		var f := 1.0 - sqrt(d2) / radius
		var away := pos - center
		away.y = 0.0
		var kick := velocity * 0.55 * f + away.normalized() * speed * 0.35 * f + Vector3.UP * speed * 0.12 * f
		_p_origin[i] = pos
		_p_vel[i] = st[1] + kick
		_p_start[i] = t
		_write(i)


## Gerbe de sable à la réception d'un saut, projetée tout autour.
func burst(point: Vector3, surface: int, strength: float) -> void:
	var c: Color = DUST_COLORS[surface]
	for k in int(28.0 * strength):
		var a := randf() * TAU
		var r := randf_range(1.5, 5.0) * strength
		var v := Vector3(cos(a) * r, randf_range(1.5, 4.5) * strength, sin(a) * r)
		var kind := Kind.WATER if surface == WL.Surface.WATER else Kind.DUST
		dust(point + Vector3.UP * 0.15, v, Color(c.r, c.g, c.b, minf(1.0, c.a * 1.4) * randf_range(0.7, 1.0)), randf_range(0.8, 2.2) * (0.8 + strength * 0.5), randf_range(1.2, 2.8), kind)
	# Grains de sable projetés, qui retombent.
	if surface != WL.Surface.WATER and surface != WL.Surface.ASPHALT:
		for k in int(40.0 * strength):
			var a := randf() * TAU
			var r := randf_range(2.0, 6.0) * strength
			dust(point + Vector3.UP * 0.1, Vector3(cos(a) * r, randf_range(3.0, 7.0) * strength, sin(a) * r), Color(c.r * 0.85, c.g * 0.8, c.b * 0.75, 0.95), randf_range(0.08, 0.16), randf_range(1.5, 2.5), Kind.SAND, point.y - 0.05)
