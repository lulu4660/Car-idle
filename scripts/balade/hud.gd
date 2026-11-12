## Affichage de la balade, dessiné en code dans le style du jeu (charbon, orange, or ; blocs
## et facettes comme le décor low poly), compact et animé :
## - compteur en haut au centre : arc de blocs qui s'allument avec une traînée lumineuse
##   (chaque bloc s'éteint doucement), bloc de tête qui brille, pulsation près de la vitesse
##   max ; balayage complet de l'aiguille à l'apparition ;
## - ligne d'infos discrète (sol, voiture, i/s, version, record) ;
## - dérapage : panneau qui surgit (rebond), points qui défilent, multiplicateur qui « saute »
##   à chaque palier, reflet qui balaie le panneau ; à la fin, les points s'envolent avec des
##   éclats facettés ; en cas de choc le panneau tremble et vire au rouge.
## Polices : Russo One et Rajdhani (SIL OFL, assets/fonts).
extends CanvasLayer

const Car = preload("res://scripts/balade/car.gd")
const WL = preload("res://scripts/core/world_layout.gd")
const Settings = preload("res://scripts/balade/settings.gd")

const CHARCOAL := Color(0.07, 0.065, 0.07, 0.58)
const INK := Color(0.96, 0.93, 0.88)
const GOLD := Color(1.0, 0.78, 0.25)
const ORANGE := Color(1.0, 0.52, 0.12)
const RED := Color(0.95, 0.2, 0.12)
const BLOCKS := 22
const ARC_FROM := deg_to_rad(150.0)
const ARC_SPAN := deg_to_rad(240.0)

var game: Node
var _canvas: Control
var _big: Font = load("res://assets/fonts/RussoOne-Regular.ttf")
var _text: Font = load("res://assets/fonts/Rajdhani-Bold.ttf")

var _time := 0.0
var _intro := 0.0               # 0 -> 1 à l'apparition
var _speed_shown := 0.0
var _block_glow: PackedFloat32Array = PackedFloat32Array()
var _gear_bump := 0.0

# Dérapage.
var _drift_points := 0.0
var _points_shown := 0.0
var _drift_mult := 1
var _mult_bump := 0.0           # 1 au changement de palier, retombe
var _drift_time := 0.0
var _grace := 0.0
var _panel := 0.0               # 0..1 : apparition du panneau
var _panel_t := 0.0             # temps depuis l'apparition
var _fail := 0.0                # 1 au choc, retombe (tremblement, rouge)
var _best := 0
var _record_flash := 0.0
var _last_speed := 0.0
var _slip_shown := 0.0
# Points qui s'envolent : [texte, couleur, âge].
var _pops: Array = []
# Éclats : [position, vitesse, rotation, vitesse de rotation, âge, durée, couleur, taille].
var _shards: Array = []


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_block_glow.resize(BLOCKS)


func _process(delta: float) -> void:
	var car: VehicleBody3D = game.car if game else null
	if car == null or not is_instance_valid(car):
		return
	_time += delta
	_intro = minf(1.0, _intro + delta / 1.4)
	_speed_shown = lerpf(_speed_shown, car.speed_kmh, minf(1.0, delta * 8.0))
	_update_blocks(car, delta)
	_update_drift(car, delta)
	_update_fx(delta)
	_gear_bump = move_toward(_gear_bump, 0.0, delta * 4.0)
	_canvas.queue_redraw()


func _update_blocks(car: VehicleBody3D, delta: float) -> void:
	var top: float = ceilf(car.top_speed_kmh / 20.0) * 20.0
	var k := clampf(_speed_shown / top, 0.0, 1.0)
	# À l'apparition : l'arc se remplit puis redescend (balayage d'aiguille).
	if _intro < 1.0:
		k = maxf(k, sin(_intro * PI))
	var lit := k * BLOCKS
	for i in BLOCKS:
		var want := clampf(lit - i, 0.0, 1.0)
		# S'allume vite, s'éteint lentement : une traînée lumineuse quand la vitesse baisse.
		var rate := 18.0 if want > _block_glow[i] else 3.5
		_block_glow[i] = move_toward(_block_glow[i], want, delta * rate)


