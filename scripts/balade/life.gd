## La vie de la carte :
## - circulation : voitures du pack qui roulent sur la piste (dans les deux sens) et font le
##   tour des pâtés de maisons en ville ; elles ralentissent et s'arrêtent si la voiture du
##   joueur est devant elles ; on peut les heurter (corps cinématiques) ;
## - voitures garées le long des rues ;
## - piétons (Kenney Mini Characters, CC0) qui marchent sur les trottoirs et la plage, et
##   s'écartent quand on fonce sur eux ; vacanciers assis près des parasols ;
## - barques qui dansent sur la houle (mêmes vagues que la flottaison).
## Tout ce qui est loin de la voiture est mis en pause (ni animation, ni déplacement).
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")
const Car = preload("res://scripts/balade/car.gd")
const MeshMerge = preload("res://scripts/balade/mesh_merge.gd")
const CarModels = preload("res://scripts/game/car_models.gd")
const Waves = preload("res://scripts/balade/waves.gd")

const ACTIVE := 150.0
const PEOPLE := ["character-female-a", "character-female-b", "character-female-c", "character-female-d", "character-female-e", "character-female-f", "character-male-a", "character-male-b", "character-male-c", "character-male-d", "character-male-e", "character-male-f", "character-male-g", "character-worker"]
## Circulation : voitures du « Car Kit » de Kenney (même style que les voitures du garage).
const CIVIL := ["sedan", "hatchback-sports", "suv", "van", "truck", "sedan-sports", "suv-luxury", "taxi", "delivery"]
const SERVICE := ["police", "ambulance", "taxi", "delivery-flat", "garbage-truck"]

var data: RefCounted
var town: Node
var target: Node3D
var _traffic: Array = [] # [corps, chemin (PackedVector2Array), distances cumulées, longueur, s, vitesse visée, vitesse, sens]
var _people: Array = []  # [nœud, lecteur, a, b, t, sens, fuite]
var _boats: Array = []   # [nœud, base x, base z, phase]
var _road: PackedVector2Array
var _rng := RandomNumberGenerator.new()


func build(world_data: RefCounted, town_node: Node, follow: Node3D) -> void:
	data = world_data
	town = town_node
	target = follow
	_rng.seed = 99
	_road_traffic()
	_city_traffic()
	_parked()
	_pedestrians()
	_boats_on_sea()


# ------------------------------------------------------------------ voitures

## Maillage fusionné d'un véhicule du pack, tourné vers +Z et à la bonne taille.
func _variant(model: String) -> Array:
	return CarModels.oriented(model)


func _vehicle(model: String, kinematic: bool) -> Node3D:
	var v: Array = _variant(model)
	var body: Node3D
	if kinematic:
		body = AnimatableBody3D.new()
		(body as AnimatableBody3D).sync_to_physics = false
	else:
		body = StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = v[0]
	mi.transform = v[1]
	mi.visibility_range_end = 180.0 if kinematic else 120.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	var half: Vector3 = v[2]
	b.size = half * 2.0 * Vector3(0.95, 0.8, 0.95)
	cs.shape = b
	cs.position = Vector3(0, half.y, 0)
	body.add_child(cs)
	if kinematic:
		# Feux seulement sur les voitures qui roulent (les voitures garées sont éteintes).
		load("res://scripts/balade/balade.gd").add_lamps_to(body, Vector3(0, half.y * 0.75, 0), half)
	add_child(body)
	return body


func _road_traffic() -> void:
	var poly := WL.road_polyline()
	_road = poly
	for k in 7:
		var dir := 1 if k % 2 == 0 else -1
		var lane := PackedVector2Array()
		var n := poly.size()
		for i in n:
			var j := i if dir > 0 else n - 1 - i
			var a := poly[j]
			var b := poly[(j + dir + n) % n]
			var t := (b - a).normalized()
			lane.append(a + Vector2(-t.y, t.x) * 2.3)
		var model: String = CIVIL[_rng.randi() % CIVIL.size()] if _rng.randf() < 0.8 else SERVICE[_rng.randi() % SERVICE.size()]
		_add_mover(model, lane, _rng.randf_range(15.0, 21.0), true)


func _city_traffic() -> void:
	var half := WL.SIZE / 2.0
	for k in 12:
		var bx := (_rng.randi_range(-7, -5) * WL.BLOCK_SIZE) + WL.STREET_WIDTH * 0.5
		var bz := (_rng.randi_range(-7, 5) * WL.BLOCK_SIZE) + WL.STREET_WIDTH * 0.5
		var span := WL.BLOCK_SIZE * _rng.randi_range(1, 2)
		var corners := [Vector2(bx, bz), Vector2(bx + span, bz), Vector2(bx + span, bz + span), Vector2(bx, bz + span)]
		if bz + span > half - 20.0:
			continue
		var lane := PackedVector2Array()
		for c in 4:
			var a: Vector2 = corners[c]
			var b: Vector2 = corners[(c + 1) % 4]
			var t := (b - a).normalized()
			var r := Vector2(-t.y, t.x) * 3.0
			for m in 6:
				lane.append(a.lerp(b, m / 6.0) + r)
		var model: String = CIVIL[_rng.randi() % CIVIL.size()] if _rng.randf() < 0.75 else SERVICE[_rng.randi() % SERVICE.size()]
		_add_mover(model, lane, _rng.randf_range(9.0, 13.0), true)


