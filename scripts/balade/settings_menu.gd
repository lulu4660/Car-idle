## Écran des réglages (bouton RÉGLAGES ou Échap) : deux onglets.
## - Graphismes : préréglages de Très bas à Ultra, puis chaque valeur modifiable.
## - Conduite : paramètres de la voiture, appliqués en direct ; « Copier » met le texte des
##   réglages dans le presse-papiers (et l'affiche) pour l'envoyer.
## Tout est enregistré dans user://settings.cfg.
extends CanvasLayer

const Settings = preload("res://scripts/balade/settings.gd")
const ORANGE := Color(1.0, 0.55, 0.15)
const CHARCOAL := Color(0.08, 0.08, 0.09, 0.92)

var game: Node
var settings: RefCounted
var _root: Control
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab := 0
var _tab_buttons: Array[Button] = []
var _preset_buttons: Array[Button] = []
var _text: TextEdit
var _rows := {}   # clé -> [contrôle, étiquette de valeur]
var _font := 16
var _save_timer := 0.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()
	visible = false


func open() -> void:
	visible = true
	# Le jeu lit les doigts directement (commandes multi-doigts) ; l'interface du menu a
	# besoin que le toucher soit aussi vu comme une souris.
	Input.emulate_mouse_from_touch = true
	_rebuild()


func close() -> void:
	visible = false
	Input.emulate_mouse_from_touch = false
	settings.save_file()


func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			settings.save_file()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if _root.get_child_count() > 1:
		_root.get_child(1).queue_free()
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	_font = maxi(14, int(u * 0.036))
	var theme := Theme.new()
	theme.default_font_size = _font
	theme.set_stylebox("normal", "Button", _box(Color(0.16, 0.15, 0.15), Color(0.35, 0.3, 0.28)))
	theme.set_stylebox("hover", "Button", _box(Color(0.22, 0.19, 0.17), ORANGE.darkened(0.3)))
	theme.set_stylebox("pressed", "Button", _box(ORANGE.darkened(0.25), ORANGE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Label", Color(0.95, 0.92, 0.88))
	theme.set_color("font_pressed_color", "Button", Color(0.05, 0.04, 0.03))
	theme.set_stylebox("slider", "HSlider", _box(Color(0.25, 0.23, 0.22), Color(0, 0, 0, 0), 4))
	theme.set_stylebox("grabber_area", "HSlider", _box(ORANGE.darkened(0.2), Color(0, 0, 0, 0), 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(ORANGE, Color(0, 0, 0, 0), 4))
	theme.set_icon("grabber", "HSlider", _knob(int(u * 0.05), ORANGE))
	theme.set_icon("grabber_highlight", "HSlider", _knob(int(u * 0.05), ORANGE.lightened(0.3)))

	var panel := PanelContainer.new()
	panel.theme = theme
	var sb := _box(CHARCOAL, ORANGE.darkened(0.4), 2)
	sb.content_margin_left = u * 0.04
	sb.content_margin_right = u * 0.04
	sb.content_margin_top = u * 0.03
	sb.content_margin_bottom = u * 0.03
	panel.add_theme_stylebox_override("panel", sb)
	var w := minf(size.x - u * 0.06, u * 1.1)
	panel.position = Vector2((size.x - w) / 2.0, u * 0.03)
	panel.size = Vector2(w, size.y - u * 0.06)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(u * 0.02))
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "RÉGLAGES"
	title.add_theme_font_size_override("font_size", int(_font * 1.4))
	title.add_theme_color_override("font_color", ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := _button("FERMER", u)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(u * 0.02))
	col.add_child(tabs)
	_tab_buttons.clear()
	for i in 3:
		var b := _button(["GRAPHISMES", "CONDUITE", "COMMANDES"][i], u)
		b.toggle_mode = true
		b.button_pressed = i == _tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = int(u * 0.03)
	col.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(u * 0.025))
	_scroll.add_child(_content)
	_fill(u)


func _select_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		_tab_buttons[k].set_pressed_no_signal(k == i)
	for c in _content.get_children():
		c.queue_free()
	_fill(minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y))
	_scroll.scroll_vertical = 0


func _fill(u: float) -> void:
	_rows.clear()
	if _tab == 0:
		_fill_graphics(u)
	elif _tab == 1:
		_fill_car(u)
	else:
		_fill_controls(u)


# ------------------------------------------------------------------ commandes