func _update_drift(car: VehicleBody3D, delta: float) -> void:
	var slip: float = absf(car.slip_angle)
	var kmh: float = car.speed_kmh
	_slip_shown = lerpf(_slip_shown, car.slip_angle, minf(1.0, delta * 8.0))
	var drifting: bool = slip > 12.0 and kmh > 25.0 and not car.in_water
	# Choc : la vitesse chute bien plus vite qu'au freinage (> 70 km/h par seconde).
	var crash: bool = delta > 0.0 and (_last_speed - kmh) / delta > 70.0 and _last_speed - kmh > 3.0
	_last_speed = kmh
	if _drift_points > 0.0 and crash:
		_pops.append(["RATÉ", RED, 0.0])
		_fail = 1.0
		_burst(RED, 10)
		_reset_drift()
	elif drifting:
		_grace = 0.0
		_drift_time += delta
		var m := mini(5, 1 + int(_drift_time / 2.0))
		if m != _drift_mult:
			_drift_mult = m
			_mult_bump = 1.0
		_drift_points += slip * kmh * 0.05 * _drift_mult * delta
	elif _drift_points > 0.0:
		_grace += delta
		if _grace > 0.9:
			var gained := roundi(_drift_points)
			if gained >= 50:
				_pops.append(["+" + _thousands(gained), GOLD, 0.0])
				if game.audio:
					game.audio.shot("score", 0.7)
				_burst(GOLD, 14 + _drift_mult * 4)
				if gained > _best:
					_best = gained
					_record_flash = 1.0
			_reset_drift()
	var want := 1.0 if _drift_points > 0.0 else 0.0
	if want > 0.0 and _panel <= 0.0:
		_panel_t = 0.0
	_panel = move_toward(_panel, want, delta * (3.0 if want > 0.0 else 4.0))
	_panel_t += delta
	_points_shown = lerpf(_points_shown, _drift_points, minf(1.0, delta * 10.0)) if _drift_points > 0.0 else _points_shown
	_mult_bump = move_toward(_mult_bump, 0.0, delta * 2.5)
	_fail = move_toward(_fail, 0.0, delta * 1.6)
	_record_flash = move_toward(_record_flash, 0.0, delta * 0.5)


func _reset_drift() -> void:
	_drift_points = 0.0
	_drift_time = 0.0
	_drift_mult = 1
	_grace = 0.0


func _update_fx(delta: float) -> void:
	for p in _pops:
		p[2] += delta
	_pops = _pops.filter(func(p: Array) -> bool: return p[2] < 1.6)
	for s in _shards:
		s[1] = (s[1] as Vector2) + Vector2(0, 260.0) * delta
		s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
		s[2] += s[3] * delta
		s[4] += delta
	_shards = _shards.filter(func(s: Array) -> bool: return s[4] < s[5])


## Éclats facettés autour du panneau de dérapage.
func _burst(col: Color, n: int) -> void:
	var size := _canvas.get_viewport_rect().size
	var u := minf(size.x, size.y)
	var c := _drift_anchor(size, u) + Vector2(0, u * 0.05)
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.25, 0.7) * u
		var tint := col.lerp(INK, randf() * 0.4)
		_shards.append([c, Vector2(cos(a), sin(a) - 0.6) * sp, randf() * TAU, randf_range(-8.0, 8.0), 0.0, randf_range(0.6, 1.1), tint, randf_range(0.008, 0.016) * u])


# ------------------------------------------------------------------ dessin

func _draw_hud() -> void:
	var car: VehicleBody3D = game.car if game else null
	if car == null or not is_instance_valid(car):
		return
	var size := _canvas.get_viewport_rect().size
	var u := minf(size.x, size.y)
	var r := u * 0.088
	# Apparition : le compteur descend du haut avec un léger rebond.
	var drop := (1.0 - _ease_out_back(clampf(_intro * 1.6, 0.0, 1.0))) * -r * 2.6
	var c := Vector2(size.x * 0.5, u * 0.028 + r + drop)
	_draw_gauge(c, r, car)
	_draw_info(Vector2(size.x * 0.5, c.y + r * 1.18), u, car)
	_draw_drift(size, u, car)
	_draw_fx(size, u)


