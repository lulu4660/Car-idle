## Affichage de la balade, dessiné en code dans le style du jeu (charbon, orange, or ; blocs
## et facettes comme le décor low poly) :
## - compteur en haut au centre : arc de blocs qui se remplissent de l'or au rouge, vitesse
##   en gros chiffres, mode de conduite dans une pastille ;
## - ligne d'infos sous le compteur (sol, voiture, transmission, caméra, images/s, version) ;
## - dérapage : angle en jauge, points qui montent avec l'angle et la vitesse, multiplicateur
##   qui grimpe si l'on tient la glisse ; les points sont gagnés quand la glisse finit, perdus
##   en cas de choc ; meilleur score de la session.
## Polices : Russo One et Rajdhani (SIL OFL, assets/fonts).
extends CanvasLayer

const Car = preload("res://scripts/balade/car.gd")
const WL = preload("res://scripts/core/world_layout.gd")
const Settings = preload("res://scripts/balade/settings.gd")

const CHARCOAL := Color(0.07, 0.065, 0.07, 0.62)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.62)
const GOLD := Color(1.0, 0.78, 0.25)
const ORANGE := Color(1.0, 0.52, 0.12)
const RED := Color(0.95, 0.2, 0.12)
const BLOCKS := 26
const ARC_FROM := deg_to_rad(150.0)   # angle (0 = droite, sens horaire à l'écran)
const ARC_SPAN := deg_to_rad(240.0)

var game: Node
var _canvas: Control
var _big: Font = load("res://assets/fonts/RussoOne-Regular.ttf")
var _text: Font = load("res://assets/fonts/Rajdhani-Bold.ttf")

# Affichage lissé.
var _speed_shown := 0.0
# Dérapage.
var _drift_points := 0.0
var _drift_mult := 1
var _drift_time := 0.0
var _grace := 0.0
var _show := 0.0          # 0..1 : panneau de dérapage visible
var _best := 0
var _pop_text := ""
var _pop_color := GOLD
var _pop_t := 9.0
var _last_speed := 0.0
var _slip_shown := 0.0


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(delta: float) -> void:
	var car: VehicleBody3D = game.car if game else null
	if car == null or not is_instance_valid(car):
		return
	_speed_shown = lerpf(_speed_shown, car.speed_kmh, minf(1.0, delta * 10.0))
	_update_drift(car, delta)
	_canvas.queue_redraw()


func _update_drift(car: VehicleBody3D, delta: float) -> void:
	var slip: float = absf(car.slip_angle)
	var kmh: float = car.speed_kmh
	_slip_shown = lerpf(_slip_shown, car.slip_angle, minf(1.0, delta * 8.0))
	var drifting: bool = slip > 12.0 and kmh > 25.0 and not car.in_water
	# Choc : la vitesse chute bien plus vite qu'au freinage (> 70 km/h par seconde)
	# pendant une glisse -> points perdus.
	var crash: bool = delta > 0.0 and (_last_speed - kmh) / delta > 70.0 and _last_speed - kmh > 3.0
	_last_speed = kmh
	if _drift_points > 0.0 and crash:
		_pop("RATÉ !", RED)
		_reset_drift()
		return
	if drifting:
		_grace = 0.0
		_drift_time += delta
		_drift_mult = mini(5, 1 + int(_drift_time / 2.0))
		_drift_points += slip * kmh * 0.05 * _drift_mult * delta
	elif _drift_points > 0.0:
		_grace += delta
		if _grace > 0.9:
			var gained := roundi(_drift_points)
			if gained >= 50:
				_pop("+" + _thousands(gained), GOLD)
				_best = maxi(_best, gained)
			_reset_drift()
	var want := 1.0 if _drift_points > 0.0 else 0.0
	_show = move_toward(_show, want, delta * 4.0)
	_pop_t += delta


func _reset_drift() -> void:
	_drift_points = 0.0
	_drift_time = 0.0
	_drift_mult = 1
	_grace = 0.0


func _pop(t: String, c: Color) -> void:
	_pop_text = t
	_pop_color = c
	_pop_t = 0.0


# ------------------------------------------------------------------ dessin

