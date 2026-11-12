## Monde précalculé de la balade (tools/bake_world.gd) : relief, sols, profondeur de la mer.
## Le relief peut changer en jeu (sable creusé à la réception d'un saut).
extends RefCounted

const WL = preload("res://scripts/core/world_layout.gd")

const PATH := "res://assets/balade/world.bin"
const HEIGHT_RES := 1025
const SPLAT_RES := 512
## Zone détaillée de la mer, le long de la côte (x, z, largeur, profondeur en mètres).
const SEA_RECT := Rect2(290.0, -552.0, 420.0, 1104.0)
const SEA_W := 768
const SEA_H := 2048

var res := HEIGHT_RES
var heights := PackedFloat32Array()
var splat := PackedByteArray()
var sea_depth := PackedByteArray()
## Distance à l'axe de la piste de rallye, 0,05 m par unité (255 = loin).
var road := PackedByteArray()


static func load_baked() -> RefCounted:
	var d = load("res://scripts/balade/world_data.gd").new()
	var f := FileAccess.open_compressed(PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var tag := f.get_buffer(4).get_string_from_ascii() if f else ""
	if tag != "CIW1" and tag != "CIW2":
		push_error("Monde absent : lance tools/bake_world.gd")
		return null
	d.res = f.get_32()
	var sres := f.get_32()
	var sw := f.get_32()
	var sh := f.get_32()
	d.heights = f.get_buffer(d.res * d.res * 4).to_float32_array()
	d.splat = f.get_buffer(sres * sres * 4)
	d.sea_depth = f.get_buffer(sw * sh)
	if tag == "CIW2":
		d.road = f.get_buffer(d.res * d.res)
	else:
		d.road.resize(d.res * d.res)
		d.road.fill(255)
	return d


## Distance (m) à l'axe de la piste au point x, z (au plus 12,75 m).
func road_distance(x: float, z: float) -> float:
	var gx := clampi(int(round(x + WL.SIZE / 2.0)), 0, res - 1)
	var gz := clampi(int(round(z + WL.SIZE / 2.0)), 0, res - 1)
	return road[gz * res + gx] * 0.05


func road_image() -> Image:
	return Image.create_from_data(res, res, false, Image.FORMAT_R8, road)


## Hauteur du terrain (interpolée) au point x, z du monde.
func height_at(x: float, z: float) -> float:
	var gx := clampf(x + WL.SIZE / 2.0, 0.0, res - 1.001)
	var gz := clampf(z + WL.SIZE / 2.0, 0.0, res - 1.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var fx := gx - x0
	var fz := gz - z0
	var a := heights[z0 * res + x0]
	var b := heights[z0 * res + x0 + 1]
	var c := heights[(z0 + 1) * res + x0]
	var e := heights[(z0 + 1) * res + x0 + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, e, fx), fz)


func height_image() -> Image:
	return Image.create_from_data(res, res, false, Image.FORMAT_RF, heights.to_byte_array())


func splat_image() -> Image:
	return Image.create_from_data(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8, splat)


func sea_image() -> Image:
	return Image.create_from_data(SEA_W, SEA_H, false, Image.FORMAT_L8, sea_depth)