func _draw_gauge(c: Vector2, r: float, car: VehicleBody3D) -> void:
	var top: float = ceilf(car.top_speed_kmh / 20.0) * 20.0
	var redline: bool = car.rpm > 0.92
	var pulse := 0.5 + 0.5 * sin(_time * 14.0) if redline else 0.0
	# Fond : disque charbon à facettes.
	var bg := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + PI / 10.0
		bg.append(c + Vector2(cos(a), sin(a)) * r * 1.1)
	_canvas.draw_colored_polygon(bg, CHARCOAL)
	_canvas.draw_polyline(bg + PackedVector2Array([bg[0]]), Color(1, 1, 1, 0.1), 1.0, true)
	var outer := r * 0.96
	var inner := r * 0.78
	var gap := ARC_SPAN / BLOCKS * 0.24
	var lead := -1
	for i in BLOCKS:
		if _block_glow[i] > 0.5:
			lead = i
	for i in BLOCKS:
		var a0 := ARC_FROM + ARC_SPAN * i / BLOCKS + gap * 0.5
		var a1 := ARC_FROM + ARC_SPAN * (i + 1) / BLOCKS - gap * 0.5
		var t := float(i) / (BLOCKS - 1)
		var g := _block_glow[i]
		var heat := GOLD.lerp(ORANGE, smoothstep(0.0, 0.6, t)).lerp(RED, smoothstep(0.72, 1.0, t))
		if redline and g > 0.0:
			heat = heat.lerp(Color(1, 0.9, 0.8), pulse * 0.5)
		var col := Color(1, 1, 1, 0.09).lerp(heat, g)
		var o := outer + (r * 0.07 if i == lead else 0.0)
		_canvas.draw_colored_polygon(_sector(c, inner, o, a0, a1), col)
		# Halo doux autour du bloc de tête.
		if i == lead:
			var am := (a0 + a1) * 0.5
			var hp := c + Vector2(cos(am), sin(am)) * (inner + o) * 0.5
			for k in 3:
				_canvas.draw_circle(hp, r * (0.1 + 0.07 * k), Color(heat.r, heat.g, heat.b, 0.16 - 0.045 * k))
	# Vitesse.
	var v := str(roundi(_speed_shown))
	_text_center(_big, v, c + Vector2(0, r * 0.2), int(r * 0.66), INK, r * 0.05)
	_text_center(_text, "KM/H", c + Vector2(0, r * 0.44), int(r * 0.2), Color(INK.r, INK.g, INK.b, 0.55), 0.0)
	# Rapport engagé, au-dessus de la vitesse ; il « saute » à chaque changement.
	if car.shifted:
		_gear_bump = 1.0
	var gt := "R" if car.gear == 0 else str(car.gear)
	var gcol := GOLD.lerp(Color.WHITE, _gear_bump * 0.8)
	_text_scaled(_big, gt, c + Vector2(0, -r * 0.3), int(r * 0.26), 1.0 + 0.5 * _gear_bump, gcol, r * 0.03)
	# Mode : petite pastille dans l'ouverture de l'arc.
	var drift_mode: bool = game.settings.mode == 0
	var pill := Rect2(c + Vector2(-r * 0.4, r * 0.66), Vector2(r * 0.8, r * 0.26))
	_slanted(pill, ORANGE if drift_mode else GOLD, r * 0.08)
	_text_center(_text, Settings.MODES[game.settings.mode], pill.get_center() + Vector2(0, r * 0.075), int(r * 0.21), Color(0.08, 0.06, 0.05), 0.0)


func _draw_info(top_center: Vector2, u: float, car: VehicleBody3D) -> void:
	var ground: String = "Eau" if car.in_water else WL.SURFACE_NAMES[car.wheel_surface[2]]
	var parts: Array[String] = [
		ground.to_upper(),
		String(Car.DISPLAY_NAMES.get(car.model_name, car.model_name)).to_upper(),
		"%d I/S" % Engine.get_frames_per_second(),
		"V" + String(game.VERSION),
	]
	var t := " · ".join(parts)
	var fs := maxi(10, int(u * 0.024))
	var a := 0.55 * clampf(_intro * 2.0 - 0.6, 0.0, 1.0)
	_text_center(_text, t, top_center + Vector2(0, fs * 0.9), fs, Color(INK.r, INK.g, INK.b, a), fs * 0.25)
	# Temps par image, en plus petit sur une seconde ligne.
	var pt := _perf_text()
	if pt != "":
		_text_center(_text, pt, top_center + Vector2(0, fs * 1.95), int(fs * 0.85), Color(INK.r, INK.g, INK.b, a * 0.8), fs * 0.2)
	if _best > 0:
		var rc := GOLD.lerp(INK, 0.3)
		var bt := "RECORD " + _thousands(_best)
		var bump := 1.0 + 0.35 * _ease_out_back(_record_flash) * _record_flash
		_text_scaled(_text, bt, top_center + Vector2(0, fs * 3.1), fs, bump, Color(rc.r, rc.g, rc.b, 0.7 + 0.3 * _record_flash), fs * 0.25)


