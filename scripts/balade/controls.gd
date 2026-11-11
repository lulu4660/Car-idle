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

var _steer_smooth := 0.0

# Boutons : action, texte, zone en fraction de l'écran (x, y depuis le HAUT, largeur, hauteur).
const BUTTONS := [
	["ci_left", "◀", Rect2(0.02, 0.77, 0.17, 0.20)],
	["ci_right", "▶", Rect2(0.21, 0.77, 0.17, 0.20)],
	["ci_brake", "FREIN", Rect2(0.61, 0.79, 0.17, 0.18)],
	["ci_gas", "GAZ", Rect2(0.80, 0.71, 0.18, 0.26)],
	["ci_drift", "DÉRAPAGE", Rect2(0.80, 0.57, 0.18, 0.12)],
	["ci_reset", "REPLACER", Rect2(0.02, 0.04, 0.12, 0.08)],
	["ci_camera", "CAMÉRA", Rect2(0.72, 0.04, 0.12, 0.08)],
	["ci_car", "VOITURE", Rect2(0.86, 0.04, 0.12, 0.08)],
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
		t.set_meta("zone", b[2])
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
	for t in _buttons:
		var z: Rect2 = t.get_meta("zone")
		var r := Rect2(z.position * size, z.size * size)
		t.position = r.position
		t.texture_normal = _box(Vector2i(r.size), Color(1, 1, 1, 0.18))
		t.texture_pressed = _box(Vector2i(r.size), Color(1.0, 0.55, 0.15, 0.65))
		var lbl := t.get_child(0) as Label
		lbl.size = r.size
		lbl.add_theme_font_size_override("font_size", maxi(14, int(size.y / 30.0)))


func _box(s: Vector2i, c: Color) -> ImageTexture:
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
	return ImageTexture.create_from_image(img)


## La souris joue le rôle d'un doigt (PC) : bouton pressé sous le pointeur.
func _unhandled_input(event: InputEvent) -> void:
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
