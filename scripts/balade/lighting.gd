## Lumière et post-traitement de la balade, au fil d'une vraie journée.
## - Heure qui avance (cycle réglable, figé possible) : le soleil se lève sur la mer à l'est,
##   passe au sud et se couche derrière les montagnes à l'ouest ; la lune suit le même
##   chemin douze heures plus tard. Les deux sont des lumières directionnelles qui dessinent
##   leur disque dans le ciel ; seule celle qui est levée éclaire (l'autre est éteinte).
## - Couleurs selon la hauteur du soleil : jour (soleil doré, ombres lavande, brume chaude),
##   aube et crépuscule (soleil orangé, ciel rose), nuit (lune froide, ciel bleu nuit) ;
##   réverbères, fenêtres et phares s'allument (paramètre global « night »).
## - Ombres du décor précalculées pour 4 positions du soleil (tools/bake_shadows.gd, une
##   par canal de shadows.png) : mélangées selon l'heure (paramètre global « shadow_mix »).
extends Node

const WorldBuilder = preload("res://scripts/balade/world_builder.gd")

## Hauteur maximale du soleil (midi) et de la lune.
const SUN_MAX_ELEV := 58.0
const MOON_MAX_ELEV := 50.0
## Heures des 4 cartes d'ombres précalculées (une par canal R, G, B, A).
const SHADOW_HOURS: Array[float] = [7.5, 10.5, 13.5, 16.5]

const DAY := {
	"sun_color": Color(1.0, 0.86, 0.70), "sun_energy": 1.9,
	"ambient": Color(0.60, 0.60, 0.80), "ambient_energy": 0.75,
	"sky_top": Color(0.22, 0.42, 0.58), "sky_horizon": Color(0.86, 0.78, 0.72),
	"ground_horizon": Color(0.80, 0.70, 0.55), "ground_bottom": Color(0.70, 0.58, 0.42),
	"fog": Color(0.90, 0.78, 0.72), "fog_density": 0.0022, "exposure": 0.9,
	"glow": 0.35, "glow_bloom": 0.04, "glow_threshold": 1.0, "contrast": 1.06, "saturation": 0.95,
	"shadow": 0.92, "vignette": 0.28,
}
const DUSK := {
	"sun_color": Color(1.0, 0.55, 0.32), "sun_energy": 1.5,
	"ambient": Color(0.58, 0.48, 0.66), "ambient_energy": 0.65,
	"sky_top": Color(0.24, 0.30, 0.52), "sky_horizon": Color(1.0, 0.62, 0.44),
	"ground_horizon": Color(0.86, 0.56, 0.42), "ground_bottom": Color(0.50, 0.38, 0.34),
	"fog": Color(0.96, 0.64, 0.52), "fog_density": 0.0026, "exposure": 0.95,
	"glow": 0.5, "glow_bloom": 0.06, "glow_threshold": 0.9, "contrast": 1.1, "saturation": 1.08,
	"shadow": 0.75, "vignette": 0.36,
}
const NIGHT := {
	"sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 0.7,
	"ambient": Color(0.32, 0.36, 0.58), "ambient_energy": 0.95,
	"sky_top": Color(0.02, 0.03, 0.10), "sky_horizon": Color(0.10, 0.12, 0.24),
	"ground_horizon": Color(0.08, 0.08, 0.15), "ground_bottom": Color(0.04, 0.04, 0.08),
	"fog": Color(0.10, 0.12, 0.20), "fog_density": 0.0028, "exposure": 1.35,
	"glow": 0.7, "glow_bloom": 0.08, "glow_threshold": 0.8, "contrast": 1.12, "saturation": 1.05,
	"shadow": 0.35, "vignette": 0.5,
}

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky: ProceduralSkyMaterial
var shadow_materials: Array = []
## Heure (0 à 24).
var hour := 15.0
## Durée d'une journée complète en minutes réelles (0 = heure figée).
var cycle_minutes := 24.0
## Facteur de nuit (0 jour, 1 nuit) et allumage des lumières (valeur donnée aux shaders).
var night := 0.0
var glow := 0.0
var _scrub_to := -1.0
var _flashing := false
var _base_ambient := 0.75
var _vignette: TextureRect
## iPhone et web : pas de halo plein écran (glow), trop coûteux (28 ms la nuit au banc
## d'essai) ; les lumières ont leurs propres petits halos (shaders/halo.gdshader).
var no_glow := false
## Brouillard (réglages) : 1 = brume d'origine, 0 = aucune, jusqu'à 8 = brouillard épais.
var fog_amount := 1.0
var _apply_timer := 0.0
## Météo (weather.gd) : nuages, pluie, brouillard, éclairs.
var weather: Node