func _drift_anchor(size: Vector2, u: float) -> Vector2:
	# Sous la rangée de boutons du haut en portrait, sous le compteur en paysage.
	var portrait := size.x < size.y
	return Vector2(size.x * 0.5, u * (0.33 if portrait else 0.3))


func _draw_drift(size: Vector2, u: float, car: VehicleBody3D) -> void:
	if _panel <= 0.001:
		return
	var anchor := _drift_anchor(size, u)
	# Apparition avec rebond, disparition en glissant vers le haut.
	var e := _ease_out_back(_panel)
	var al := clampf(_panel * 1.5, 0.0, 1.0)
	var shake := sin(_time * 70.0) * u * 0.012 * _fail
	var w := u * 0.44
	var h := u * 0.105
	var scale := lerpf(0.7, 1.0, e)
	# Tout le panneau est dessiné à taille fixe puis agrandi par une transformation : les
	# polices gardent une taille constante (une nouvelle taille de police à chaque image
	# oblige à redessiner les lettres, coûteux sur la version web).
	var base := Transform2D(0.0, Vector2(scale, scale), 0.0, anchor + Vector2(shake, (1.0 - _panel) * -u * 0.03))
	_canvas.draw_set_transform_matrix(base)
	var box := Rect2(Vector2(-w * 0.5, 0.0), Vector2(w, h))
	var bg := CHARCOAL.lerp(Color(0.45, 0.05, 0.03, 0.7), _fail)
	_slanted(box, Color(bg.r, bg.g, bg.b, bg.a * al), u * 0.022)
	# Reflet qui balaie le panneau pendant la glisse.
	var sweep := fmod(_panel_t * 0.7, 1.6) - 0.3
	if sweep > -0.2 and sweep < 1.2:
		var x := box.position.x + box.size.x * sweep
		var band := PackedVector2Array([
			Vector2(x, box.position.y), Vector2(x + u * 0.03, box.position.y),
			Vector2(x + u * 0.03 - u * 0.022, box.end.y), Vector2(x - u * 0.022, box.end.y)])
		var clipped := Geometry2D.intersect_polygons(band, _slanted_points(box, u * 0.022))
		for poly in clipped:
			_canvas.draw_colored_polygon(poly, Color(1, 1, 1, 0.07 * al))
	# Liseré orange en bas.
	var line_y := box.end.y - 2.0
	_canvas.draw_line(Vector2(box.position.x + u * 0.01, line_y), Vector2(box.end.x - u * 0.03, line_y), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.8 * al), 2.0)
	var pad := u * 0.03
	# Titre.
	var tfs := int(u * 0.026)
	_canvas.draw_string(_text, box.position + Vector2(pad + u * 0.01, tfs * 1.15), "DÉRAPAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(ORANGE.r, ORANGE.g, ORANGE.b, al))
	# Multiplicateur : saute et flashe à chaque palier (agrandi autour de son centre).
	var mt := "×%d" % _drift_mult
	var mfs := int(u * 0.04)
	var mw := _big.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
	var mcol := GOLD.lerp(RED, (_drift_mult - 1) / 4.0).lerp(Color.WHITE, _mult_bump * 0.7)
	var mc := Vector2(box.end.x - pad - u * 0.012 - mw * 0.5, box.position.y + h * 0.5)
	var mb := 1.0 + 0.5 * _mult_bump
	_canvas.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(mb, mb), 0.0, mc))
	_canvas.draw_string_outline(_big, Vector2(-mw * 0.5, 0.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, int(u * 0.006), Color(0, 0, 0, 0.4 * al))
	_canvas.draw_string(_big, Vector2(-mw * 0.5, 0.0), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color(mcol.r, mcol.g, mcol.b, al))
	_canvas.draw_set_transform_matrix(base)
	# Points qui défilent.
	var pfs := int(u * 0.042)
	_canvas.draw_string(_big, box.position + Vector2(pad + u * 0.006, h * 0.66), _thousands(roundi(_points_shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(INK.r, INK.g, INK.b, al))
	# Jauge d'angle depuis le centre, avec une pointe lumineuse.
	var bar := Rect2(box.position + Vector2(pad + u * 0.006, h - u * 0.022), Vector2(box.size.x - pad * 2.0 - u * 0.03, u * 0.008))
	_canvas.draw_rect(bar, Color(1, 1, 1, 0.12 * al))
	var f := clampf(absf(_slip_shown) / maxf(car.max_drift_deg, 1.0), 0.0, 1.0)
	var half := bar.size.x * 0.5
	var mid := bar.position.x + half
	var fw := half * f
	var x0 := mid if _slip_shown < 0.0 else mid - fw
	var heat := GOLD.lerp(RED, smoothstep(0.5, 1.0, f))
	_canvas.draw_rect(Rect2(Vector2(x0, bar.position.y), Vector2(fw, bar.size.y)), Color(heat.r, heat.g, heat.b, al))
	var tip := Vector2(mid + (fw if _slip_shown < 0.0 else -fw), bar.get_center().y)
	for k in 2:
		_canvas.draw_circle(tip, u * (0.008 + 0.006 * k), Color(heat.r, heat.g, heat.b, (0.35 - 0.15 * k) * al))
	_canvas.draw_rect(Rect2(Vector2(mid - 1.0, bar.position.y - u * 0.004), Vector2(2.0, bar.size.y + u * 0.008)), Color(1, 1, 1, 0.55 * al))
	var at := "%d°" % roundi(absf(_slip_shown))
	var afs := int(u * 0.024)
	var aw := _text.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
	_canvas.draw_string(_text, Vector2(bar.end.x - aw, bar.position.y - u * 0.008), at, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Color(INK.r, INK.g, INK.b, 0.6 * al))
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_fx(size: Vector2, u: float) -> void:
	var anchor := _drift_anchor(size, u)
	for p in _pops:
		var k: float = p[2] / 1.6
		var col: Color = p[1]
		var a := 1.0 - smoothstep(0.55, 1.0, k)
		var pop := _ease_out_back(clampf(k * 4.0, 0.0, 1.0))
		var y := anchor.y + u * 0.06 - _ease_out(k) * u * 0.07
		_text_scaled(_big, p[0], Vector2(anchor.x, y), int(u * 0.05), lerpf(0.5, 1.0, pop), Color(col.r, col.g, col.b, a), u * 0.006)
	for s in _shards:
		var k: float = s[4] / s[5]
		var col: Color = s[6]
		var sz: float = s[7] * (1.0 - k * 0.6)
		var rot: float = s[2]
		var c: Vector2 = s[0]
		var pts := PackedVector2Array()
		for i in 4:
			var a := rot + TAU * i / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * sz * (1.0 if i % 2 == 0 else 0.55))
		_canvas.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 1.0 - k))


