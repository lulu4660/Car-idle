## Commandes de conduite : clavier (flèches ou ZQSD/WASD, espace = frein à main,
## R = replacer, C = voiture suivante, V = plan de caméra) et boutons tactiles multi-doigts
## (gauche/droite en bas à gauche, gaz/frein en bas à droite, dérapage au-dessus).
## La souris compte comme un doigt sur PC.
## Quatre façons de tourner, au choix dans RÉGLAGES > Commandes (comme dans les jeux de
## drift sur téléphone) : flèches, volant à l'écran (on le tourne au doigt, il revient au
## centre au lâcher), glisser (le doigt glisse à gauche ou à droite depuis là où il s'est
## posé) et inclinaison du téléphone (gyroscope, via le navigateur sur la version web).
extends CanvasLayer

enum SteerMode { ARROWS, WHEEL, SLIDE, TILT }
const MODE_NAMES: Array[String] = ["FLÈCHES", "VOLANT", "GLISSER", "INCLINAISON"]
var steer_mode := SteerMode.ARROWS
## Sensibilité de la direction (volant, glisser, inclinaison).
var sensitivity := 1.0
var tilt_invert := false
## Taille des boutons de conduite (1 = normale).
var button_scale := 1.0
const WHEEL_LOCK := 135.0       # degrés de volant pour braquer à fond (sensibilité 1)
var _wheel_angle := 0.0
var _wheel_touch := -1
var _wheel_grab := 0.0          # angle du doigt au moment de la prise
var _wheel_start := 0.0         # angle du volant au moment de la prise
var _slide_touch := -1
var _slide_origin := Vector2.ZERO
var _slide_pos := Vector2.ZERO
var _analog := 0.0
var _tilt_ready := false
var _overlay: Control

var throttle := 0.0
var brake := 0.0
var steer := 0.0
var handbrake := false
var reset_requested := false
var next_car_requested := false
var camera_requested := false
var night_requested := false
var settings_requested := false
var mode_requested := false

var _steer_smooth := 0.0

# Boutons : action, texte (vide = flèche dessinée), coin d'accroche (0/1 en x et y) et zone
# mesurée depuis ce coin, en fraction du petit côté de l'écran : même taille au doigt en
# portrait et en paysage, rien ne se chevauche sur un téléphone tenu droit.
const BUTTONS := [
	["ci_left", "", Vector2(0, 1), Rect2(0.035, 0.035, 0.17, 0.2)],
	["ci_right", "", Vector2(0, 1), Rect2(0.215, 0.035, 0.17, 0.2)],
	["ci_gas", "GAZ", Vector2(1, 1), Rect2(0.035, 0.035, 0.19, 0.24)],
	["ci_brake", "FREIN", Vector2(1, 1), Rect2(0.24, 0.035, 0.16, 0.15)],
	["ci_drift", "DÉRAPAGE", Vector2(1, 1), Rect2(0.035, 0.29, 0.19, 0.095)],
	["ci_reset", "REPLACER", Vector2(0, 0), Rect2(0.025, 0.025, 0.2, 0.072)],
	["ci_night", "NUIT", Vector2(0, 0), Rect2(0.025, 0.107, 0.2, 0.072)],
	# Petit bouton façon « ESP » : allume ou coupe le mode Drift (icône dessinée).
	["ci_mode", "", Vector2(0, 0), Rect2(0.025, 0.189, 0.09, 0.072)],
	["ci_camera", "CAMÉRA", Vector2(1, 0), Rect2(0.025, 0.025, 0.2, 0.072)],
	["ci_car", "VOITURE", Vector2(1, 0), Rect2(0.025, 0.107, 0.2, 0.072)],
	["ci_settings", "RÉGLAGES", Vector2(1, 0), Rect2(0.025, 0.189, 0.2, 0.072)],
]

const KEYS := {
	"ci_left": [KEY_LEFT, KEY_A, KEY_Q],
	"ci_right": [KEY_RIGHT, KEY_D],
	"ci_gas": [KEY_UP, KEY_W, KEY_Z],
	"ci_brake": [KEY_DOWN, KEY_S],
	"ci_drift": [KEY_SPACE],
	"ci_reset": [KEY_R],
	"ci_camera": [KEY_V],
	"ci_car": [KEY_C],
	"ci_night": [KEY_N],
	"ci_settings": [KEY_ESCAPE, KEY_P],
	"ci_mode": [KEY_G],
}

var _buttons: Array[TouchScreenButton] = []
const FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")
var _mouse_action := ""


