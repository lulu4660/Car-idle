## Garage 3D (écran principal de la partie idle), en diorama cartoon : le garage vu de
## haut et de trois quarts, en coupe (deux murs, pas de plafond), qui flotte sur un fond
## sombre. Couleurs franches, lumière claire et nette (soleil chaud, ombres douces).
## - Devant : le pont élévateur, avec la voiture choisie ; il la soulève quand on achète
##   une amélioration (étincelles). Un mécano travaille à côté.
## - Derrière : les places peintes, en rangées, avec les voitures garées.
## - Murs de briques, soubassement charbon, rideau orange, enseigne néon de l'étape ;
##   établi, piles de pneus, cônes, caisses (Car Kit de Kenney, CC0).
## - Le garage grandit avec l'étape (Box, Atelier, Showroom, Hangar).
## Caméra orthographique (vue de maquette) : le garage entier tient dans la partie de
## l'écran que l'interface laisse libre (`cover_bottom` en portrait, `cover_right` en
## paysage).
extends Node3D

const Economy = preload("res://scripts/core/economy.gd")
const CarModels = preload("res://scripts/game/car_models.gd")

const ORANGE := Color(1.0, 0.52, 0.12)
const YELLOW := Color(1.0, 0.78, 0.16)
## Taille du garage (largeur, profondeur) par étape.
const ROOMS: Array[Vector2] = [Vector2(15, 13), Vector2(19, 15), Vector2(23, 17), Vector2(27, 19)]
const BAY_W := 3.2
const BAY_D := 5.6
const PROPS := "res://assets/garage/props/"

var game: Node
var camera: Camera3D
var ui: Node
## Part de l'écran couverte par l'interface : en bas (portrait) ou à droite (paysage).
var cover_bottom := 0.46
var cover_right := 0.4
## Part du haut de l'écran prise par l'argent (portrait).
var cover_top := 0.12
var _room := Vector2(15, 13)
var _room_node: Node3D
var _bays: Node3D
var _bay_cars := {}
var _bay_spots: Array[Transform3D] = []
var _lift_pos := Vector3.ZERO
var _lift_platform: Node3D
var _lift_car: Node3D
var _lift_uid := -1
var _lift_h := 0.0
var _lift_v := 0.0
var _lift_goal := 0.0
var _sign: Label3D
var _sparks: CPUParticles3D
var _worker: Node3D
var _worker_anim: AnimationPlayer
var _shown_stage := -1
var _shown_slots := -1
var _shown_size := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	# Tout le garage est animé image par image (pont, mécano, caméra) : pas d'interpolation
	# physique (activée dans project.godot pour la voiture de la balade).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game = get_node("/root/Game")
	_build_environment()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	ui = load("res://scripts/garage/garage_ui.gd").new()
	ui.garage = self
	add_child(ui)
	game.changed.connect(_refresh)
	_refresh()


# ------------------------------------------------------------------ caméra

## Vue de maquette : de trois quarts avant droit, en plongée ; le garage entier tient dans
## la partie libre de l'écran.
func _place_camera() -> void:
	if camera == null:
		return
	var size := get_viewport().get_visible_rect().size
	_shown_size = size
	var portrait := size.y > size.x
	var aspect := size.x / maxf(size.y, 1.0)
	var center := Vector3(0, 1.0, 0)
	var dir := Basis.from_euler(Vector3(deg_to_rad(-36.0), deg_to_rad(32.0), 0.0))
	camera.transform = Transform3D(dir, center + dir.z * 60.0)
	camera.near = 1.0
	camera.far = 200.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Étendue du garage vue par la caméra.
	var inv := camera.transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x in [-1.0, 1.0]:
		for y in [-0.6, 4.4]:
			for z in [-1.0, 1.0]:
				var p: Vector3 = inv * Vector3(x * _room.x / 2.0, y, z * _room.y / 2.0)
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var box := hi - lo
	var mid := (hi + lo) / 2.0
	var free_w: float
	var free_h: float
	var free_c: Vector2   # centre de la partie libre, en fraction de l'écran (0 à 1)
	if portrait:
		free_w = 0.9
		free_h = 1.0 - cover_bottom - cover_top
		free_c = Vector2(0.5, cover_top + free_h / 2.0)
	else:
		free_w = 1.0 - cover_right - 0.04
		free_h = 0.84
		free_c = Vector2(free_w / 2.0 + 0.02, 0.52)
	var s := maxf(box.y / free_h, box.x / (free_w * aspect))
	camera.size = s
	# Décale le cadre pour que le garage tombe au milieu de la partie libre.
	camera.h_offset = mid.x - (free_c.x - 0.5) * s * aspect
	camera.v_offset = mid.y + (free_c.y - 0.5) * s