func _draw_hud() -> void:
	var car: VehicleBody3D = game.car if game else null
	if car == null or not is_instance_valid(car):
		return
	var size := _canvas.get_viewport_rect().size
	var u := minf(size.x, size.y)
	var portrait := size.x < size.y
	var r := u * (0.15 if portrait else 0.12)
	var c := Vector2(size.x * 0.5, u * 0.035 + r)
	_draw_gauge(c, r, car)
	var y := c.y + r * 0.98
	# En portrait, sous les boutons du haut (qui descendent jusqu'à 0,40 du petit côté).
	if portrait:
		y = maxf(y, u * 0.40)
	y = _draw_info(Vector2(size.x * 0.5, y), u, car)
	_draw_drift(Vector2(size.x * 0.5, y + u * 0.04), u, car)


func _draw_gauge(c: Vector2, r: float, car: VehicleBody3D) -> void:
	var top: float = ceilf(car.top_speed_kmh / 20.0) * 20.0
	var k := clampf(_speed_shown / top, 0.0, 1.0)
	# Fond : disque charbon facetté (polygone à 10 côtés, comme le décor low poly).
	var bg := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + PI / 10.0
		bg.append(c + Vector2(cos(a), sin(a)) * r * 1.08)
	_canvas.draw_colored_polygon(bg, CHARCOAL)
	_canvas.draw_polyline(bg + PackedVector2Array([bg[0]]), Color(1, 1, 1, 0.12), maxf(1.0, r * 0.015), true)
	# Arc de blocs.
	var outer := r * 0.95
	var inner := r * 0.78
	var gap := ARC_SPAN / BLOCKS * 0.22
	var lit := k * BLOCKS
	for i in BLOCKS:
		var a0 := ARC_FROM + ARC_SPAN * i / BLOCKS + gap * 0.5
		var a1 := ARC_FROM + ARC_SPAN * (i + 1) / BLOCKS - gap * 0.5
		var t := float(i) / (BLOCKS - 1)
		var col := Color(1, 1, 1, 0.1)
		var fill := clampf(lit - i, 0.0, 1.0)
		if fill > 0.0:
			var heat := GOLD.lerp(ORANGE, smoothstep(0.0, 0.6, t)).lerp(RED, smoothstep(0.7, 1.0, t))
			col = Color(1, 1, 1, 0.1).lerp(heat, fill)
		# Le bloc le plus haut s'allonge un peu vers l'extérieur (repère).
		var o := outer + (r * 0.06 if fill > 0.0 and i == int(lit) - 1 else 0.0)
		var quad := PackedVector2Array([
			c + Vector2(cos(a0), sin(a0)) * inner, c + Vector2(cos(a0), sin(a0)) * o,
			c + Vector2(cos(a1), sin(a1)) * o, c + Vector2(cos(a1), sin(a1)) * inner])
		_canvas.draw_colored_polygon(quad, col)
	# Graduations de 20 en 20 (petits traits à l'intérieur de l'arc).
	var steps := int(top / 20.0)
	for s in steps + 1:
		var a := ARC_FROM + ARC_SPAN * s / steps
		var d := Vector2(cos(a), sin(a))
		var major := s % 2 == 0
		_canvas.draw_line(c + d * inner * (0.84 if major else 0.9), c + d * inner * 0.96, Color(1, 1, 1, 0.55 if major else 0.3), maxf(1.0, r * (0.022 if major else 0.014)), true)
	# Vitesse.
	var v := str(roundi(_speed_shown))
	var fs := int(r * 0.62)
	_text_center(_big, v, c + Vector2(0, r * 0.16), fs, INK, r * 0.05)
	_text_center(_text, "KM/H", c + Vector2(0, r * 0.38), int(r * 0.2), DIM, 0.0)
	# Mode de conduite : pastille dans l'ouverture de l'arc.
	var mode: String = Settings.MODES[game.settings.mode]
	var pill := Rect2(c + Vector2(-r * 0.42, r * 0.6), Vector2(r * 0.84, r * 0.27))
	var drift_mode: bool = game.settings.mode == 0
	_slanted(pill, ORANGE if drift_mode else GOLD, r * 0.08)
	_text_center(_text, mode, pill.get_center() + Vector2(0, r * 0.085), int(r * 0.22), Color(0.08, 0.06, 0.05), 0.0)