## Direction vers le soleil à une heure donnée (repère Godot : nord = -Z, est = +X).
static func sun_dir_at(h: float) -> Vector3:
	var t := (h - 6.0) / 12.0
	var az := deg_to_rad(90.0 + 180.0 * t)
	var el := deg_to_rad(SUN_MAX_ELEV * sin(PI * t))
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


static func moon_dir_at(h: float) -> Vector3:
	var t := (fposmod(h + 12.0, 24.0) - 6.0) / 12.0
	var az := deg_to_rad(90.0 + 180.0 * t)
	var el := deg_to_rad(MOON_MAX_ELEV * sin(PI * t))
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


## Poids des 4 cartes d'ombres pour une heure de soleil (6 h à 18 h).
static func shadow_mix_at(h: float) -> Vector4:
	var w := [0.0, 0.0, 0.0, 0.0]
	if h <= SHADOW_HOURS[0]:
		w[0] = 1.0
	elif h >= SHADOW_HOURS[3]:
		w[3] = 1.0
	else:
		for i in 3:
			if h <= SHADOW_HOURS[i + 1]:
				var k := (h - SHADOW_HOURS[i]) / (SHADOW_HOURS[i + 1] - SHADOW_HOURS[i])
				w[i] = 1.0 - k
				w[i + 1] = k
				break
	return Vector4(w[0], w[1], w[2], w[3])


func setup(environment: Environment, sun_light: DirectionalLight3D, parent: Node) -> void:
	env = environment
	sun = sun_light
	sky = env.sky.sky_material as ProceduralSkyMaterial
	# Le ciel change avec l'heure : ses reflets sont recalculés par étapes, sans à-coup.
	env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	moon = DirectionalLight3D.new()
	moon.name = "Lune"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_angular_distance = 0.6
	moon.shadow_enabled = false
	parent.add_child(moon)
	_build_vignette(parent)
	_apply()


## Bouton NUIT / JOUR : fait défiler le temps jusqu'à la nuit (22 h 30) ou jusqu'à
## l'après-midi (15 h). `instant` : tout de suite.
func set_night(on: bool, instant := false) -> void:
	var target := 22.5 if on else 15.0
	if instant:
		hour = target
		_scrub_to = -1.0
		_apply()
	else:
		_scrub_to = target


func is_night() -> bool:
	var h := _scrub_to if _scrub_to >= 0.0 else hour
	return sun_dir_at(h).y < 0.0


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_scrub_to = -1.0
	_apply()


## Réapplique l'éclairage (après un changement de réglage graphique).
func refresh() -> void:
	_apply()


## Direction vers la source de lumière principale (soleil ou lune) en ce moment.
func light_direction() -> Vector3:
	var s := sun_dir_at(hour)
	return s if s.y > -0.02 else moon_dir_at(hour)