func _add_mover(model: String, lane: PackedVector2Array, speed: float, loop: bool) -> void:
	var dist := PackedFloat32Array([0.0])
	for i in range(1, lane.size() + (1 if loop else 0)):
		dist.append(dist[i - 1] + lane[(i - 1) % lane.size()].distance_to(lane[i % lane.size()]))
	var body := _vehicle(model, true)
	_traffic.append([body, lane, dist, dist[dist.size() - 1], _rng.randf() * dist[dist.size() - 1], speed, speed])


func _parked() -> void:
	for spot in town.parking:
		var model: String = CIVIL[_rng.randi() % CIVIL.size()]
		var body := _vehicle(model, false)
		body.global_transform = Transform3D(Basis(Vector3.UP, float(spot[1])), spot[0])


func _point_at(lane: PackedVector2Array, dist: PackedFloat32Array, s: float) -> Array:
	var lo := 0
	var hi := dist.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if dist[mid] <= s:
			lo = mid
		else:
			hi = mid
	var a := lane[lo % lane.size()]
	var b := lane[hi % lane.size()]
	var t := (s - dist[lo]) / maxf(dist[hi] - dist[lo], 0.001)
	return [a.lerp(b, t), (b - a).normalized()]


# ------------------------------------------------------------------ piétons

func _pedestrians() -> void:
	var walks: Array = town.sidewalks.duplicate()
	for k in 30:
		if walks.is_empty():
			break
		var seg: Array = walks[_rng.randi() % walks.size()]
		_add_person(Vector3(seg[0].x, WL.GROUND_LEVEL, seg[0].y), Vector3(seg[1].x, WL.GROUND_LEVEL, seg[1].y), "walk")
	var spots: Array = town.beach_spots
	for k in mini(22, spots.size() * 2):
		var p: Vector3 = spots[_rng.randi() % spots.size()]
		if _rng.randf() < 0.5:
			# Vacancier assis ou debout près d'un parasol.
			var at := p + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
			at.y = data.height_at(at.x, at.z)
			_add_person(at, at, "sit" if _rng.randf() < 0.6 else "idle")
		else:
			# Promeneur le long de l'eau.
			var a := Vector3(p.x + 18.0, 0, p.z - 25.0)
			var b := Vector3(p.x + 18.0, 0, p.z + 25.0)
			a.y = data.height_at(a.x, a.z)
			b.y = data.height_at(b.x, b.z)
			_add_person(a, b, "walk")


func _add_person(a: Vector3, b: Vector3, anim: String) -> void:
	var path := "res://assets/props/people/%s.glb" % PEOPLE[_rng.randi() % PEOPLE.size()]
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.scale = Vector3.ONE * 2.6
	add_child(node)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visibility_range_end = 110.0
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false)[0] if node.find_children("*", "AnimationPlayer", true, false).size() > 0 else null
	if player and player.has_animation(anim):
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		player.play(anim)
		player.seek(_rng.randf() * 1.0, true)
	node.global_position = a.lerp(b, _rng.randf())
	_people.append([node, player, a, b, _rng.randf(), 1.0 if _rng.randf() < 0.5 else -1.0, 0.0, anim])


# ------------------------------------------------------------------ barques