## Ligne d'infos sous le compteur ; rend le bas de la ligne.
func _draw_info(top_center: Vector2, u: float, car: VehicleBody3D) -> float:
	var ground: String = "Eau" if car.in_water else WL.SURFACE_NAMES[car.wheel_surface[2]]
	var parts: Array[String] = [
		ground.to_upper(),
		String(Car.DISPLAY_NAMES.get(car.model_name, car.model_name)).to_upper(),
		Car.DRIVE_NAMES[car.drive].to_upper(),
		"%d I/S" % Engine.get_frames_per_second(),
		"V" + String(game.VERSION),
	]
	if _best > 0:
		parts.append("RECORD " + _thousands(_best))
	var t := "  ·  ".join(parts)
	var fs := maxi(11, int(u * 0.03))
	var w := _text.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := fs * 1.35
	var box := Rect2(top_center + Vector2(-w * 0.5 - fs * 0.8, h * 0.3), Vector2(w + fs * 1.6, h))
	_slanted(box, CHARCOAL, fs * 0.35)
	_text_center(_text, t, box.get_center() + Vector2(0, fs * 0.36), fs, DIM, 0.0)
	return box.end.y


func _draw_drift(top_center: Vector2, u: float, car: VehicleBody3D) -> void:
	# Points gagnés ou perdus : montent et s'effacent.
	if _pop_t < 1.4:
		var k := _pop_t / 1.4
		var a := 1.0 - smoothstep(0.6, 1.0, k)
		var grow := 1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.15, k))
		var col := Color(_pop_color.r, _pop_color.g, _pop_color.b, a)
		_text_center(_big, _pop_text, top_center + Vector2(0, u * 0.1 - k * u * 0.06), int(u * 0.08 * grow), col, u * 0.008)
	if _show <= 0.01:
		return
	var al := _show
	var w := u * 0.56
	var h := u * 0.16
	var box := Rect2(top_center + Vector2(-w * 0.5, 0), Vector2(w, h))
	_slanted(box, Color(CHARCOAL.r, CHARCOAL.g, CHARCOAL.b, CHARCOAL.a * al), u * 0.03)
	# Titre et multiplicateur.
	var fs := int(u * 0.034)
	_canvas.draw_string(_text, box.position + Vector2(u * 0.045, u * 0.045), "DÉRAPAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ORANGE.r, ORANGE.g, ORANGE.b, al))
	var mult_col := GOLD.lerp(RED, (_drift_mult - 1) / 4.0)
	var mt := "×%d" % _drift_mult
	var mfs := int(u * 0.05)
	var mw := _big.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
	_canvas.draw_string(_big, box.position + Vector2(w - u * 0.06 - mw, u * 0.058), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color(mult_col.r, mult_col.g, mult_col.b, al))
	# Points.
	_text_center(_big, _thousands(roundi(_drift_points)), box.position + Vector2(w * 0.5, u * 0.1), int(u * 0.055), Color(INK.r, INK.g, INK.b, al), u * 0.006)
	# Jauge d'angle : part du centre vers le côté de la glisse.
	var bar := Rect2(box.position + Vector2(u * 0.045, h - u * 0.035), Vector2(w - u * 0.09, u * 0.014))
	_canvas.draw_rect(bar, Color(1, 1, 1, 0.12 * al))
	var maxa: float = car.max_drift_deg
	var f := clampf(absf(_slip_shown) / maxa, 0.0, 1.0)
	var half := bar.size.x * 0.5
	var mid := bar.position.x + half
	var fill_w := half * f
	var x0 := mid if _slip_shown < 0.0 else mid - fill_w
	var heat := GOLD.lerp(RED, smoothstep(0.5, 1.0, f))
	_canvas.draw_rect(Rect2(Vector2(x0, bar.position.y), Vector2(fill_w, bar.size.y)), Color(heat.r, heat.g, heat.b, al))
	_canvas.draw_rect(Rect2(Vector2(mid - 1.0, bar.position.y - u * 0.006), Vector2(2.0, bar.size.y + u * 0.012)), Color(1, 1, 1, 0.6 * al))
	var at := "%d°" % roundi(absf(_slip_shown))
	var afs := int(u * 0.03)
	var aw := _text.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
	_canvas.draw_string(_text, Vector2(bar.end.x - aw, bar.position.y - u * 0.012), at, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Color(DIM.r, DIM.g, DIM.b, DIM.a * al))


# ------------------------------------------------------------------ outils

## Bandeau incliné (parallélogramme), le motif des boutons et pastilles du jeu.
func _slanted(r: Rect2, col: Color, slant: float) -> void:
	var p := PackedVector2Array([
		r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(slant, 0), Vector2(r.position.x, r.end.y)])
	_canvas.draw_colored_polygon(p, col)


func _text_center(font: Font, t: String, baseline_center: Vector2, fs: int, col: Color, outline: float) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := baseline_center - Vector2(w * 0.5, 0)
	if outline > 0.0:
		_canvas.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(outline), Color(0, 0, 0, 0.45 * col.a))
	_canvas.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
