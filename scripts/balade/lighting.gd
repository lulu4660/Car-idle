## Lumière et post-traitement de la balade, de jour comme de nuit.
## - Jour : soleil doré d'après-midi, ombres lavande, brume chaude, halo doux (glow) sur
##   les reflets, étalonnage (contraste, saturation), vignettage.
## - Nuit : lune froide, ciel bleu nuit, brume sombre ; réverbères, fenêtres et phares
##   s'allument (paramètre global « night » lu par les shaders), halo plus fort.
## Passage de l'un à l'autre en douceur (set_night).
extends Node

const WorldBuilder = preload("res://scripts/balade/world_builder.gd")

const DAY := {
	"sun_color": Color(1.0, 0.86, 0.70), "sun_energy": 1.9, "elev": 34.0, "azim": 225.0,
	"ambient": Color(0.60, 0.60, 0.80), "ambient_energy": 0.75,
	"sky_top": Color(0.22, 0.42, 0.58), "sky_horizon": Color(0.86, 0.78, 0.72),
	"ground_horizon": Color(0.80, 0.70, 0.55), "ground_bottom": Color(0.70, 0.58, 0.42),
	"fog": Color(0.90, 0.78, 0.72), "fog_density": 0.0022, "exposure": 0.9,
	"glow": 0.35, "glow_bloom": 0.04, "glow_threshold": 1.0, "contrast": 1.06, "saturation": 0.95,
	"shadow": 0.92, "vignette": 0.28,
}
const NIGHT := {
	"sun_color": Color(0.55, 0.66, 1.0), "sun_energy": 0.32, "elev": 42.0, "azim": 150.0,
	"ambient": Color(0.20, 0.23, 0.42), "ambient_energy": 0.55,
	"sky_top": Color(0.01, 0.02, 0.07), "sky_horizon": Color(0.07, 0.08, 0.18),
	"ground_horizon": Color(0.06, 0.06, 0.12), "ground_bottom": Color(0.03, 0.03, 0.06),
	"fog": Color(0.06, 0.07, 0.14), "fog_density": 0.0035, "exposure": 1.05,
	"glow": 0.7, "glow_bloom": 0.08, "glow_threshold": 0.8, "contrast": 1.12, "saturation": 1.05,
	"shadow": 0.35, "vignette": 0.5,
}

var env: Environment
var sun: DirectionalLight3D
var sky: ProceduralSkyMaterial
var shadow_materials: Array = []
var night := 0.0
## Allumage des lumières de nuit (0 à 1), la valeur donnée aux shaders.
var glow := 0.0
var _target := 0.0
var _vignette: TextureRect
## iPhone et web : le halo (glow) seulement la nuit, là où il fait briller les lumières ;
## le jour son effet est discret et il coûte une passe d'image.
var glow_only_at_night := false


func setup(environment: Environment, sun_light: DirectionalLight3D, parent: Node) -> void:
	env = environment
	sun = sun_light
	sky = env.sky.sky_material as ProceduralSkyMaterial
	_build_vignette(parent)
	_apply(0.0)


func set_night(on: bool, instant := false) -> void:
	_target = 1.0 if on else 0.0
	if instant:
		night = _target
		_apply(night)


func is_night() -> bool:
	return _target > 0.5


## Direction vers la source de lumière principale (soleil ou lune) en ce moment.
func light_direction() -> Vector3:
	var el := deg_to_rad(lerpf(DAY["elev"], NIGHT["elev"], night))
	var az := deg_to_rad(lerpf(DAY["azim"], NIGHT["azim"], night))
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


func _process(delta: float) -> void:
	if not is_equal_approx(night, _target):
		night = move_toward(night, _target, delta / 2.5)
		_apply(night)


func _v(key: String, k: float) -> Variant:
	var a: Variant = DAY[key]
	var b: Variant = NIGHT[key]
	if a is Color:
		return (a as Color).lerp(b, k)
	return lerpf(a, b, k)


func _apply(k: float) -> void:
	# Le ciel et la lumière basculent un peu avant le reste (crépuscule).
	var e := smoothstep(0.0, 1.0, k)
	glow = smoothstep(0.25, 0.9, k)
	RenderingServer.global_shader_parameter_set("night", glow)
	sun.light_color = _v("sun_color", e)
	sun.light_energy = _v("sun_energy", e)
	sun.look_at_from_position(Vector3.ZERO, -light_direction(), Vector3.UP)
	env.ambient_light_color = _v("ambient", e)
	env.ambient_light_energy = _v("ambient_energy", e)
	sky.sky_top_color = _v("sky_top", e)
	sky.sky_horizon_color = _v("sky_horizon", e)
	sky.ground_horizon_color = _v("ground_horizon", e)
	sky.ground_bottom_color = _v("ground_bottom", e)
	sky.sun_angle_max = lerpf(20.0, 4.0, e)
	env.fog_light_color = _v("fog", e)
	env.fog_density = _v("fog_density", e)
	env.tonemap_exposure = _v("exposure", e)
	env.glow_enabled = not glow_only_at_night or e > 0.05
	env.glow_intensity = _v("glow", e)
	env.glow_bloom = _v("glow_bloom", e)
	env.glow_hdr_threshold = _v("glow_threshold", e)
	env.adjustment_contrast = _v("contrast", e)
	env.adjustment_saturation = _v("saturation", e)
	for m in shadow_materials:
		(m as ShaderMaterial).set_shader_parameter("shadow_strength", _v("shadow", e))
	if _vignette:
		_vignette.modulate.a = _v("vignette", e)


## Vignettage : un dégradé radial posé sur l'image (presque gratuit, pas de passe en plus).
func _build_vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	parent.add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.0, 0.05, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vignette)