func _ready() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in KEYS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)
	for b in BUTTONS:
		var t := TouchScreenButton.new()
		t.action = b[0]
		t.passby_press = true
		t.set_meta("corner", b[2])
		t.set_meta("zone", b[3])
		t.set_meta("arrow", -1 if b[0] == "ci_left" else (1 if b[0] == "ci_right" else 0))
		var lbl := Label.new()
		lbl.text = b[1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FONT)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88, 0.95))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
		lbl.add_theme_constant_override("outline_size", 3)
		t.add_child(lbl)
		add_child(t)
		_buttons.append(t)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	for t in _buttons:
		var corner: Vector2 = t.get_meta("corner")
		var z: Rect2 = t.get_meta("zone")
		if corner.y == 1:
			z = Rect2(z.position * button_scale, z.size * button_scale)
		var bs := z.size * u
		var x := z.position.x * u if corner.x == 0 else size.x - (z.position.x + z.size.x) * u
		var y := z.position.y * u if corner.y == 0 else size.y - (z.position.y + z.size.y) * u
		t.position = Vector2(x, y)
		t.set_meta("base", Vector2(x, y))
		t.set_meta("size", bs)
		var arrow: int = t.get_meta("arrow")
		# Zone tactile un peu plus grande que le bouton dessiné (un doigt un peu à côté compte).
		var hit := RectangleShape2D.new()
		hit.size = bs * Vector2(1.08, 1.2)
		t.shape = hit
		t.shape_centered = true
		t.shape_visible = false
		if t.action == "ci_mode":
			_mode_textures(t, Vector2i(bs))
			continue
		t.texture_normal = _box(Vector2i(bs), Color(0.07, 0.065, 0.07, 0.42), arrow)
		t.texture_pressed = _box(Vector2i(bs), Color(1.0, 0.52, 0.12, 0.85), arrow)
		var lbl := t.get_child(0) as Label
		lbl.size = bs
		var small: bool = z.size.y < 0.1
		lbl.add_theme_font_size_override("font_size", maxi(11, int(u * (0.03 if small else 0.036))))
		# Flèches seulement en mode flèches.
		if t.action == "ci_left" or t.action == "ci_right":
			t.visible = steer_mode == SteerMode.ARROWS


## Fond du bouton (cadre) ; `arrow` = -1 ou 1 : flèche gauche ou droite dessinée dedans
## (les caractères ◀ ▶ manquent dans la police de la version web).
func _box(s: Vector2i, c: Color, arrow := 0) -> ImageTexture:
	s = s.max(Vector2i(8, 8))
	var img := Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Coins coupés (facettes, comme le décor low poly), liseré clair, trait orange en bas.
	var cut := int(minf(s.x, s.y) * 0.22)
	var rim := Color(1, 1, 1, 0.22)
	var accent := Color(1.0, 0.52, 0.12, 0.9)
	for y in s.y:
		for x in s.x:
			var dx := mini(x, s.x - 1 - x)
			var dy := mini(y, s.y - 1 - y)
			var d := dx + dy - cut
			if d < 0:
				continue
			var edge := mini(mini(dx, dy), d)
			var col := c
			if edge < 2:
				col = rim if c.a < 0.6 else Color(1, 0.8, 0.5, 0.9)
			elif s.y - 1 - y < 6 and dx > cut and c.a < 0.6:
				col = accent
			img.set_pixel(x, y, col)
	if arrow != 0:
		var half := minf(s.x, s.y) * 0.2
		var cx := s.x * 0.5
		var cy := s.y * 0.5
		var ink := Color(0.96, 0.93, 0.88, 0.95)
		for y in range(int(cy - half), int(cy + half) + 1):
			var span := half * (1.0 - absf(y - cy) / half) * 1.5
			for x in range(int(cx - half * 0.7), int(cx - half * 0.7 + span) + 1):
				var xx := x if arrow > 0 else int(2.0 * cx) - x
				if xx >= 0 and xx < s.x and y >= 0 and y < s.y:
					img.set_pixel(xx, y, ink)
	return ImageTexture.create_from_image(img)


## La souris joue le rôle d'un doigt (PC) : bouton pressé sous le pointeur.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_action = _action_at(event.position)
			if _mouse_action != "":
				Input.action_press(_mouse_action)
		elif _mouse_action != "":
			Input.action_release(_mouse_action)
			_mouse_action = ""


