## Capture rapide d'un plan fixe de la balade (pour relire le rendu) :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 960x540 -s tools/pose.gd -- sortie.png [plan_caméra] [x z cap°]
extends SceneTree

var frames := 0
var out := "pose.png"
var cam_mode := 0
var place := []
var balade: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: cam_mode = int(args[1])
	if args.size() > 4: place = [float(args[2]), float(args[3]), float(args[4])]
	balade = load("res://scenes/balade.tscn").instantiate()
	root.add_child(balade)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 3:
		balade.camera.mode = cam_mode
		if place.size() == 3:
			balade.car.respawn(Vector3(place[0], 0, place[1]), deg_to_rad(place[2]))
			balade.camera.snap()
	if frames == 75:
		root.get_texture().get_image().save_png(out)
		print("capture ", out)
		quit()
