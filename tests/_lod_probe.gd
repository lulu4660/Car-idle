extends SceneTree
var b: Node
var f := 0
var last := {}
func _initialize() -> void:
	b = load("res://scenes/balade.tscn").instantiate()
	b.set("force_quality", 0)
	root.add_child(b)
	process_frame.connect(_frame)
func _frame() -> void:
	f += 1
	if f == 3:
		b.car.respawn(Vector3(40, 0, -360), deg_to_rad(-59.0))
		b.camera.snap()
	if f == 30: Input.action_press("ci_gas", 0.7)
	if f > 60 and f < 400:
		var cam: Camera3D = b.camera
		for i in b.vegetation._lod_cells.size():
			var c: Dictionary = b.vegetation._lod_cells[i]
			if last.has(i) and last[i] != c["lod"]:
				print("f=%d case %s lod %d->%d d=%.1f cam=%s car=%s v=%.0f" % [f, c["center"], last[i], c["lod"], Vector2(cam.global_position.x, cam.global_position.z).distance_to(c["center"]), cam.global_position.snapped(Vector3.ONE), b.car.global_position.snapped(Vector3.ONE), b.car.speed_kmh])
			last[i] = c["lod"]
	if f == 400:
		quit()
