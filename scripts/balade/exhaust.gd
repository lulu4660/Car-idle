## Pot d'échappement de la voiture conduite et ses retours de flamme : au lever de pied
## après une montée en régime (une salve de 2 à 4 claquements), au passage d'un rapport
## supérieur, et quelques crépitements en décélération à haut régime. Flamme : cône additif
## et halo (`shaders/flame.gdshader`), aucune vraie lumière. Le son est joué par audio.gd
## (`car.backfire_pop`).
extends Node3D

const FLAME := preload("res://shaders/flame.gdshader")

var car: VehicleBody3D
var _flame: MeshInstance3D
var _glow: MeshInstance3D
var _flame_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _queue: Array[float] = []      # moments des prochains claquements (s)
var _queue_k: Array[float] = []    # force de chacun
var _t := 0.0
var _life := 0.0
var _life_max := 0.1
var _power := 0.0
var _length := 0.6
var _since_high := 9.0           # temps depuis le dernier « plein gaz » (s)
var _peak_rpm := 0.0
var _prev_gear := 1
var _cool := 0.0
var _rng := RandomNumberGenerator.new()


## Pose le pot sous l'arrière de la caisse (repère de la caisse : avant vers +Z, gauche +X).
static func attach(c: VehicleBody3D) -> Node3D:
	var body := c.body_node.get_node_or_null("Carrosserie") as MeshInstance3D
	if body == null:
		return null
	var b := body.get_aabb()
	var ex: Node3D = load("res://scripts/balade/exhaust.gd").new()
	ex.name = "Echappement"
	ex.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # flamme animée dans _process
	ex.car = c
	# Côté droit (-X), bas de la caisse, dépasse un peu du pare-chocs : l'arrière est cherché
	# parmi les sommets à cet endroit (une roue de secours ne doit pas reculer le pot).
	var px := b.get_center().x - b.size.x * 0.27
	var py := maxf(b.position.y, c.body_bottom * 0.6) + 0.08
	var rear := INF
	for s in body.mesh.get_surface_count():
		for v in body.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x - px) < 0.25 and absf(v.y - py) < 0.25:
				rear = minf(rear, v.z)
	if rear == INF:
		rear = b.position.z
	ex.position = Vector3(px, py, rear - 0.02)
	c.body_node.add_child(ex)
	return ex


func _ready() -> void:
	_rng.randomize()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.42, 0.4, 0.4)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var pipe := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = 0.3
	pm.radial_segments = 10
	pipe.mesh = pm
	pipe.material_override = metal
	pipe.rotation_degrees.x = 90.0
	pipe.position = Vector3(0, 0, 0.1)
	add_child(pipe)
	# Bouche sombre au bout du pot.
	var mouth := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.035
	mm.bottom_radius = 0.035
	mm.height = 0.01
	mm.radial_segments = 10
	mouth.mesh = mm
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.03, 0.03, 0.03)
	mouth.material_override = black
	mouth.rotation_degrees.x = 90.0
	mouth.position = Vector3(0, 0, -0.051)
	add_child(mouth)

	# Flamme : cône de rayon 1 et de longueur 1 le long de -Z, la base à la sortie du pot.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 10
	cone.rings = 3
	cone.cap_top = false
	cone.cap_bottom = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cone, 0, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0, -0.5)))
	_flame = MeshInstance3D.new()
	_flame.mesh = st.commit()
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = FLAME
	_flame.material_override = _flame_mat
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = Vector3(0, 0, -0.05)
	_flame.visible = false
	add_child(_flame)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_glow.mesh = q
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = FLAME
	_glow_mat.set_shader_parameter("glow", true)
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position = Vector3(0, 0, -0.25)
	_glow.scale = Vector3.ONE * 0.7
	_glow.visible = false
	add_child(_glow)


## Un claquement (force 0 à 1).
func pop(k: float) -> void:
	_life_max = _rng.randf_range(0.07, 0.13)
	_life = _life_max
	_power = clampf(k, 0.2, 1.0)
	_length = lerpf(0.45, 1.25, _power) * _rng.randf_range(0.75, 1.15)
	_flame_mat.set_shader_parameter("seed", _rng.randf() * 100.0)
	if car:
		car.backfire_pop = maxf(car.backfire_pop, _power)


## Une salve de n claquements, de plus en plus faibles.
func burst(n: int, k: float) -> void:
	var at := _t
	for i in n:
		_queue.append(at)
		_queue_k.append(k * pow(0.8, i))
		at += _rng.randf_range(0.06, 0.15)


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	if car and not car.in_water:
		_watch(delta)
	# Claquements prévus.
	var i := 0
	while i < _queue.size():
		if _queue[i] <= _t:
			pop(_queue_k[i])
			_queue.remove_at(i)
			_queue_k.remove_at(i)
		else:
			i += 1
	# Flamme qui jaillit puis retombe.
	if _life > 0.0:
		_life -= delta
		var a := clampf(_life / _life_max, 0.0, 1.0)
		var grow := 1.0 - pow(a, 3.0)   # sort très vite
		var p := _power * (0.35 + 0.65 * a)
		_flame.visible = true
		_glow.visible = true
		_flame.scale = Vector3(0.09 + 0.07 * _power, 0.09 + 0.07 * _power, maxf(0.05, _length * lerpf(0.4, 1.0, grow)))
		_flame_mat.set_shader_parameter("power", p)
		_glow_mat.set_shader_parameter("power", p)
		_glow.position.z = -0.12 - _length * 0.3
	elif _flame.visible:
		_flame.visible = false
		_glow.visible = false


## Quand la voiture claque : lever de pied après une montée en régime, rapport supérieur,
## crépitements en décélération à haut régime.
func _watch(delta: float) -> void:
	var load_now: float = car.engine_load
	var rpm: float = car.rpm
	_since_high += delta
	if load_now > 0.55:
		_since_high = 0.0
		_peak_rpm = maxf(_peak_rpm, rpm)
	elif _since_high > 0.5:
		_peak_rpm = lerpf(_peak_rpm, rpm, minf(1.0, delta * 1.5))
	if _cool <= 0.0:
		# La charge du moteur retombe en ≈ 0,15 s quand on lâche les gaz.
		if load_now < 0.3 and _since_high < 0.35 and _peak_rpm > 0.55:
			burst(_rng.randi_range(2, 4), lerpf(0.55, 1.0, clampf((_peak_rpm - 0.55) / 0.4, 0.0, 1.0)))
			_cool = 0.6
			_since_high = 9.0
			_peak_rpm = rpm
		elif car.gear > _prev_gear and car.gear > 1 and load_now > 0.5:
			burst(_rng.randi_range(1, 2), 0.75)
			_cool = 0.35
		elif load_now < 0.1 and rpm > 0.5 and car.speed_kmh > 35.0 and _rng.randf() < delta * 1.6:
			pop(_rng.randf_range(0.25, 0.5))
			_cool = 0.15
	_prev_gear = car.gear