# ------------------------------------------------------------------ outils

func _sector(c: Vector2, r0: float, r1: float, a0: float, a1: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(cos(a0), sin(a0)) * r0, c + Vector2(cos(a0), sin(a0)) * r1,
		c + Vector2(cos(a1), sin(a1)) * r1, c + Vector2(cos(a1), sin(a1)) * r0])


func _slanted_points(r: Rect2, slant: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(slant, 0), Vector2(r.position.x, r.end.y)])


## Bandeau incliné (parallélogramme), le motif des pastilles du jeu.
func _slanted(r: Rect2, col: Color, slant: float) -> void:
	_canvas.draw_colored_polygon(_slanted_points(r, slant), col)


func _text_center(font: Font, t: String, baseline_center: Vector2, fs: int, col: Color, outline: float) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := baseline_center - Vector2(w * 0.5, 0)
	if outline > 0.0:
		_canvas.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, int(outline)), Color(0, 0, 0, 0.45 * col.a))
	_canvas.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Texte centré agrandi par une transformation (police à taille fixe).
func _text_scaled(font: Font, t: String, baseline_center: Vector2, fs: int, scale: float, col: Color, outline: float) -> void:
	_canvas.draw_set_transform(baseline_center, 0.0, Vector2(scale, scale))
	_text_center(font, t, Vector2.ZERO, fs, col, outline)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x := t - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Où part le temps d'une image (pour trouver ce qui ralentit) : scripts, physique, et
## dessin côté processeur et côté carte graphique, en millisecondes.
var _perf_on := false
var _perf_acc := Vector4.ZERO
var _perf_n := 0
var _perf_label := ""


func _perf_text() -> String:
	var vp := _canvas.get_viewport()
	if not _perf_on:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
		_perf_on = true
	_perf_acc += Vector4(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()))
	_perf_n += 1
	if _perf_n >= 30:
		var a := _perf_acc / _perf_n
		_perf_label = "IMAGE %.1f · PHYS %.1f · DESSIN %.1f · GPU %.1f MS" % [a.x, a.y, a.z, a.w]
		_perf_acc = Vector4.ZERO
		_perf_n = 0
	return _perf_label
