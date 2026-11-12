## Captures de la balade pour relire le rendu :
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility -s tools/shot.gd -- out_dir [secondes_de_gaz] [mode_camera]
extends SceneTree

var frames := 0
var out := "shots"
var gas_s := 3.0
var cam_mode := 0
var balade: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: gas_s = float(args[1])
	if args.size() > 2: cam_mode = int(args[2])
	DirAccess.make_dir_recursive_absolute(out)
	balade = load("res://scenes/balade.tscn").instantiate()
	root.add_child(balade)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 5 and balade.camera:
		balade.camera.mode = cam_mode
	var t := frames / 60.0
	if t > 1.0 and t < 1.0 + gas_s:
		Input.action_press("ci_gas")
	else:
		Input.action_release("ci_gas")
	if t > 1.0 + gas_s * 0.5 and t < 1.0 + gas_s:
		Input.action_press("ci_right")
		Input.action_press("ci_drift")
	else:
		Input.action_release("ci_right")
		Input.action_release("ci_drift")
	for s in [1.0, 1.0 + gas_s, 2.5 + gas_s]:
		if frames == int(s * 60.0):
			var img := root.get_texture().get_image()
			var path := "%s/shot_%02d.png" % [out, int(s * 10)]
			img.save_png(path)
			print("capture ", path, " voiture=", balade.car.global_position.snapped(Vector3.ONE * 0.1), " v=", snappedf(balade.car.speed_kmh, 0.1), " up=", snappedf(balade.car.global_basis.y.y, 0.01))
	if frames > int((3.0 + gas_s) * 60.0):
		quit()