func _boats_on_sea() -> void:
	var canoe: Node3D = (load("res://assets/props/nature/canoe.glb") as PackedScene).instantiate()
	var merged: Array = MeshMerge.merge(canoe)
	canoe.free()
	var mesh: ArrayMesh = merged[0]
	var box: AABB = merged[1]
	var s := 6.0 / maxf(box.size.z, box.size.x)
	for k in 10:
		var x := _rng.randf_range(430.0, 560.0)
		var z := _rng.randf_range(-420.0, 420.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3.ONE * s
		mi.visibility_range_end = 260.0
		add_child(mi)
		_boats.append([mi, x, z, _rng.randf() * TAU, _rng.randf_range(-1.2, 1.2) if k < 4 else 0.0])


# ------------------------------------------------------------------ chaque image

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var me := target.global_position
	var my_vel: Vector3 = target.linear_velocity if target is RigidBody3D else Vector3.ZERO
	for tr in _traffic:
		var body: Node3D = tr[0]
		if not body.visible:
			continue
		var lane: PackedVector2Array = tr[1]
		var dist: PackedFloat32Array = tr[2]
		var total: float = tr[3]
		var s: float = tr[4]
		var want: float = tr[5]
		var v: float = tr[6]
		var far := Vector2(body.global_position.x - me.x, body.global_position.z - me.z).length() > ACTIVE * 2.0
		# Freine si la voiture du joueur est juste devant, dans sa voie.
		var fwd := -body.global_basis.z if false else body.global_basis.z
		var to_me := me - body.global_position
		var ahead := to_me.dot(fwd)
		var lateral := (to_me - fwd * ahead).length()
		var goal := want
		if not far and ahead > 0.0 and ahead < 14.0 and lateral < 3.0:
			goal = 0.0
		v = move_toward(v, goal, (12.0 if goal < v else 3.0) * delta)
		s = fposmod(s + v * delta, total)
		tr[4] = s
		tr[6] = v
		if far:
			continue
		var pt: Array = _point_at(lane, dist, s)
		var p: Vector2 = pt[0]
		var t: Vector2 = pt[1]
		var g: float = data.height_at(p.x, p.y)
		var ahead_p := p + t * 2.0
		var g2: float = data.height_at(ahead_p.x, ahead_p.y)
		var pos := Vector3(p.x, maxf(g, WL.SEA_LEVEL), p.y)
		var look := Vector3(t.x, (g2 - g) / 2.0, t.y).normalized()
		body.global_transform = Transform3D(Basis.looking_at(-look, Vector3.UP), pos)
	for pe in _people:
		var node: Node3D = pe[0]
		var player: AnimationPlayer = pe[1]
		if not node.visible:
			continue
		var d := node.global_position.distance_to(me)
		var awake := d < ACTIVE
		if player:
			player.active = awake
		if not awake:
			continue
		var a: Vector3 = pe[2]
		var b: Vector3 = pe[3]
		var flee: float = pe[6]
		# Une voiture qui fonce dessus : on s'écarte en courant.
		if d < 7.0 and my_vel.length() > 4.0 and flee <= 0.0:
			pe[6] = 1.2
			if player and player.has_animation("sprint"):
				player.get_animation("sprint").loop_mode = Animation.LOOP_LINEAR
				player.play("sprint")
		if flee > 0.0:
			pe[6] = flee - delta
			var away := node.global_position - me
			away.y = 0.0
			var side := Vector3(-my_vel.z, 0.0, my_vel.x).normalized()
			if side.dot(away) < 0.0:
				side = -side
			node.global_position += side * 5.0 * delta
			node.global_position.y = data.height_at(node.global_position.x, node.global_position.z)
			node.look_at(node.global_position + side, Vector3.UP, true)
			if pe[6] <= 0.0 and player and player.has_animation(pe[7]):
				player.play(pe[7])
				# Reprend sa route depuis là où il est.
				pe[2] = node.global_position
				pe[4] = 0.0
			continue
		if a.distance_to(b) < 0.5:
			continue
		var t: float = float(pe[4]) + delta * 1.3 / a.distance_to(b) * float(pe[5])
		if t > 1.0 or t < 0.0:
			pe[5] = -pe[5]
			t = clampf(t, 0.0, 1.0)
		pe[4] = t
		var pos := a.lerp(b, t)
		pos.y = data.height_at(pos.x, pos.z)
		var dir: Vector3 = (b - a) * float(pe[5])
		node.global_position = pos
		if dir.length() > 0.01:
			node.look_at(pos + Vector3(dir.x, 0.0, dir.z), Vector3.UP, true)
	for bo in _boats:
		var mi: MeshInstance3D = bo[0]
		var x: float = bo[1]
		var z: float = bo[2]
		if bo[4] != 0.0:
			bo[2] = z + bo[4] * delta
			z = bo[2]
			if absf(z) > 450.0:
				bo[4] = -bo[4]
		var h := Waves.surface(x, z, 20.0)
		var hx := Waves.surface(x + 2.0, z, 20.0) - Waves.surface(x - 2.0, z, 20.0)
		var hz := Waves.surface(x, z + 3.0, 20.0) - Waves.surface(x, z - 3.0, 20.0)
		var up := Vector3(-hx / 4.0, 1.0, -hz / 6.0).normalized()
		var heading := Vector3(sin(bo[3]), 0.0, cos(bo[3]))
		var bx := up.cross(heading).normalized()
		var bz := bx.cross(up).normalized()
		mi.global_transform = Transform3D(Basis(bx, up, bz).scaled(mi.scale), Vector3(x, h - 0.15, z))


## Part de la circulation et des passants gardée (0 à 1, réglages graphiques) : les autres
## sont cachés, sans collision ni animation.
func set_density(f: float) -> void:
	for list in [_traffic, _people]:
		for i in list.size():
			var node: Node3D = list[i][0]
			# Suite de Weyl : la part gardée est répartie sur toute la carte.
			var on: bool = fposmod(i * 0.618034, 1.0) < f
			node.visible = on
			if node is CollisionObject3D:
				var co := node as CollisionObject3D
				if not co.has_meta("layer"):
					co.set_meta("layer", co.collision_layer)
				co.collision_layer = int(co.get_meta("layer")) if on else 0
			if list == _people and list[i][1]:
				(list[i][1] as AnimationPlayer).active = on
