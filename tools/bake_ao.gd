## Précalcule l'ombrage des creux (assets/balade/ao.png, 1024², 1 m par pixel) : le sol
## s'assombrit doucement au pied des objets (arbres, rochers, bâtiments, d'après la carte
## des obstacles occluders.png) et au fond des vallons (relief plus bas que ses environs).
## Comme dans les jeux « Art of Rally » : ce qui donne du volume, calculé une fois.
## À relancer après tools/bake_shadows.gd ou tools/bake_world.gd :
##   godot --headless --path . -s tools/bake_ao.gd
extends SceneTree

const WorldData = preload("res://scripts/balade/world_data.gd")
const RES := 1024
const OUT := "res://assets/balade/ao.png"


## Flou par réduction puis agrandissement (filtrage de la bibliothèque d'images).
func _blur(src: Image, small: int) -> Image:
	var img := src.duplicate() as Image
	img.resize(small, small, Image.INTERPOLATE_BILINEAR)
	img.resize(RES, RES, Image.INTERPOLATE_CUBIC)
	return img


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# Objets : part couverte × hauteur (les grands objets assombrissent plus loin).
	var occ: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/balade/occluders.png"))
	occ.convert(Image.FORMAT_RGB8)
	var mass := Image.create(occ.get_width(), occ.get_height(), false, Image.FORMAT_RF)
	for y in occ.get_height():
		for x in occ.get_width():
			var p := occ.get_pixel(x, y)
			mass.set_pixel(x, y, Color(p.b * clampf(p.r * 25.5 / 5.0, 0.0, 1.0), 0, 0))
	mass.resize(RES, RES, Image.INTERPOLATE_BILINEAR)
	var near := _blur(mass, 384)
	var far := _blur(mass, 160)
	# Relief : creux = plus bas que la moyenne des environs (sur ~16 m et ~40 m).
	var data = WorldData.load_baked()
	var h: Image = data.height_image()
	h.convert(Image.FORMAT_RF)
	h.resize(RES, RES, Image.INTERPOLATE_BILINEAR)
	var h16 := _blur(h, 64)
	var h40 := _blur(h, 26)
	var out := Image.create(RES, RES, false, Image.FORMAT_L8)
	for y in RES:
		for x in RES:
			var obj := clampf(near.get_pixel(x, y).r * 1.5 + far.get_pixel(x, y).r * 0.9, 0.0, 1.0)
			var hh := h.get_pixel(x, y).r
			var cav := clampf((h16.get_pixel(x, y).r - hh) / 3.0, 0.0, 1.0) * 0.6 + clampf((h40.get_pixel(x, y).r - hh) / 8.0, 0.0, 1.0) * 0.4
			var v := clampf(obj * 0.85 + cav * 0.6, 0.0, 1.0)
			out.set_pixel(x, y, Color(v, v, v))
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("%s écrit en %d ms" % [OUT, Time.get_ticks_msec() - t0])
	quit()