func _action_at(p: Vector2) -> String:
	for t in _buttons:
		if t.visible and Rect2(t.position, t.texture_normal.get_size()).has_point(p):
			return t.action
	return ""


func _process(delta: float) -> void:
	_animate(delta)
	var keys := Input.get_action_strength("ci_right") - Input.get_action_strength("ci_left")
	match steer_mode:
		SteerMode.WHEEL:
			if _wheel_touch == -1:
				# Le volant revient seul au centre quand on le lâche.
				_wheel_angle = move_toward(_wheel_angle, 0.0, delta * 540.0)
			_analog = clampf(_wheel_angle / (WHEEL_LOCK / sensitivity), -1.0, 1.0)
		SteerMode.SLIDE:
			_analog = 0.0
			if _slide_touch != -1:
				var u := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y)
				_analog = clampf((_slide_pos.x - _slide_origin.x) / (u * 0.17) * sensitivity, -1.0, 1.0)
		SteerMode.TILT:
			_analog = _read_tilt()
		_:
			_analog = 0.0
	if steer_mode == SteerMode.ARROWS or absf(keys) > 0.01:
		# Le volant revient plus vite au centre qu'il ne braque : plus facile au doigt.
		var rate := 4.0 if absf(keys) > absf(_steer_smooth) else 7.0
		_steer_smooth = move_toward(_steer_smooth, keys, rate * delta)
	else:
		# Direction analogique : suit le doigt (ou le téléphone) presque directement.
		_steer_smooth = lerpf(_steer_smooth, _analog, minf(1.0, delta * 18.0))
	steer = _steer_smooth
	_overlay.queue_redraw()
	throttle = Input.get_action_strength("ci_gas")
	brake = Input.get_action_strength("ci_brake")
	handbrake = Input.is_action_pressed("ci_drift")
	reset_requested = Input.is_action_just_pressed("ci_reset")
	next_car_requested = Input.is_action_just_pressed("ci_car")
	camera_requested = Input.is_action_just_pressed("ci_camera")
	night_requested = Input.is_action_just_pressed("ci_night")
	settings_requested = Input.is_action_just_pressed("ci_settings")
	mode_requested = Input.is_action_just_pressed("ci_mode")


## Masque ou montre les boutons (écran des réglages) ; relâche tout ce qui était appuyé.
func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)
	for action in KEYS:
		Input.action_release(action)
	_mouse_action = ""
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	_steer_smooth = 0.0
	_wheel_touch = -1
	_slide_touch = -1
	handbrake = false
	settings_requested = false


## Appui : le bouton s'enfonce (ressort, léger rebond au relâché).
func _animate(delta: float) -> void:
	for t in _buttons:
		if not t.has_meta("base"):
			continue
		var want := 0.9 if t.is_pressed() else 1.0
		var v: float = t.get_meta("v", 0.0)
		var sc: float = t.scale.x
		v += ((want - sc) * 600.0 - v * 22.0) * delta
		sc += v * delta
		t.set_meta("v", v)
		t.scale = Vector2(sc, sc)
		var bs: Vector2 = t.get_meta("size")
		t.position = (t.get_meta("base") as Vector2) + bs * (1.0 - sc) * 0.5


## Bouton Drift : allumé (orange) quand le mode Drift est actif, éteint sinon ; l'icône
## (voiture et traces de glisse) reste lisible dans les deux états.
var drift_on := true


func set_drift_indicator(on: bool) -> void:
	drift_on = on
	for t in _buttons:
		if t.action == "ci_mode" and t.has_meta("size"):
			_mode_textures(t, Vector2i(t.get_meta("size")))


func _mode_textures(t: TouchScreenButton, bs: Vector2i) -> void:
	var off := Color(0.07, 0.065, 0.07, 0.42)
	var lit := Color(1.0, 0.52, 0.12, 0.85)
	t.texture_normal = _icon(bs, lit if drift_on else off, drift_on)
	t.texture_pressed = _icon(bs, off if drift_on else lit, not drift_on)
	(t.get_child(0) as Label).text = ""


