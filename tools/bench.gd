## Mesure grossière du coût d'une image (rendu logiciel ici : à comparer entre versions,
## pas en valeur absolue) :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 960x540 -s tools/bench.gd [-- low] [night] [city]
## night : mode nuit ; city : en ville (le plus chargé) ; nospot / noglow : sans phares / sans halo
## (pour isoler un coût).
extends SceneTree

var frames := 0
var t0 := 0
var balade: Node


func _init() -> void:
	balade = load("res://scenes/balade.tscn").instantiate()
	if "low" in OS.get_cmdline_user_args():
		balade.set("force_quality", 0)
	root.add_child(balade)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var args := OS.get_cmdline_user_args()
	if frames == 5:
		if "city" in args:
			balade.car.respawn(Vector3(-352, 0, -52), PI / 2)
			balade.camera.snap()
		if "night" in args:
			balade.lighting.set_night(true, true)
	if frames > 5:
		if "nospot" in args:
			for l in balade._car_lights:
				l.visible = false
		if "notilt" in args and balade.lighting.tilt_shift:
			balade.lighting.tilt_shift.get_parent().visible = false
		if "noglow" in args:
			balade.lighting.env.glow_enabled = false
	if frames == 30:
		t0 = Time.get_ticks_usec()
		Input.action_press("ci_gas")
	if frames == 150:
		var ms := (Time.get_ticks_usec() - t0) / 120.0 / 1000.0
		print("BENCH %.1f ms par image (%.0f i/s), %d appels de dessin, %d sommets" % [ms, 1000.0 / ms,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		quit()
