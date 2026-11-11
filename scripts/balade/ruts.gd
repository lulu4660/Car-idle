## Ornières : les roues creusent vraiment le sable et la terre. Autour de la voiture, une
## pièce de terrain fine (12,5 cm entre sommets, 20 cm sur iPhone) suit la voiture ; une carte des creux
## (8 cm par texel, 41 m de côté) garde la profondeur des ornières et leurs bourrelets.
## Le creux dépend du sol (sable profond, terre moins), de la charge et de la glisse ; il
## s'accumule quand on repasse. La carte glisse avec la voiture : au-delà de ~20 m derrière,
## les ornières s'effacent de la vue.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")

const TEX := 512
const TEXEL := 0.08
const SPAN := TEX * TEXEL           # 40,96 m
var mesh_step := 0.125
const RUT_DEPTH := 0.3              # profondeur codée par R = 1 (m)
const RUT_BERM := 0.12              # bourrelet codé par G = 1 (m)
const UPDATE_EVERY := 1.0 / 20.0    # envoi de la carte à la carte graphique (20 fois/s)

# Profondeur d'une ornière par passage, selon le sol (m) : bitume, terre, sable, mouillé, eau.
const DEPTH := [0.0, 0.035, 0.07, 0.045, 0.0]

var _image: Image
var _texture: ImageTexture
var _origin := Vector2.ZERO          # coin de la zone (x, z) en m, multiple de TEXEL
var _patch: MeshInstance3D
var _materials: Array[ShaderMaterial] = []
var _last: Array = [null, null, null, null]
var _dirty := false
var _since_upload := 0.0


## `terrain_material` : le matériau du terrain ; la pièce en reçoit une copie en mode fin.
func build(terrain_material: ShaderMaterial) -> void:
	_image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	_texture = ImageTexture.create_from_image(_image)

	var patch_mat := terrain_material.duplicate() as ShaderMaterial
	patch_mat.set_shader_parameter("is_patch", true)
	_materials = [terrain_material, patch_mat]
	for m in _materials:
		m.set_shader_parameter("rut_tex", _texture)
		m.set_shader_parameter("rut_depth", RUT_DEPTH)
		m.set_shader_parameter("rut_berm", RUT_BERM)

	var n := int(SPAN / mesh_step)
	var pm := PlaneMesh.new()
	pm.size = Vector2(SPAN, SPAN)
	pm.subdivide_width = n - 1
	pm.subdivide_depth = n - 1
	pm.center_offset = Vector3(SPAN / 2.0, 0, SPAN / 2.0)
	_patch = MeshInstance3D.new()
	_patch.name = "Ornieres"
	_patch.mesh = pm
	_patch.material_override = patch_mat
	_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_patch.custom_aabb = AABB(Vector3(0, -5, 0), Vector3(SPAN, WL.MAX_HEIGHT + 10.0, SPAN))
	add_child(_patch)
	_set_origin(Vector2(WL.SPAWN_X, WL.SPAWN_Z) - Vector2(SPAN, SPAN) / 2.0)


func _set_origin(o: Vector2) -> void:
	_origin = Vector2(snappedf(o.x, TEXEL), snappedf(o.y, TEXEL))
	_patch.position = Vector3(_origin.x, 0, _origin.y)
	for m in _materials:
		m.set_shader_parameter("rut_rect", Vector4(_origin.x, _origin.y, SPAN, SPAN))


## Recentre la zone sur la voiture quand elle s'approche du bord ; les ornières déjà
## creusées glissent avec (copie décalée de la carte).
func follow(center: Vector3) -> void:
	var c := Vector2(center.x, center.z)
	var rel := c - _origin - Vector2(SPAN, SPAN) / 2.0
	if absf(rel.x) < SPAN * 0.2 and absf(rel.y) < SPAN * 0.2:
		return
	var new_origin := Vector2(snappedf(c.x - SPAN / 2.0, TEXEL), snappedf(c.y - SPAN / 2.0, TEXEL))
	var shift := Vector2i(roundi((new_origin.x - _origin.x) / TEXEL), roundi((new_origin.y - _origin.y) / TEXEL))
	var old := _image.duplicate() as Image
	_image.fill(Color(0, 0, 0, 1))
	var src := Rect2i(Vector2i.ZERO, Vector2i(TEX, TEX)).intersection(Rect2i(shift, Vector2i(TEX, TEX)))
	if src.size.x > 0 and src.size.y > 0:
		_image.blit_rect(old, src, src.position - shift)
	_set_origin(_origin + Vector2(shift) * TEXEL)
	_dirty = true
	for i in 4:
		_last[i] = null


## La roue `wheel` touche le sol meuble en `point` : creuse le trajet depuis le dernier point.
## `width` : largeur du pneu (m) ; `load_k` : appui (0 à 1,5) ; `slip` : glisse (0 à 1).
func dig(wheel: int, point: Vector3, surface: int, width: float, load_k: float, slip: float) -> void:
	var depth: float = DEPTH[surface] * clampf(load_k, 0.3, 1.5) * (1.0 + slip * 1.2)
	if depth <= 0.0:
		_last[wheel] = null
		return
	var p := Vector2(point.x, point.z)
	var a: Variant = _last[wheel]
	_last[wheel] = p
	if a == null or (a as Vector2).distance_to(p) > 2.0:
		return
	_stamp_segment(a as Vector2, p, width * 0.5, depth)


func lift(wheel: int) -> void:
	_last[wheel] = null


## Creuse le long du segment a → b : fond plat sur la largeur du pneu, bords arrondis,
## sable repoussé en bourrelet de chaque côté.
func _stamp_segment(a: Vector2, b: Vector2, half: float, depth: float) -> void:
	var berm_w := half * 1.4
	var reach := half + berm_w
	var lo := (Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach) - _origin) / TEXEL
	var hi := (Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach) - _origin) / TEXEL
	var x0 := clampi(int(floor(lo.x)), 0, TEX - 1)
	var y0 := clampi(int(floor(lo.y)), 0, TEX - 1)
	var x1 := clampi(int(ceil(hi.x)), 0, TEX - 1)
	var y1 := clampi(int(ceil(hi.y)), 0, TEX - 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 1e-6)
	var d_code := depth / RUT_DEPTH
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var wp := _origin + Vector2(x + 0.5, y + 0.5) * TEXEL
			var t := clampf((wp - a).dot(ab) / len2, 0.0, 1.0)
			var dist := wp.distance_to(a + ab * t)
			if dist > reach:
				continue
			var c := _image.get_pixel(x, y)
			if dist < half:
				# Fond de l'ornière : profil arrondi sur les bords ; repasser creuse un peu plus.
				var k := 1.0 - pow(dist / half, 4.0)
				var want := d_code * k
				c.r = minf(1.0, maxf(c.r, want) + want * 0.08)
				c.g = maxf(0.0, c.g - want * 0.5)
			else:
				# Bourrelet : le sable chassé sur les côtés.
				var u := (dist - half) / berm_w
				var berm := sin(u * PI) * depth * 0.45 / RUT_BERM
				c.g = minf(1.0, maxf(c.g, berm * (1.0 - c.r)))
			_image.set_pixel(x, y, c)
	_dirty = true


func _process(delta: float) -> void:
	_since_upload += delta
	if _dirty and _since_upload >= UPDATE_EVERY:
		_texture.update(_image)
		_dirty = false
		_since_upload = 0.0
