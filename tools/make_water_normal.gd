## Fabrique la carte de rides de la mer (assets/water/ripples.png) : relief d'eau sans
## raccord (somme de vagues de fréquences entières dans des directions variées), converti
## en carte de normales. À relancer seulement pour changer l'aspect des rides :
##   godot --headless --path . -s tools/make_water_normal.gd
extends SceneTree

const SIZE := 256
const WAVES := 48


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var waves := []
	for i in WAVES:
		# Fréquences entières : la carte se raccorde parfaitement sur ses bords.
		var a := rng.randf() * TAU
		var f := rng.randf_range(2.0, 14.0)
		var kx := roundi(cos(a) * f)
		var ky := roundi(sin(a) * f)
		if kx == 0 and ky == 0:
			kx = 3
		var k := Vector2(kx, ky).length()
		waves.append([kx, ky, 1.0 / pow(k, 1.3), rng.randf() * TAU])
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE * TAU
			var v := float(y) / SIZE * TAU
			var s := 0.0
			for w in waves:
				# Crêtes un peu pointues, creux arrondis, comme de petites vagues de vent.
				var ph: float = w[0] * u + w[1] * v + w[3]
				s += w[2] * (1.0 - absf(sin(ph * 0.5))) * 2.0
			h[y * SIZE + x] = s
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var grads := PackedVector2Array()
	grads.resize(SIZE * SIZE)
	var big := 0.0
	for y in SIZE:
		for x in SIZE:
			var dx := h[y * SIZE + (x + 1) % SIZE] - h[y * SIZE + (x - 1 + SIZE) % SIZE]
			var dy := h[((y + 1) % SIZE) * SIZE + x] - h[((y - 1 + SIZE) % SIZE) * SIZE + x]
			grads[y * SIZE + x] = Vector2(dx, dy)
			big = maxf(big, Vector2(dx, dy).length())
	# Pente la plus forte ramenée à ~45° : rides nettes, le shader en dose l'effet.
	var strength := 1.0 / maxf(big, 1e-6)
	for y in SIZE:
		for x in SIZE:
			var g := grads[y * SIZE + x] * strength
			var n := Vector3(-g.x, -g.y, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.save_png("res://assets/water/ripples.png")
	print("assets/water/ripples.png écrit")
	quit()
