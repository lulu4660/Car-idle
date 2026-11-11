## Mesure grossière du coût d'une image (rendu logiciel ici : à comparer entre versions,
## pas en valeur absolue) :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 960x540 -s tools/bench.gd [-- low]
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
	if frames == 30:
		t0 = Time.get_ticks_usec()
		Input.action_press("ci_gas")
	if frames == 150:
		var ms := (Time.get_ticks_usec() - t0) / 120.0 / 1000.0
		print("BENCH %.1f ms par image (%.0f i/s), %d appels de dessin, %d sommets" % [ms, 1000.0 / ms,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		quit()
