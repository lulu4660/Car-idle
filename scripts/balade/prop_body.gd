## Objet du décor destructible : immobile tant que rien ne le touche ; quand la voiture
## arrive dessus (zone de détection un peu plus large que l'objet), il devient mobile et
## reçoit le choc : il est projeté, roule, et les objets fragiles se brisent en morceaux
## qui s'effacent au bout de quelques secondes.
extends RigidBody3D

const WL = preload("res://scripts/core/world_layout.gd")

var fragile := false
var debris_color := Color(0.55, 0.40, 0.26)
var effects: Node3D
var _hit := false


func setup(size: Vector3) -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0.8, 0.6, 0.8)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0, size.y / 2.0, 0)
	add_child(area)
	area.body_entered.connect(_on_touch)


func _on_touch(body: Node3D) -> void:
	if _hit or not body is VehicleBody3D:
		return
	var v: Vector3 = (body as VehicleBody3D).linear_velocity
	if v.length() < 2.0:
		return
	_hit = true
	freeze = false
	# Le choc : dans le sens de la voiture, un peu vers le haut, avec une rotation.
	var push := v * mass * 0.9 + Vector3.UP * mass * clampf(v.length() * 0.35, 1.0, 6.0)
	apply_impulse(push, Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)))
	if effects:
		effects.burst(global_position, WL.Surface.SAND, clampf(v.length() / 12.0, 0.4, 1.4))
	if fragile and v.length() > 5.0:
		_break.call_deferred(v)
	else:
		_settle_later()


## Se brise : quelques blocs de la couleur de l'objet, projetés, qui disparaissent ensuite.
func _break(v: Vector3) -> void:
	var size := Vector3.ONE * 0.6
	for c in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			size = ((c as CollisionShape3D).shape as BoxShape3D).size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = debris_color
	mat.roughness = 0.9
	var parent := get_parent()
	var n := 7
	for i in n:
		var piece := RigidBody3D.new()
		piece.mass = maxf(1.0, mass / n)
		var s := size * randf_range(0.22, 0.4)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm
		mi.material_override = mat
		piece.add_child(mi)
		var pc := CollisionShape3D.new()
		var pb := BoxShape3D.new()
		pb.size = s
		pc.shape = pb
		piece.add_child(pc)
		parent.add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(0.1, 0.9) * size.y, randf_range(-0.5, 0.5) * size.z)
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		piece.linear_velocity = v * randf_range(0.4, 0.9) + Vector3(randf_range(-3, 3), randf_range(2, 6), randf_range(-3, 3))
		piece.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_fade_out(piece, randf_range(4.0, 7.0))
	queue_free()


func _fade_out(node: Node3D, after: float) -> void:
	var t := get_tree().create_timer(after)
	t.timeout.connect(func() -> void:
		if is_instance_valid(node):
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.6)
			tw.tween_callback(node.queue_free))


## Une fois retombé et immobile, l'objet se fige de nouveau (plus aucun calcul).
func _settle_later() -> void:
	await get_tree().create_timer(4.0).timeout
	while is_instance_valid(self) and linear_velocity.length() > 0.2:
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		freeze = true
		_hit = false
