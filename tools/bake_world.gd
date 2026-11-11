## Précalcule le monde de la balade (assets/balade/world.bin) à partir de world_layout.gd :
## relief 1025 × 1025 (1 m), peinture des sols 512 × 512, profondeur de la mer le long de
## la côte. Le jeu le charge en un instant au lieu de recalculer 1 million de hauteurs.
## À relancer après tout changement de world_layout.gd :
##   godot --headless --path . -s tools/bake_world.gd
extends SceneTree

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var res := WorldData.HEIGHT_RES
	var half := WL.SIZE / 2.0
	var heights := PackedFloat32Array()
	heights.resize(res * res)
	for zi in res:
		var z := zi * WL.SIZE / (res - 1) - half
		for xi in res:
			heights[zi * res + xi] = WL.height(xi * WL.SIZE / (res - 1) - half, z)
	print("relief : %d ms" % (Time.get_ticks_msec() - t0))

	var splat := _splat(heights, res)
	print("sols : %d ms" % (Time.get_ticks_msec() - t0))

	var rect := WorldData.SEA_RECT
	var sw := WorldData.SEA_W
	var sh := WorldData.SEA_H
	var sea := PackedByteArray()
	sea.resize(sw * sh)
	for j in sh:
		var z := rect.position.y + (j + 0.5) / sh * rect.size.y
		for i in sw:
			var x := rect.position.x + (i + 0.5) / sw * rect.size.x
			var d := clampf((WL.SEA_LEVEL - WL.height(x, z)) / 8.0, 0.0, 1.0)
			sea[j * sw + i] = int(round(d * 255.0))

	DirAccess.make_dir_recursive_absolute("res://assets/balade")
	var f := FileAccess.open_compressed(WorldData.PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_buffer("CIW1".to_ascii_buffer())
	f.store_32(res)
	f.store_32(WorldData.SPLAT_RES)
	f.store_32(sw)
	f.store_32(sh)
	f.store_buffer(heights.to_byte_array())
	f.store_buffer(splat)
	f.store_buffer(sea)
	f.close()
	print("écrit %s en %d ms" % [WorldData.PATH, Time.get_ticks_msec() - t0])
	quit()


## Sols : un sol par point (R bitume, V terre, B sable, A sable mouillé), les creux des
## dunes un peu plus sombres, puis un flou 5 × 5 pour des transitions douces.
func _splat(heights: PackedFloat32Array, res: int) -> PackedByteArray:
	var a := WorldData.SPLAT_RES
	var half := WL.SIZE / 2.0
	var raw := PackedFloat32Array()
	raw.resize(a * a * 4)
	for zi in a:
		for xi in a:
			var x := (xi + 0.5) / a * WL.SIZE - half
			var z := (zi + 0.5) / a * WL.SIZE - half
			var hx := mini(res - 1, int(round((xi + 0.5) / a * (res - 1))))
			var hz := mini(res - 1, int(round((zi + 0.5) / a * (res - 1))))
			var h := heights[hz * res + hx]
			var s := WL.surface_at(x, z, h)
			var o := (zi * a + xi) * 4
			if s == WL.Surface.SAND:
				var trough := clampf((WL.GROUND_LEVEL + 3.0 - h) / 3.0, 0.0, 1.0)
				var patch := WL.fbm(x / 60.0 + 2.0, z / 60.0 - 5.0)
				var wet := clampf(trough * 0.35 + (patch - 0.55) * 0.5, 0.0, 1.0)
				raw[o + 2] = 1.0 - wet
				raw[o + 3] = wet
			else:
				var layer := WL.Surface.WET_SAND if s == WL.Surface.WATER else s
				raw[o + layer] = 1.0
	var out := PackedByteArray()
	out.resize(a * a * 4)
	for zi in a:
		for xi in a:
			var sum := [0.0, 0.0, 0.0, 0.0]
			for dz in range(-2, 3):
				var z2 := clampi(zi + dz, 0, a - 1)
				for dx in range(-2, 3):
					var o2 := (z2 * a + clampi(xi + dx, 0, a - 1)) * 4
					for l in 4:
						sum[l] += raw[o2 + l]
			var total: float = sum[0] + sum[1] + sum[2] + sum[3]
			for l in 4:
				out[(zi * a + xi) * 4 + l] = int(round(sum[l] / total * 255.0))
	return out