## Icône : petite voiture vue de dessus, en biais, avec deux traces en S derrière elle.
func _icon(s: Vector2i, c: Color, lit: bool) -> ImageTexture:
	var img := _box(s, c).get_image()
	var ink := Color(0.08, 0.06, 0.05, 0.95) if lit else Color(0.96, 0.93, 0.88, 0.9)
	var w := float(s.x)
	var h := float(s.y)
	var cx := w * 0.5
	var cy := h * 0.4
	var ang := -0.5
	var ca := cos(ang)
	var sa := sin(ang)
	var hw := w * 0.13
	var hl := h * 0.22
	for y in s.y:
		for x in s.x:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var u := dx * ca + dy * sa
			var v := -dx * sa + dy * ca
			if absf(u) < hw and absf(v) < hl:
				img.set_pixel(x, y, ink)
	# Traces en S derrière la voiture.
	for k in [-1.0, 1.0]:
		for i in 60:
			var t2 := i / 59.0
			var px: float = cx + k * w * 0.12 + sin(t2 * PI * 2.0) * w * 0.07 - w * 0.04
			var py := cy + hl * 0.9 + t2 * h * 0.28
			for d in 2:
				var xx := int(px) + d
				var yy := int(py)
				if xx >= 0 and xx < s.x and yy >= 0 and yy < s.y:
					img.set_pixel(xx, yy, ink)
	return ImageTexture.create_from_image(img)


## Change le texte d'un bouton (ex. NUIT / JOUR).
func set_label(action: String, text: String) -> void:
	for t in _buttons:
		if t.action == action:
			(t.get_child(0) as Label).text = text


# ------------------------------------------------------------------ direction analogique

## Applique les réglages de commandes (RÉGLAGES > Commandes).
func configure(mode: int, sens: float, invert: bool, scale: float) -> void:
	steer_mode = mode
	sensitivity = sens
	tilt_invert = invert
	button_scale = scale
	_wheel_touch = -1
	_slide_touch = -1
	_wheel_angle = 0.0
	if steer_mode == SteerMode.TILT:
		_setup_tilt()
	_layout()


func _wheel_geom() -> Array:
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	var r := u * 0.15 * button_scale
	return [Vector2(u * 0.04 + r, size.y - u * 0.04 - r), r]


## Zone où le doigt dirige (moitié gauche, sous les boutons du haut).
func _steer_zone(p: Vector2) -> bool:
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	return p.x < size.x * 0.5 and p.y > u * 0.3


func _input(event: InputEvent) -> void:
	if not visible or not (steer_mode == SteerMode.WHEEL or steer_mode == SteerMode.SLIDE):
		return
	var idx := -1
	var pos := Vector2.ZERO
	var pressed := false
	var moved := false
	if event is InputEventScreenTouch:
		idx = event.index
		pos = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		idx = event.index
		pos = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		idx = 100
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		idx = 100
		pos = event.position
		moved = true
	else:
		return
	if steer_mode == SteerMode.WHEEL:
		var g := _wheel_geom()
		var c: Vector2 = g[0]
		if moved and idx == _wheel_touch:
			var a := rad_to_deg((pos - c).angle())
			_wheel_angle = clampf(_wheel_start + wrapf(a - _wheel_grab, -180.0, 180.0), -WHEEL_LOCK * 1.1, WHEEL_LOCK * 1.1)
			# On suit le doigt d'un tour à l'autre (pas de saut à ±180°).
			_wheel_grab = a
			_wheel_start = _wheel_angle
		elif not moved and pressed and _wheel_touch == -1 and pos.distance_to(c) < float(g[1]) * 1.5:
			_wheel_touch = idx
			_wheel_grab = rad_to_deg((pos - c).angle())
			_wheel_start = _wheel_angle
		elif not moved and not pressed and idx == _wheel_touch:
			_wheel_touch = -1
	else:
		if moved and idx == _slide_touch:
			_slide_pos = pos
		elif not moved and pressed and _slide_touch == -1 and _steer_zone(pos):
			_slide_touch = idx
			_slide_origin = pos
			_slide_pos = pos
		elif not moved and not pressed and idx == _slide_touch:
			_slide_touch = -1