func _fill_controls(u: float) -> void:
	_content.add_child(_label("Direction", true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(u * 0.02))
	grid.add_theme_constant_override("v_separation", int(u * 0.02))
	_content.add_child(grid)
	var names: Array = game.controls.MODE_NAMES
	for i in names.size():
		var b := _button(names[i], u)
		b.toggle_mode = true
		b.button_pressed = i == int(settings.controls["steer_mode"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_steer.bind(i))
		grid.add_child(b)
	var hint := _label(["Deux flèches, gauche et droite.", "Un volant à l'écran : tourne-le au doigt, il revient au centre quand tu le lâches.", "Pose le doigt à gauche de l'écran et glisse-le vers la gauche ou la droite.", "Penche le téléphone. Sur iPhone, touche l'écran une fois pour autoriser le capteur."][int(settings.controls["steer_mode"])], false)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	_content.add_child(hint)
	_add_row("sensitivity", "Sensibilité de la direction", 0.4, 2.5, 0.05, float(settings.controls["sensitivity"]), _on_control, u)
	_add_row("button_scale", "Taille des boutons", 0.7, 1.4, 0.05, float(settings.controls["button_scale"]), _on_control, u)
	_add_row("tilt_invert", "Inclinaison inversée", 0.0, 1.0, 0.0, float(settings.controls["tilt_invert"]), _on_control, u)


func _choose_steer(i: int) -> void:
	settings.controls["steer_mode"] = float(i)
	settings.apply_controls(game.controls)
	_save_timer = 0.2
	_select_tab(2)


func _on_control(key: String, v: float) -> void:
	settings.controls[key] = v
	settings.apply_controls(game.controls)
	_save_timer = 0.5


# ------------------------------------------------------------------ graphismes

func _fill_graphics(u: float) -> void:
	_content.add_child(_label("Préréglage", true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(u * 0.02))
	grid.add_theme_constant_override("v_separation", int(u * 0.02))
	_content.add_child(grid)
	_preset_buttons.clear()
	for i in Settings.PRESETS.size():
		var b := _button(Settings.PRESETS[i].to_upper(), u)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_preset.bind(i))
		grid.add_child(b)
		_preset_buttons.append(b)
	_content.add_child(_label("Réglages fins", true))
	for g in Settings.GRAPHICS:
		_add_row(g[0], g[1], g[2], g[3], g[4], float(settings.graphics[g[0]]), _on_graphic, u)
	# Heure du jour (le soleil et la lune se placent en direct).
	_add_row("hour", "Heure", 0.0, 24.0, 0.25, game.lighting.hour, _on_hour, u)
	var hint := _label("Le plus efficace pour gagner des images/s : baisser la résolution 3D, puis la distance d'affichage et l'herbe.", false)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	_content.add_child(hint)
	_refresh_presets()


func _on_hour(_key: String, v: float) -> void:
	game.lighting.set_hour(v)


func _choose_preset(i: int) -> void:
	settings.set_preset(i)
	settings.apply_graphics(game)
	for g in Settings.GRAPHICS:
		_set_row(g[0], float(settings.graphics[g[0]]), g[4])
	_refresh_presets()
	_save_timer = 0.5


func _on_graphic(key: String, v: float) -> void:
	settings.graphics[key] = v
	var m: int = settings.matching_preset()
	if m >= 0:
		settings.preset = m
	settings.apply_graphics(game)
	_refresh_presets()
	_save_timer = 0.5


func _refresh_presets() -> void:
	var m: int = settings.matching_preset()
	for i in _preset_buttons.size():
		_preset_buttons[i].set_pressed_no_signal(i == m)


# ------------------------------------------------------------------ conduite

func _fill_car(u: float) -> void:
	var car: VehicleBody3D = game.car
	_content.add_child(_label("Mode de conduite", true))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", int(u * 0.02))
	_content.add_child(modes)
	for i in Settings.MODES.size():
		var b := _button(Settings.MODES[i], u)
		b.toggle_mode = true
		b.button_pressed = i == settings.mode
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_mode.bind(i))
		modes.add_child(b)
	var hint := _label("Drift : la voiture glisse, l'angle se tient aux gaz et au volant. Grip : elle accroche, ne part en travers qu'au frein à main.", false)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	_content.add_child(hint)
	_content.add_child(_label("Voiture : %s — réglages du mode %s, appliqués en direct, gardés pour toutes les voitures." % [game.car_display_name(), Settings.MODES[settings.mode]], false))
	for c in Settings.CAR:
		_add_row(c[0], c[1], c[2], c[3], c[4], Settings.car_value(car, c[0]), _on_car, u)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u * 0.02))
	_content.add_child(row)
	var reset := _button("RÉINITIALISER", u)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_reset_car)
	row.add_child(reset)
	var copy := _button("COPIER LES RÉGLAGES", u)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_copy_car)
	row.add_child(copy)
	_text = TextEdit.new()
	_text.editable = false
	_text.custom_minimum_size = Vector2(0, u * 0.7)
	_text.add_theme_font_size_override("font_size", maxi(12, int(_font * 0.8)))
	_text.visible = false
	_content.add_child(_text)