func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_visible_rect().size != _shown_size:
		_place_camera()
	# Pont élévateur : ressort amorti vers sa hauteur voulue.
	_lift_v += ((_lift_goal - _lift_h) * 90.0 - _lift_v * 11.0) * delta
	_lift_h += _lift_v * delta
	if _lift_platform:
		_lift_platform.position.y = _lift_h
	if _lift_goal > 0.0 and absf(_lift_h - _lift_goal) < 0.05:
		_lift_goal = 0.0
	if _sign:
		_sign.modulate.a = 0.85 + 0.15 * sin(_t * 3.0)


# ------------------------------------------------------------------ matériaux

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _neon(c: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c.lerp(Color.WHITE, 0.3)
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _prop(parent: Node3D, name: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var n: Node3D = (load(PROPS + name + ".glb") as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


## Damier du sol (dalles de 2 m, deux gris chauds).
func _floor_tex() -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.6, 0.57, 0.53))
	img.set_pixel(1, 1, Color(0.6, 0.57, 0.53))
	img.set_pixel(1, 0, Color(0.55, 0.52, 0.49))
	img.set_pixel(0, 1, Color(0.55, 0.52, 0.49))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ décor

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.1, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.78, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Soleil chaud qui entre par la coupe : ombres nettes et douces.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 55.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


## Construit le garage pour l'étape en cours (taille, places, décor).
func _build_room() -> void:
	if _room_node:
		_room_node.queue_free()
	_bay_cars.clear()
	_lift_car = null
	_lift_uid = -1
	_room = ROOMS[game.stage]
	var root := Node3D.new()
	add_child(root)
	_room_node = root
	var w := _room.x
	var d := _room.y
	# Socle : dalle épaisse à bord charbon.
	_box(root, Vector3(w + 0.6, 0.8, d + 0.6), Vector3(0, -0.4, 0), _mat(Color(0.2, 0.17, 0.17)))
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	floor.mesh = pm
	var fm := _mat(Color.WHITE, 0.7)
	fm.albedo_texture = _floor_tex()
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(w / 4.0, d / 4.0, 1)
	floor.material_override = fm
	floor.position.y = 0.01
	root.add_child(floor)
	# Murs : fond et gauche (la coupe montre l'intérieur), briques, soubassement, chaperon.
	var brick := _mat(Color(0.66, 0.31, 0.22))
	var base := _mat(Color(0.2, 0.18, 0.18))
	var cap := _mat(Color(0.93, 0.86, 0.74))
	var h := 4.2
	_box(root, Vector3(w + 0.6, h, 0.6), Vector3(0, h / 2.0, -d / 2.0 - 0.3), brick)
	_box(root, Vector3(0.6, h, d), Vector3(-w / 2.0 - 0.3, h / 2.0, 0), brick)
	_box(root, Vector3(w + 0.62, 1.1, 0.64), Vector3(0, 0.55, -d / 2.0 - 0.3), base)
	_box(root, Vector3(0.64, 1.1, d), Vector3(-w / 2.0 - 0.3, 0.55, 0), base)
	_box(root, Vector3(w + 0.8, 0.22, 0.8), Vector3(0, h + 0.11, -d / 2.0 - 0.3), cap)
	_box(root, Vector3(0.8, 0.22, d + 0.2), Vector3(-w / 2.0 - 0.3, h + 0.11, 0.1), cap)
	# Joints de briques : quelques lignes claires sur les murs.
	var joint := _mat(Color(0.78, 0.42, 0.3))
	for y in [1.7, 2.5, 3.3]:
		_box(root, Vector3(w + 0.62, 0.06, 0.62), Vector3(0, y, -d / 2.0 - 0.3), joint)
		_box(root, Vector3(0.62, 0.06, d), Vector3(-w / 2.0 - 0.3, y, 0), joint)
	# Rideau métallique orange au fond, à droite.
	var door_x := w / 2.0 - 3.6
	_box(root, Vector3(4.6, 3.4, 0.2), Vector3(door_x, 1.7, -d / 2.0 + 0.02), _mat(Color(0.98, 0.55, 0.16), 0.6))
	for k in 8:
		_box(root, Vector3(4.6, 0.05, 0.24), Vector3(door_x, 0.3 + k * 0.4, -d / 2.0 + 0.02), _mat(Color(0.8, 0.38, 0.1)))
	_box(root, Vector3(5.0, 0.35, 0.4), Vector3(door_x, 3.55, -d / 2.0 + 0.05), base)
	# Fenêtres sur le mur de gauche (la nuit dehors, reflet chaud).
	for z in [-d / 4.0, d / 6.0]:
		_box(root, Vector3(0.12, 1.4, 2.2), Vector3(-w / 2.0 + 0.02, 2.5, z), _mat(Color(0.93, 0.86, 0.74)))
		_box(root, Vector3(0.14, 1.15, 1.95), Vector3(-w / 2.0 + 0.03, 2.5, z), _mat(Color(0.2, 0.15, 0.22), 0.2))
		_box(root, Vector3(0.16, 1.15, 0.08), Vector3(-w / 2.0 + 0.04, 2.5, z), _mat(Color(0.93, 0.86, 0.74)))
	# Enseigne néon de l'étape, au-dessus du rideau... sur le mur du fond, à gauche.
	_sign = Label3D.new()
	_sign.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_sign.font_size = 140
	_sign.pixel_size = 0.012
	_sign.outline_size = 22
	_sign.modulate = Color(1.0, 0.86, 0.5)
	_sign.outline_modulate = Color(1.0, 0.4, 0.08)
	_sign.shaded = false
	_sign.text = String(Economy.STAGES[game.stage]["name"]).to_upper()
	_sign.position = Vector3(-w / 2.0 + 4.5, 2.9, -d / 2.0 + 0.05)
	root.add_child(_sign)
	_box(root, Vector3(5.2, 1.6, 0.1), Vector3(-w / 2.0 + 4.5, 2.9, -d / 2.0 + 0.0), _mat(Color(0.16, 0.13, 0.13)))
	# Établi et mur à outils (gauche, devant), piles de pneus, cônes, caisses.
	var wood := _mat(Color(0.72, 0.5, 0.3))
	var bx := -w / 2.0 + 0.9
	var bz := d / 2.0 - 3.2
	_box(root, Vector3(1.2, 0.12, 2.8), Vector3(bx, 1.0, bz), wood)
	for dz in [-1.2, 1.2]:
		_box(root, Vector3(1.0, 1.0, 0.12), Vector3(bx, 0.5, bz + dz), _mat(Color(0.25, 0.22, 0.22)))
	_box(root, Vector3(0.6, 0.45, 0.8), Vector3(bx, 1.28, bz - 0.7), _mat(Color(0.88, 0.2, 0.15), 0.5))
	_box(root, Vector3(0.08, 1.3, 2.6), Vector3(-w / 2.0 + 0.05, 2.0, bz), _mat(Color(0.36, 0.3, 0.28)))
	for k in 5:
		_box(root, Vector3(0.1, 0.5, 0.1), Vector3(-w / 2.0 + 0.12, 2.0 + (k % 2) * 0.3, bz - 1.0 + k * 0.5), _mat(Color(0.75, 0.75, 0.72), 0.4))
	for k in 3:
		_prop(root, "debris-tire", Vector3(w / 2.0 - 1.0, 0.2 + k * 0.38, d / 2.0 - 1.4), k * 0.7, 2.2)
	_prop(root, "debris-tire", Vector3(w / 2.0 - 2.2, 0.2, d / 2.0 - 1.0), 0.3, 2.2)
	_prop(root, "cone", Vector3(2.8, 0, d / 2.0 - 0.8), 0.0, 1.6)
	_prop(root, "cone", Vector3(-2.8, 0, d / 2.0 - 0.8), 0.4, 1.6)
	_prop(root, "box", Vector3(door_x - 3.2, 0, -d / 2.0 + 0.8), 0.2, 1.8)
	_prop(root, "box", Vector3(door_x - 3.0, 0.9, -d / 2.0 + 0.8), 0.9, 1.4)
	_cyl(root, 0.4, 1.1, Vector3(-w / 2.0 + 0.7, 0.55, -d / 2.0 + 0.7), _mat(Color(0.85, 0.22, 0.15), 0.5))
	_cyl(root, 0.4, 1.1, Vector3(-w / 2.0 + 1.6, 0.55, -d / 2.0 + 0.6), _mat(Color(0.95, 0.65, 0.12), 0.5))
	# Pont élévateur, devant au centre : marquage jaune et noir, deux colonnes.
	_lift_pos = Vector3(0.6, 0, d / 2.0 - 3.6)
	_hazard(root, _lift_pos, Vector2(3.6, 5.8))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.4, 2.6, 0.4), _lift_pos + Vector3(sx * 1.85, 1.3, 0), _mat(YELLOW, 0.5))
		_box(root, Vector3(0.6, 0.2, 0.6), _lift_pos + Vector3(sx * 1.85, 2.7, 0), _mat(Color(0.25, 0.22, 0.22)))
	_lift_platform = Node3D.new()
	_lift_platform.position = _lift_pos
	root.add_child(_lift_platform)
	for sx in [-1.0, 1.0]:
		_box(_lift_platform, Vector3(0.35, 0.12, 4.6), Vector3(sx * 0.75, 0.08, 0), _mat(Color(0.3, 0.28, 0.28), 0.5))
	# Lumière chaude au-dessus du pont.
	var lamp := OmniLight3D.new()
	lamp.position = _lift_pos + Vector3(0, 4.5, 1.0)
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	root.add_child(lamp)
	var neon := OmniLight3D.new()
	neon.position = _sign.position + Vector3(0, 0, 1.2)
	neon.light_color = ORANGE
	neon.light_energy = 1.5
	neon.omni_range = 6.0
	root.add_child(neon)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 50
	_sparks.lifetime = 0.8
	_sparks.explosiveness = 0.9
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.0
	_sparks.gravity = Vector3(0, -12, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	_sparks.mesh = sm
	_sparks.material_override = _neon(Color(1.0, 0.8, 0.3))
	_sparks.position = _lift_pos + Vector3(0, 0.6, 0)
	root.add_child(_sparks)
	# Le mécano, qui bricole à côté du pont.
	_worker = (load("res://assets/props/people/character-worker.glb") as PackedScene).instantiate()
	_worker.scale = Vector3.ONE * 2.4
	_worker.position = _lift_pos + Vector3(2.7, 0, 1.2)
	_worker.rotation.y = -PI / 2.0 - 0.4
	root.add_child(_worker)
	var players := _worker.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_worker_anim = players[0]
		_play_worker("interact-right")
	_bays = Node3D.new()
	root.add_child(_bays)
	_layout_bays()


func _play_worker(anim: String) -> void:
	if _worker_anim and _worker_anim.has_animation(anim):
		_worker_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		_worker_anim.play(anim)


## Rectangle de sécurité jaune et noir autour du pont.
func _hazard(parent: Node3D, c: Vector3, size: Vector2) -> void:
	var yellow := _mat(YELLOW, 0.6)
	var black := _mat(Color(0.12, 0.1, 0.1), 0.6)
	var t := 0.22
	var n := int(size.x / 0.5)
	for side in [-1.0, 1.0]:
		for k in n:
			_box(parent, Vector3(size.x / n, 0.02, t), c + Vector3(-size.x / 2.0 + (k + 0.5) * size.x / n, 0.02, side * size.y / 2.0), yellow if k % 2 == 0 else black)
	var m := int(size.y / 0.5)
	for side in [-1.0, 1.0]:
		for k in m:
			_box(parent, Vector3(t, 0.02, size.y / m), c + Vector3(side * size.x / 2.0, 0.02, -size.y / 2.0 + (k + 0.5) * size.y / m), yellow if k % 2 == 0 else black)


## Places : rangées derrière le pont, voitures tournées vers l'avant.
func _layout_bays() -> void:
	_bay_spots.clear()
	var w := _room.x
	var d := _room.y
	var cols := int((w - 2.0) / BAY_W)
	var x0 := -(cols - 1) * BAY_W / 2.0
	var z := -d / 2.0 + 0.6 + BAY_D / 2.0
	while z + BAY_D / 2.0 < d / 2.0 - 6.6 and _bay_spots.size() < Economy.MAX_SLOTS:
		for c in cols:
			_bay_spots.append(Transform3D(Basis.IDENTITY, Vector3(x0 + c * BAY_W, 0, z)))
		z += BAY_D + 0.6
	var line := _mat(Color(0.97, 0.95, 0.9), 0.6)
	for n in mini(game.slots + 1, _bay_spots.size()):
		var xf := _bay_spots[n]
		var owned: bool = n < game.slots
		var m := line if owned else _mat(Color(1.0, 0.6, 0.2), 0.6)
		for dx in [-BAY_W / 2.0, BAY_W / 2.0]:
			_box(_bays, Vector3(0.1, 0.02, BAY_D), xf.origin + Vector3(dx, 0.02, 0), m)
		_box(_bays, Vector3(BAY_W, 0.02, 0.1), xf.origin + Vector3(0, 0.02, -BAY_D / 2.0), m)
		if not owned:
			var plus := Label3D.new()
			plus.text = "+"
			plus.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
			plus.font_size = 160
			plus.pixel_size = 0.012
			plus.modulate = Color(1.0, 0.6, 0.2)
			plus.shaded = false
			plus.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			plus.position = xf.origin + Vector3(0, 0.9, 0)
			_bays.add_child(plus)


# ------------------------------------------------------------------ voitures

func _car_node(car: Dictionary) -> Node3D:
	var node := Node3D.new()
	var kit := CarModels.kit_for(String(car["model"]))
	node.add_child(CarModels.showroom(kit, CarModels.color_of(car)))
	return node


## Remet le garage d'accord avec la partie.
func _refresh() -> void:
	if _shown_stage != game.stage:
		_shown_stage = game.stage
		_shown_slots = game.slots
		_build_room()
		_place_camera()
	elif _shown_slots != game.slots:
		_shown_slots = game.slots
		for c in _bays.get_children():
			c.queue_free()
		_layout_bays()
	var want := {}
	var k := 0
	for uid in game.parked:
		if uid != game.selected:
			want[uid] = k
		k += 1
	for uid in _bay_cars.keys():
		if not want.has(uid) or int(want[uid]) >= _bay_spots.size():
			(_bay_cars[uid] as Node3D).queue_free()
			_bay_cars.erase(uid)
	for uid in want:
		var i := int(want[uid])
		if i >= _bay_spots.size():
			continue
		var node: Node3D = _bay_cars.get(uid)
		if node == null:
			node = _car_node(game.get_car(uid))
			_room_node.add_child(node)
			_bay_cars[uid] = node
		node.transform = _bay_spots[i]
	if _lift_uid != game.selected:
		_show_on_lift(game.selected)


func _show_on_lift(uid: int) -> void:
	_lift_uid = uid
	if _lift_car:
		_lift_car.queue_free()
		_lift_car = null
	var car: Dictionary = game.get_car(uid)
	if car.is_empty():
		return
	_lift_car = _car_node(car)
	_lift_car.position.y = 0.14
	_lift_platform.add_child(_lift_car)
	# Arrivée : la voiture tombe sur le pont avec un rebond.
	_lift_car.position.y = 2.5
	var tw := create_tween()
	tw.tween_property(_lift_car, "position:y", 0.14, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Amélioration achetée : le pont soulève la voiture, étincelles, le mécano s'active.
func celebrate(big: bool) -> void:
	_lift_goal = 1.4 if big else 0.7
	_sparks.amount = 80 if big else 40
	_sparks.restart()
	_sparks.emitting = true
	_play_worker("emote-yes" if big else "interact-right")
	if big:
		get_tree().create_timer(1.2).timeout.connect(_play_worker.bind("interact-right"))


## Voiture garée la plus proche d'un point de l'écran (la toucher la choisit).
func car_at_screen(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for uid in _bay_cars:
		var node := _bay_cars[uid] as Node3D
		var sp := camera.unproject_position(node.global_position + Vector3(0, 0.7, 0))
		var dd := sp.distance_to(p)
		if dd < best_d:
			best_d = dd
			best = uid
	var vp := get_viewport().get_visible_rect().size
	return best if best_d < minf(vp.x, vp.y) * 0.08 else -1
