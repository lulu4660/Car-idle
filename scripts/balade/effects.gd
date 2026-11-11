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


## Pose une empreinte si la roue a assez avancé depuis la dernière.
func track(wheel: int, point: Vector3, normal: Vector3, heading: Vector3, surface: int, width: float) -> void:
	var life: float = MARK_LIFE[surface]
	if life <= 0.0:
		return
	if _last_stamp[wheel].distance_to(point) < STAMP_SPACING:
		return
	_last_stamp[wheel] = point
	var z := (heading - normal * heading.dot(normal)).normalized()
	var x := normal.cross(z).normalized()
	var basis := Basis(x * width, normal, z * STAMP_SPACING * 1.15)
	_stamps.set_instance_transform(_stamp_next, Transform3D(basis, point + normal * 0.03))
	_stamps.set_instance_color(_stamp_next, MARK_COLORS[surface])
	_stamps.set_instance_custom_data(_stamp_next, Color(_now(), life, 0, 0))
	_stamp_next = (_stamp_next + 1) % MAX_STAMPS


## La roue a quitté le sol : la prochaine trace repart de zéro.
func lift(wheel: int) -> void:
	_last_stamp[wheel] = Vector3.INF


## Un grain de poussière : départ, vitesse, couleur, taille (m), durée (s).
func dust(pos: Vector3, vel: Vector3, color: Color, size: float, life: float) -> void:
	# La 1re colonne de la base porte la vitesse (le shader fait face à la caméra).
	var basis := Basis(vel, Vector3.UP, Vector3.BACK)
	_dust.set_instance_transform(_dust_next, Transform3D(basis, pos))
	_dust.set_instance_color(_dust_next, color)
	_dust.set_instance_custom_data(_dust_next, Color(_now(), life, size, randf()))
	_dust_next = (_dust_next + 1) % MAX_DUST


## Gerbe de sable à la réception d'un saut, projetée tout autour.
func burst(point: Vector3, surface: int, strength: float) -> void:
	var c: Color = DUST_COLORS[surface]
	for k in int(28.0 * strength):
		var a := randf() * TAU
		var r := randf_range(1.5, 5.0) * strength
		var v := Vector3(cos(a) * r, randf_range(1.5, 4.5) * strength, sin(a) * r)
		dust(point + Vector3.UP * 0.15, v, Color(c.r, c.g, c.b, minf(1.0, c.a * 1.4) * randf_range(0.7, 1.0)), randf_range(0.8, 2.2) * (0.8 + strength * 0.5), randf_range(1.2, 2.8))