func _process(delta: float) -> void:
	if _scrub_to >= 0.0:
		# Défilement rapide (6 heures par seconde), par le chemin le plus court en avant.
		var gap := fposmod(_scrub_to - hour, 24.0)
		var step := delta * 6.0
		if gap <= step:
			hour = _scrub_to
			_scrub_to = -1.0
		else:
			hour = fposmod(hour + step, 24.0)
		_apply()
		return
	if cycle_minutes > 0.0:
		hour = fposmod(hour + delta * 24.0 / (cycle_minutes * 60.0), 24.0)
	# Le soleil et la météo changent lentement : l'éclairage et le ciel sont recalculés une
	# fois par seconde, ce qui ne se voit pas et coûte peu.
	_apply_timer -= delta
	if _apply_timer <= 0.0:
		_apply_timer = 1.0
		_apply()
	# Éclair d'orage : la scène s'illumine un instant (sans attendre le recalcul).
	if weather and (weather.flash > 0.0 or _flashing):
		_flashing = weather.flash > 0.0
		env.ambient_light_energy = _base_ambient + weather.flash * 3.0
		env.background_energy_multiplier = 1.0 + weather.flash * 2.5


func _mix(key: String, dusk: float, k_night: float) -> Variant:
	var a: Variant = DAY[key]
	var b: Variant = DUSK[key]
	var c: Variant = NIGHT[key]
	if a is Color:
		return (a as Color).lerp(b, dusk).lerp(c, k_night)
	return lerpf(lerpf(a, b, dusk), c, k_night)