## Volant ou curseur dessinés à l'écran.
func _draw_overlay() -> void:
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	var ink := Color(0.96, 0.93, 0.88, 0.9)
	var orange := Color(1.0, 0.52, 0.12)
	if steer_mode == SteerMode.WHEEL:
		var g := _wheel_geom()
		var c: Vector2 = g[0]
		var r: float = g[1]
		var held := _wheel_touch != -1
		var a := deg_to_rad(_wheel_angle)
		_overlay.draw_circle(c, r * 1.02, Color(0.07, 0.065, 0.07, 0.42))
		# Jante facettée (12 pans), branches, repère orange en haut.
		var rim := PackedVector2Array()
		for i in 13:
			var t := a + TAU * i / 12.0
			rim.append(c + Vector2(cos(t), sin(t)) * r * 0.9)
		_overlay.draw_polyline(rim, orange if held else ink, maxf(3.0, r * 0.13), true)
		for sp in [PI * 0.5, PI * 0.5 + TAU / 3.0, PI * 0.5 - TAU / 3.0]:
			var d := Vector2(cos(a + sp + PI), sin(a + sp + PI))
			_overlay.draw_line(c + d * r * 0.2, c + d * r * 0.84, Color(ink.r, ink.g, ink.b, 0.75), maxf(2.0, r * 0.08), true)
		_overlay.draw_circle(c, r * 0.22, Color(0.12, 0.11, 0.11, 0.9))
		var top := Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5))
		_overlay.draw_line(c + top * r * 0.78, c + top * r * 1.0, orange, maxf(4.0, r * 0.16))
	elif steer_mode == SteerMode.SLIDE:
		var y := size.y - u * 0.12
		var x0 := u * 0.06
		var x1 := size.x * 0.46
		var mid := (x0 + x1) * 0.5
		_overlay.draw_rect(Rect2(Vector2(x0, y - 2.0), Vector2(x1 - x0, 4.0)), Color(1, 1, 1, 0.18))
		var k := (x1 - x0) * 0.5 * _steer_smooth
		_overlay.draw_rect(Rect2(Vector2(minf(mid, mid + k), y - 3.0), Vector2(absf(k), 6.0)), orange)
		_overlay.draw_circle(Vector2(mid + k, y), u * 0.028, ink if _slide_touch != -1 else Color(ink.r, ink.g, ink.b, 0.5))
		if _slide_touch == -1:
			_overlay.draw_string(FONT, Vector2(x0, y - u * 0.05), "GLISSE LE DOIGT ICI", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, int(u * 0.03)), Color(ink.r, ink.g, ink.b, 0.5))
	elif steer_mode == SteerMode.TILT:
		var y2 := size.y - u * 0.12
		var x2 := u * 0.06
		var w := size.x * 0.4
		var mid2 := x2 + w * 0.5
		_overlay.draw_rect(Rect2(Vector2(x2, y2 - 2.0), Vector2(w, 4.0)), Color(1, 1, 1, 0.18))
		_overlay.draw_circle(Vector2(mid2 + w * 0.5 * _steer_smooth, y2), u * 0.024, orange)
		if not _tilt_ready:
			_overlay.draw_string(FONT, Vector2(x2, y2 - u * 0.05), "TOUCHE L'ÉCRAN POUR ACTIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, int(u * 0.03)), Color(ink.r, ink.g, ink.b, 0.6))


# ------------------------------------------------------------------ inclinaison

## Version web : le navigateur donne l'inclinaison (devicemotion). Sur iPhone, il faut une
## autorisation demandée pendant un vrai geste : on l'accroche au prochain toucher.
func _setup_tilt() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
	(function () {
		if (window.__ci_tilt_setup) return;
		window.__ci_tilt_setup = true;
		window.__ci_tilt = 0; window.__ci_tilt_on = false;
		function listen() {
			window.addEventListener('devicemotion', function (e) {
				var g = e.accelerationIncludingGravity; if (!g) return;
				var a = (screen.orientation && screen.orientation.angle) || window.orientation || 0;
				var v = a == 90 ? g.y : (a == -90 || a == 270 ? -g.y : (a == 180 ? -g.x : g.x));
				window.__ci_tilt = v; window.__ci_tilt_on = true;
			});
		}
		if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
			var ask = function () {
				DeviceMotionEvent.requestPermission().then(function (s) { if (s === 'granted') listen(); }).catch(function () {});
				document.removeEventListener('touchend', ask, true);
			};
			document.addEventListener('touchend', ask, true);
		} else { listen(); }
	})();
	""", true)


func _read_tilt() -> float:
	var v := 0.0
	if OS.has_feature("web"):
		var w = JavaScriptBridge.get_interface("window")
		if w:
			_tilt_ready = bool(w.__ci_tilt_on)
			v = float(w.__ci_tilt)
	else:
		var acc := Input.get_accelerometer()
		_tilt_ready = acc != Vector3.ZERO
		v = acc.x
	# iPhone : pencher à droite donne une valeur négative.
	var sgn := 1.0 if tilt_invert else -1.0
	var k := v * sgn / 4.5 * sensitivity
	return clampf(signf(k) * maxf(absf(k) - 0.06, 0.0) / 0.94, -1.0, 1.0)
