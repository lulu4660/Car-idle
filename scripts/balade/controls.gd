## Commandes de conduite : clavier (flèches ou ZQSD/WASD, espace = frein à main,
## R = replacer, C = voiture suivante, V = plan de caméra) et boutons tactiles multi-doigts
## (gauche/droite en bas à gauche, gaz/frein en bas à droite, dérapage au-dessus).
## La souris compte comme un doigt sur PC.
extends CanvasLayer

var throttle := 0.0
var brake := 0.0
var steer := 0.0
var handbrake := false
var reset_requested := false
var next_car_requested := false
var camera_requested := false
var night_requested := false
var settings_requested := false

var _steer_smooth := 0.0

# Boutons : action, texte (vide = flèche dessinée), coin d'accroche (0/1 en x et y) et zone
# mesurée depuis ce coin, en fraction du petit côté de l'écran : même taille au doigt en
# portrait et en paysage, rien ne se chevauche sur un téléphone tenu droit.
const BUTTONS := [
	["ci_left", "", Vector2(0, 1), Rect2(0.04, 0.04, 0.20, 0.26)],
	["ci_right", "", Vector2(0, 1), Rect2(0.26, 0.04, 0.20, 0.26)],
	["ci_gas", "GAZ", Vector2(1, 1), Rect2(0.04, 0.04, 0.24, 0.32)],
	["ci_brake", "FREIN", Vector2(1, 1), Rect2(0.30, 0.04, 0.20, 0.20)],
	["ci_drift", "DÉRAPAGE", Vector2(1, 1), Rect2(0.04, 0.38, 0.24, 0.14)],
	["ci_reset", "REPLACER", Vector2(0, 0), Rect2(0.03, 0.03, 0.28, 0.11)],
	["ci_night", "NUIT", Vector2(0, 0), Rect2(0.03, 0.16, 0.28, 0.11)],
	["ci_camera", "CAMÉRA", Vector2(1, 0), Rect2(0.03, 0.03, 0.28, 0.11)],
	["ci_car", "VOITURE", Vector2(1, 0), Rect2(0.03, 0.16, 0.28, 0.11)],
	["ci_settings", "RÉGLAGES", Vector2(1, 0), Rect2(0.03, 0.29, 0.28, 0.11)],
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
}

var _buttons: Array[TouchScreenButton] = []
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
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		lbl.add_theme_constant_override("outline_size", 4)
		t.add_child(lbl)
		add_child(t)
		_buttons.append(t)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	for t in _buttons:
		var corner: Vector2 = t.get_meta("corner")
		var z: Rect2 = t.get_meta("zone")
		var bs := z.size * u
		var x := z.position.x * u if corner.x == 0 else size.x - (z.position.x + z.size.x) * u
		var y := z.position.y * u if corner.y == 0 else size.y - (z.position.y + z.size.y) * u
		t.position = Vector2(x, y)
		var arrow: int = t.get_meta("arrow")
		t.texture_normal = _box(Vector2i(bs), Color(1, 1, 1, 0.18), arrow)
		t.texture_pressed = _box(Vector2i(bs), Color(1.0, 0.55, 0.15, 0.65), arrow)
		var lbl := t.get_child(0) as Label
		lbl.size = bs
		lbl.add_theme_font_size_override("font_size", maxi(12, int(u * 0.042)))


## Fond du bouton (cadre) ; `arrow` = -1 ou 1 : flèche gauche ou droite dessinée dedans
## (les caractères ◀ ▶ manquent dans la police de la version web).
func _box(s: Vector2i, c: Color, arrow := 0) -> ImageTexture:
	s = s.max(Vector2i(8, 8))
	var img := Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var border := Color(c.r, c.g, c.b, minf(1.0, c.a + 0.35))
	for x in s.x:
		for w in 2:
			img.set_pixel(x, w, border)
			img.set_pixel(x, s.y - 1 - w, border)
	for y in s.y:
		for w in 2:
			img.set_pixel(w, y, border)
			img.set_pixel(s.x - 1 - w, y, border)
	if arrow != 0:
		var half := minf(s.x, s.y) * 0.22
		var cx := s.x * 0.5
		var cy := s.y * 0.5
		var ink := Color(1, 1, 1, 0.9)
		for y in range(int(cy - half), int(cy + half) + 1):
			var span := half * (1.0 - absf(y - cy) / half) * 1.6
			for x in range(int(cx - half * 0.8), int(cx - half * 0.8 + span) + 1):
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
		if Rect2(t.position, t.texture_normal.get_size()).has_point(p):
			return t.action
	return ""


func _process(delta: float) -> void:
	var target := Input.get_action_strength("ci_right") - Input.get_action_strength("ci_left")
	# Le volant revient plus vite au centre qu'il ne braque : plus facile au doigt.
	var rate := 4.0 if absf(target) > absf(_steer_smooth) else 7.0
	_steer_smooth = move_toward(_steer_smooth, target, rate * delta)
	steer = _steer_smooth
	throttle = Input.get_action_strength("ci_gas")
	brake = Input.get_action_strength("ci_brake")
	handbrake = Input.is_action_pressed("ci_drift")
	reset_requested = Input.is_action_just_pressed("ci_reset")
	next_car_requested = Input.is_action_just_pressed("ci_car")
	camera_requested = Input.is_action_just_pressed("ci_camera")
	night_requested = Input.is_action_just_pressed("ci_night")
	settings_requested = Input.is_action_just_pressed("ci_settings")


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
	handbrake = false
	settings_requested = false


## Change le texte d'un bouton (ex. NUIT / JOUR).
func set_label(action: String, text: String) -> void:
	for t in _buttons:
		if t.action == action:
			(t.get_child(0) as Label).text = text