func _choose_mode(i: int) -> void:
	settings.mode = i
	game.controls.set_drift_indicator(i == 0)
	game.rebuild_car()
	_save_timer = 0.1
	# La voiture est refaite à l'image suivante : on remplit l'onglet ensuite.
	await get_tree().process_frame
	_select_tab(1)


func _on_car(key: String, v: float) -> void:
	settings.car_tuning[key] = v
	Settings.set_car_value(game.car, key, v)
	if key == "drive":
		_set_row(key, v, 1.0)
	_save_timer = 0.5


func _reset_car() -> void:
	var base: Dictionary = game.car_base
	settings.car_tuning.clear()
	for k in base:
		Settings.set_car_value(game.car, k, float(base[k]))
	for c in Settings.CAR:
		_set_row(c[0], Settings.car_value(game.car, c[0]), c[4])
	_text.visible = false
	_save_timer = 0.1


func _copy_car() -> void:
	var t: String = settings.car_text(game.car, game.car_base)
	DisplayServer.clipboard_set(t)
	_text.text = t
	_text.visible = true
	await get_tree().process_frame
	_scroll.ensure_control_visible(_text)


# ------------------------------------------------------------------ lignes

func _add_row(key: String, title: String, lo: float, hi: float, step: float, value: float, cb: Callable, u: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(u * 0.008))
	_content.add_child(box)
	var line := HBoxContainer.new()
	box.add_child(line)
	var name_lbl := _label(title, false)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_lbl)
	var val := Label.new()
	val.add_theme_color_override("font_color", ORANGE)
	line.add_child(val)
	if step <= 0.0:
		var cb_btn := CheckButton.new()
		cb_btn.button_pressed = value > 0.5
		cb_btn.toggled.connect(func(on: bool) -> void:
			val.text = "OUI" if on else "NON"
			cb.call(key, 1.0 if on else 0.0))
		line.add_child(cb_btn)
		val.text = "OUI" if value > 0.5 else "NON"
		_rows[key] = [cb_btn, val, step]
		return
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, u * 0.07)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		val.text = _show(key, v, step)
		cb.call(key, v))
	box.add_child(s)
	val.text = _show(key, value, step)
	_rows[key] = [s, val, step]


func _set_row(key: String, v: float, step: float) -> void:
	if not _rows.has(key):
		return
	var r: Array = _rows[key]
	if r[0] is HSlider:
		(r[0] as HSlider).set_value_no_signal(v)
	else:
		(r[0] as CheckButton).set_pressed_no_signal(v > 0.5)
	(r[1] as Label).text = ("OUI" if v > 0.5 else "NON") if float(r[2]) <= 0.0 else _show(key, v, step)


func _show(key: String, v: float, step: float) -> String:
	match key:
		"drive":
			return ["4x4", "Propulsion", "Traction"][clampi(int(v), 0, 2)]
		"msaa":
			return ["Non", "×2", "×4"][clampi(int(v), 0, 2)]
		"hour":
			return "%02d:%02d" % [int(v) % 24, int(fmod(v, 1.0) * 60.0)]
		"cycle":
			return "Figée" if v < 0.5 else "%d min" % roundi(v)
		"fog":
			return "Aucun" if v < 0.05 else "×%.1f" % v
		"scale", "range", "grass", "life", "volume", "button_scale", "headlights":
			return "%d %%" % roundi(v * 100.0)
	return Settings.fmt(v, step)


func _label(t: String, strong: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if strong:
		l.add_theme_color_override("font_color", ORANGE)
	return l


func _button(t: String, u: float) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, u * 0.09)
	return b


static func _box(fill: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func _knob(d: int, c: Color) -> ImageTexture:
	d = maxi(d, 16)
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 1.0:
				img.set_pixel(x, y, c if dist < r - 3.0 else c.darkened(0.5))
	return ImageTexture.create_from_image(img)