func _apply() -> void:
	var sd := sun_dir_at(hour)
	var md := moon_dir_at(hour)
	var sun_el := rad_to_deg(asin(sd.y))
	var moon_el := rad_to_deg(asin(md.y))
	# Nuit quand le soleil passe sous l'horizon ; aube et crépuscule autour.
	night = smoothstep(2.0, -10.0, sun_el)
	var dusk := 1.0 - smoothstep(3.0, 22.0, sun_el)
	glow = smoothstep(0.25, 0.9, night)
	RenderingServer.global_shader_parameter_set("night", glow)
	# Soleil : éclaire tant qu'il est levé, s'éteint en se couchant.
	var sun_k := smoothstep(-3.0, 6.0, sun_el)
	# Nuages : le soleil se voile, la lumière s'aplatit, le ciel grisonne ; pluie et
	# brouillard épaississent la brume.
	var cl: float = weather.clouds if weather else 0.0
	var wfog: float = weather.fog if weather else 0.0
	var wrain: float = weather.rain if weather else 0.0
	sun.visible = sun_k > 0.001
	if sun.visible:
		sun.light_color = (DAY["sun_color"] as Color).lerp(DUSK["sun_color"], dusk).lerp(Color(0.85, 0.87, 0.9), cl * 0.6)
		sun.light_energy = lerpf(DAY["sun_energy"], DUSK["sun_energy"], dusk) * sun_k * (1.0 - 0.62 * cl)
		sun.look_at_from_position(Vector3.ZERO, -sd, Vector3.UP)
	# Lune : prend le relais la nuit (éteinte de jour).
	var moon_k := smoothstep(-3.0, 8.0, moon_el) * night
	moon.visible = moon_k > 0.001
	if moon.visible:
		moon.light_energy = NIGHT["sun_energy"] * moon_k
		moon.look_at_from_position(Vector3.ZERO, -md, Vector3.UP)
	# Reflet sur l'eau : le soleil, ou la lune la nuit (voilés par les nuages, sans
	# disparaître : on voit encore la tache claire derrière un ciel couvert).
	var veil := 1.0 - 0.5 * cl
	if sun_k > 0.001:
		RenderingServer.global_shader_parameter_set("sun_dir", sd)
		var sc: Color = sun.light_color
		var sk := sun_k * veil * lerpf(1.0, 1.4, dusk)
		RenderingServer.global_shader_parameter_set("sun_glint", Vector3(sc.r, sc.g, sc.b) * sk)
	elif moon_k > 0.001:
		RenderingServer.global_shader_parameter_set("sun_dir", md)
		var mc: Color = moon.light_color
		RenderingServer.global_shader_parameter_set("sun_glint", Vector3(mc.r, mc.g, mc.b) * moon_k * veil * 0.75)
	else:
		RenderingServer.global_shader_parameter_set("sun_glint", Vector3.ZERO)
	env.ambient_light_color = (_mix("ambient", dusk, night) as Color).lerp(Color(0.62, 0.64, 0.7) * (1.0 - night * 0.7), cl * 0.5)
	_base_ambient = _mix("ambient_energy", dusk, night) * (1.0 + 0.35 * cl)
	env.ambient_light_energy = _base_ambient
	sky.sky_top_color = _grey(_mix("sky_top", dusk, night), cl * 0.8)
	sky.sky_horizon_color = _grey(_mix("sky_horizon", dusk, night), cl * 0.7)
	sky.ground_horizon_color = _grey(_mix("ground_horizon", dusk, night), cl * 0.6)
	sky.ground_bottom_color = _grey(_mix("ground_bottom", dusk, night), cl * 0.6)
	sky.sun_angle_max = lerpf(20.0, 4.0, night)
	var thick := clampf((fog_amount - 1.0) / 3.0, 0.0, 1.0)
	var fog_grey := Color(0.78, 0.78, 0.8).lerp(Color(0.1, 0.1, 0.13), night)
	env.fog_enabled = fog_amount > 0.01
	env.fog_light_color = (_mix("fog", dusk, night) as Color).lerp(fog_grey, clampf(thick * 0.7 + cl * 0.5 + wfog * 0.4, 0.0, 1.0))
	# Pluie et brouillard épaississent la brume, mais modérément (la caméra est à 30-40 m
	# de la voiture) et moins la nuit, où une brume sombre ferait un mur noir.
	env.fog_density = _mix("fog_density", dusk, night) * fog_amount * (1.0 + (wfog * 1.5 + wrain * 0.4) * (1.0 - night * 0.6))
	env.fog_sky_affect = lerpf(0.35, 1.0, thick)
	# Ciel couvert : l'exposition compense en partie (comme l'œil qui s'adapte).
	env.tonemap_exposure = _mix("exposure", dusk, night) * (1.0 + 0.15 * cl)
	env.glow_enabled = not no_glow
	env.glow_intensity = _mix("glow", dusk, night)
	env.glow_bloom = _mix("glow_bloom", dusk, night)
	env.glow_hdr_threshold = _mix("glow_threshold", dusk, night)
	env.adjustment_contrast = _mix("contrast", dusk, night)
	env.adjustment_saturation = _mix("saturation", dusk, night)
	# Ombres du décor : cartes mélangées selon la position de la lumière (le soleil, ou la
	# lune la nuit, qui suit le même chemin douze heures plus tard) ; plus douces quand la
	# lumière est basse.
	var light_hour := hour if sd.y > -0.02 else fposmod(hour + 12.0, 24.0)
	RenderingServer.global_shader_parameter_set("shadow_mix", shadow_mix_at(light_hour))
	var low := smoothstep(2.0, 12.0, rad_to_deg(asin(light_direction().y)))
	for m in shadow_materials:
		(m as ShaderMaterial).set_shader_parameter("shadow_strength", _mix("shadow", dusk, night) * lerpf(0.4, 1.0, low))
	if _vignette:
		_vignette.modulate.a = _mix("vignette", dusk, night)
	# Couleur du ciel reflétée par les flaques.
	for m in shadow_materials:
		(m as ShaderMaterial).set_shader_parameter("sky_reflect", sky.sky_horizon_color.lerp(sky.sky_top_color, 0.4) * 0.7 * (1.0 - 0.55 * cl))


## Couleur grisée (ciel couvert) : vers sa luminance, un peu assombrie.
static func _grey(c: Color, k: float) -> Color:
	var l := c.get_luminance()
	return c.lerp(Color(l, l, l * 1.04) * 0.92, clampf(k, 0.0, 1.0))


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
