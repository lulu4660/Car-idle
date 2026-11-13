## Interface du garage, par-dessus la scène 3D : argent et revenus en haut, la voiture
## choisie (flèches pour changer, ou toucher une voiture garée), ses 10 pièces à
## améliorer (×1, ×10 ou MAX ; paliers ×2 aux niveaux 25, 50, 100, 150, 200), et en bas
## GARAGE (places, étape suivante, réserve), SERVIR (gain au toucher, jauge du rush ×2) et
## BALADE. Au retour d'une absence : ce que le garage a rapporté.
## Style de la balade : charbon translucide, orange, polices Russo One et Rajdhani ; tailles
## de police fixées une fois (une nouvelle taille coûte cher sur le web).
extends CanvasLayer

const Economy = preload("res://scripts/core/economy.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const CHARCOAL := Color(0.07, 0.065, 0.07, 0.82)
const CHARCOAL_SOFT := Color(0.07, 0.065, 0.07, 0.6)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.55)
const GOLD := Color(1.0, 0.78, 0.25)
const ORANGE := Color(1.0, 0.52, 0.12)
const RED := Color(0.95, 0.2, 0.12)
const RARITY_COLORS: Array[Color] = [Color(0.72, 0.72, 0.7), Color(0.45, 0.85, 0.4), Color(0.35, 0.7, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.72, 0.2), Color(1.0, 0.3, 0.25)]
const MULTS: Array[int] = [1, 10, -1]

var garage: Node3D
var game: Node
var _u := 1.0
var _su := 1.0
var _big: Font
var _text: Font
var _root: Control
var _coins_lbl: Label
var _income_lbl: Label
var _stage_lbl: Label
var _car_name: Label
var _car_info: Label
var _rarity_lbl: Label
var _rows: Array = []   # [bouton, nom, niveau, barre, indice de pièce]
var _mult_btns: Array[Button] = []
var _mult := 0
var _serve_btn: Button
var _rush_bar: ProgressBar
var _popup: Control
var _shown_coins := 0.0
var _float_layer: Control
var _last_size := Vector2.ZERO


func _ready() -> void:
	game = get_node("/root/Game")
	# Les boutons de l'interface se touchent du doigt (la balade lit les doigts elle-même).
	Input.emulate_mouse_from_touch = true
	_big = load("res://assets/fonts/RussoOne-Regular.ttf")
	_text = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_build()
	game.changed.connect(_refresh)
	_shown_coins = game.coins
	_refresh()
	if not game.offline.is_empty():
		_show_offline()


func _build() -> void:
	if _root:
		_root.queue_free()
	_rows.clear()
	_mult_btns.clear()
	var size := get_viewport().get_visible_rect().size
	_last_size = size
	_u = minf(size.x, size.y)
	var portrait := size.y >= size.x
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	var pad := _u * 0.03
	# --- En haut : argent, revenu, étape.
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(0, pad) if portrait else Vector2(pad * 1.5, pad)
	top.size = Vector2(size.x, _u * 0.2) if portrait else Vector2(_u * 0.6, _u * 0.2)
	_root.add_child(top)
	# Paysage : en-tête plus petit, en haut à gauche (l'enseigne du garage est au milieu).
	var tu := _u if portrait else _u * 0.72
	_coins_lbl = _label(top, "0", _big, int(tu * 0.085), INK)
	var align := HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	_coins_lbl.horizontal_alignment = align
	_coins_lbl.add_theme_constant_override("outline_size", int(_u * 0.012))
	_coins_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_income_lbl = _label(top, "", _text, int(tu * 0.045), GOLD)
	_income_lbl.horizontal_alignment = align
	_stage_lbl = _label(top, "", _text, int(tu * 0.036), DIM)
	_stage_lbl.horizontal_alignment = align
	# --- Bas : la fiche de la voiture (pièces) puis la barre de boutons.
	var bar_h := _u * 0.15
	var sheet_rect: Rect2
	if portrait:
		var sheet_h := size.y * 0.4
		sheet_rect = Rect2(pad, size.y - bar_h - pad * 2.0 - sheet_h, size.x - pad * 2.0, sheet_h)
	else:
		var w := size.x * 0.38
		sheet_rect = Rect2(size.x - w - pad, pad, w, size.y - bar_h - pad * 3.0)
	# Tailles de la fiche d'après sa largeur (paysage : colonne plus étroite que l'écran).
	_su = minf(_u, sheet_rect.size.x / 0.94)
	_build_sheet(sheet_rect)
	_build_bar(Rect2(pad, size.y - bar_h - pad, (size.x if portrait else size.x * 0.6) - pad * 2.0, bar_h))
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_float_layer)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = _text
	th.default_font_size = int(_u * 0.04)
	var normal := _style(Color(0.16, 0.14, 0.14, 0.92), ORANGE, 0.0)
	var hover := _style(Color(0.22, 0.18, 0.16, 0.95), ORANGE, 0.0)
	var pressed := _style(ORANGE, ORANGE, 0.0)
	var disabled := _style(Color(0.12, 0.11, 0.11, 0.7), Color(1, 1, 1, 0.12), 0.0)
	for t in ["normal", "focus"]:
		th.set_stylebox(t, "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", Color(0.08, 0.06, 0.05))
	th.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.06, 0.05))
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	th.set_color("font_focus_color", "Button", INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.1)
	th.set_stylebox("background", "ProgressBar", sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	th.set_stylebox("fill", "ProgressBar", fill)
	# Barre de défilement fine.
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 0.52, 0.12, 0.5)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	th.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return th


## Cadre à coins coupés (inclinaison légère, trait orange en bas).
func _style(bg: Color, line: Color, skew: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = line
	s.border_width_bottom = maxi(2, int(_u * 0.006))
	s.corner_radius_top_left = int(_u * 0.012)
	s.corner_radius_bottom_right = int(_u * 0.012)
	s.corner_detail = 1
	s.skew = Vector2(skew, 0)
	s.content_margin_left = _u * 0.02
	s.content_margin_right = _u * 0.02
	s.content_margin_top = _u * 0.008
	s.content_margin_bottom = _u * 0.008
	return s


func _label(parent: Node, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, font: Font, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func(): _press_anim(b))
	parent.add_child(b)
	return b


## Bouton qui s'enfonce et revient sur ressort.
func _press_anim(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	b.scale = Vector2(0.93, 0.93)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_sheet(r: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.position = r.position
	panel.size = r.size
	panel.add_theme_stylebox_override("panel", _style(CHARCOAL, ORANGE, 0.0))
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_su * 0.012))
	panel.add_child(col)
	# Titre : flèches et nom de la voiture.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(_su * 0.015))
	col.add_child(head)
	var prev := _button(head, "<", _big, int(_su * 0.05))
	prev.custom_minimum_size = Vector2(_su * 0.1, _su * 0.09)
	prev.pressed.connect(func(): _cycle(-1))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	_car_name = _label(names, "", _big, int(_su * 0.048), INK)
	_car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_name.clip_text = true
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", int(_su * 0.02))
	names.add_child(sub)
	_rarity_lbl = _label(sub, "", _text, int(_su * 0.034), INK)
	_car_info = _label(sub, "", _text, int(_su * 0.034), GOLD)
	var next := _button(head, ">", _big, int(_su * 0.05))
	next.custom_minimum_size = Vector2(_su * 0.1, _su * 0.09)
	next.pressed.connect(func(): _cycle(1))
	# Achat ×1 / ×10 / MAX.
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", int(_su * 0.012))
	col.add_child(mrow)
	var lbl := _label(mrow, "PIÈCES", _big, int(_su * 0.034), ORANGE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in MULTS.size():
		var b := _button(mrow, "×%d" % MULTS[i] if MULTS[i] > 0 else "MAX", _big, int(_su * 0.03))
		b.custom_minimum_size = Vector2(_su * 0.12, _su * 0.065)
		b.toggle_mode = true
		b.button_pressed = i == _mult
		b.pressed.connect(func(): _set_mult(i))
		_mult_btns.append(b)
	# Liste des pièces (défilante).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(_su * 0.01))
	scroll.add_child(list)
	for p in Economy.PARTS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(_su * 0.02))
		list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var line := HBoxContainer.new()
		info.add_child(line)
		var name_l := _label(line, String(Economy.PARTS[p]["name"]).to_upper(), _text, int(_su * 0.04), INK)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lvl_l := _label(line, "", _text, int(_su * 0.034), DIM)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, maxf(4.0, _su * 0.012))
		bar.max_value = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(bar)
		var btn := _button(row, "", _big, int(_su * 0.032))
		btn.custom_minimum_size = Vector2(_su * 0.3, _su * 0.085)
		var part := p
		btn.pressed.connect(func(): _buy(part))
		_rows.append([btn, name_l, lvl_l, bar, p])


func _build_bar(r: Rect2) -> void:
	var row := HBoxContainer.new()
	row.position = r.position
	row.size = r.size
	row.add_theme_constant_override("separation", int(_u * 0.02))
	_root.add_child(row)
	var g := _button(row, "GARAGE", _big, int(_u * 0.036))
	g.custom_minimum_size = Vector2(_u * 0.24, r.size.y)
	g.pressed.connect(_show_garage_menu)
	var serve_box := Control.new()
	serve_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	serve_box.custom_minimum_size = Vector2(0, r.size.y)
	serve_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(serve_box)
	_serve_btn = _button(serve_box, "SERVIR", _big, int(_u * 0.06))
	_serve_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var serve_style := _style(Color(0.85, 0.36, 0.06, 0.95), GOLD, 0.0)
	_serve_btn.add_theme_stylebox_override("normal", serve_style)
	_serve_btn.add_theme_stylebox_override("hover", serve_style)
	_serve_btn.add_theme_color_override("font_color", Color(0.1, 0.06, 0.04))
	_serve_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.04))
	_serve_btn.button_down.connect(_serve)
	_rush_bar = ProgressBar.new()
	_rush_bar.show_percentage = false
	_rush_bar.max_value = 1.0
	_rush_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush_bar.anchor_left = 0.08
	_rush_bar.anchor_right = 0.92
	_rush_bar.anchor_top = 1.0
	_rush_bar.anchor_bottom = 1.0
	_rush_bar.offset_top = -_u * 0.03
	_rush_bar.offset_bottom = -_u * 0.016
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	_rush_bar.add_theme_stylebox_override("fill", fill)
	serve_box.add_child(_rush_bar)
	var b := _button(row, "BALADE", _big, int(_u * 0.036))
	b.custom_minimum_size = Vector2(_u * 0.24, r.size.y)
	b.pressed.connect(_go_drive)


# ------------------------------------------------------------------ mise à jour

func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _last_size:
		_build()
		_refresh()
	var t: float = game.now()
	# L'argent affiché rattrape le vrai en roulant.
	var target: float = game.coins
	_shown_coins = target if absf(target - _shown_coins) < 0.5 else lerpf(_shown_coins, target, minf(1.0, delta * 10.0))
	_coins_lbl.text = Economy.format_number(_shown_coins)
	var rush: bool = game.rush_active(t)
	_income_lbl.text = "+%s /s%s" % [Economy.format_number(game.income(t)), "   RUSH ×2  %d s" % ceili(game.rush_until - t) if rush else ""]
	_income_lbl.add_theme_color_override("font_color", ORANGE if rush else GOLD)
	_rush_bar.value = 1.0 if rush else game.rush_charge
	# Les prix changent avec l'argent : les boutons s'allument quand on peut payer.
	_refresh_buttons()


func _refresh() -> void:
	if _car_name == null:
		return
	_stage_lbl.text = "%s  ·  %d / %d PLACES  ·  %d EN RÉSERVE" % [String(Economy.STAGES[game.stage]["name"]).to_upper(), game.parked.size(), game.slots, game.cars.size() - game.parked.size()]
	var car: Dictionary = game.get_car(game.selected)
	if car.is_empty():
		return
	var model := Catalog.get_car(String(car["model"]))
	_car_name.text = Catalog.display_name(String(car["model"])).to_upper()
	var rarity := int(model["rarity"])
	_rarity_lbl.text = Economy.RARITY_NAMES[rarity].to_upper()
	_rarity_lbl.add_theme_color_override("font_color", RARITY_COLORS[rarity])
	var parked: bool = game.is_parked(int(car["uid"]))
	_car_info.text = ("+%s /s" % Economy.format_number(game.car_income(car))) if parked else "EN RÉSERVE"
	_car_info.add_theme_color_override("font_color", GOLD if parked else DIM)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var car: Dictionary = game.get_car(game.selected)
	if car.is_empty():
		return
	for r in _rows:
		var btn: Button = r[0]
		var p: int = r[4]
		var level := int(car["levels"][p])
		var lvl_l: Label = r[2]
		var bar: ProgressBar = r[3]
		if p >= game.unlocked_parts():
			var need := 0
			for s in Economy.STAGES.size():
				if int(Economy.STAGES[s]["parts"]) > p:
					need = s
					break
			btn.text = String(Economy.STAGES[need]["name"]).to_upper()
			btn.disabled = true
			lvl_l.text = "VERROUILLÉ"
			bar.value = 0.0
			(r[1] as Label).modulate.a = 0.4
			continue
		(r[1] as Label).modulate.a = 1.0
		var nm := Economy.next_milestone(level)
		lvl_l.text = "NIV. %d" % level + (("  ·  ×2 AU %d" % nm) if nm > 0 else "  ·  MAX")
		var prev := 0
		for s in Economy.MILESTONES:
			if level >= s:
				prev = s
		bar.value = 1.0 if nm < 0 else float(level - prev) / float(nm - prev)
		if level >= Economy.MAX_LEVEL:
			btn.text = "MAX"
			btn.disabled = true
			continue
		var q: Dictionary = game.part_quote(int(car["uid"]), p, MULTS[_mult])
		var n := int(q["count"])
		btn.text = ("+%d  " % n if n > 1 else "") + Economy.format_number(float(q["cost"]))
		btn.disabled = game.coins < float(q["cost"])


# ------------------------------------------------------------------ actions

func _set_mult(i: int) -> void:
	_mult = i
	for k in _mult_btns.size():
		_mult_btns[k].button_pressed = k == i
	_refresh_buttons()


func _cycle(dir: int) -> void:
	if game.cars.is_empty():
		return
	var i := 0
	for k in game.cars.size():
		if int(game.cars[k]["uid"]) == game.selected:
			i = k
	i = posmod(i + dir, game.cars.size())
	game.select(int(game.cars[i]["uid"]))


func _buy(part: int) -> void:
	var car: Dictionary = game.get_car(game.selected)
	var before := int(car["levels"][part])
	if game.buy_part(game.selected, part, MULTS[_mult]):
		var after := int(game.get_car(game.selected)["levels"][part])
		var big := Economy.milestones_passed(after) > Economy.milestones_passed(before)
		garage.celebrate(big)
		var row: Array = _rows[part]
		var btn: Button = row[0]
		_float_text(("REVENU ×2 !" if big else "+%d NIV." % (after - before)), btn.global_position + Vector2(btn.size.x * 0.5, 0), GOLD if big else INK)


func _serve() -> void:
	var gain: float = game.tap(game.now())
	var p := _serve_btn.global_position + Vector2(_serve_btn.size.x * randf_range(0.3, 0.7), 0)
	_float_text("+" + Economy.format_number(gain), p, GOLD)


func _go_drive() -> void:
	game.save_game(game.now())
	Input.emulate_mouse_from_touch = false
	get_tree().change_scene_to_file("res://scenes/balade.tscn")


## Texte qui s'envole et s'efface (gain, niveaux).
func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := _label(_float_layer, text, _big, int(_u * 0.045), color)
	l.add_theme_constant_override("outline_size", int(_u * 0.01))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.reset_size()
	l.position = at - Vector2(l.size.x * 0.5, l.size.y)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - _u * 0.12, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	# Toucher une voiture garée la met sur le plateau.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var uid: int = garage.car_at_screen(event.position)
		if uid >= 0:
			game.select(uid)


# ------------------------------------------------------------------ fenêtres

func _open_popup(title: String) -> VBoxContainer:
	_close_popup()
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_popup)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_popup())
	_popup.add_child(shade)
	var size := get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	var w := minf(size.x * 0.9, _u * 1.1)
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.065, 0.07, 0.96), ORANGE, 0.0))
	panel.custom_minimum_size = Vector2(w, 0)
	panel.position = Vector2((size.x - w) / 2.0, size.y * 0.18)
	_popup.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_u * 0.02))
	panel.add_child(col)
	var t := _label(col, title, _big, int(_u * 0.055), ORANGE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Ouverture : la fenêtre glisse et grandit un peu.
	panel.pivot_offset = Vector2(w / 2.0, 0)
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	return col


func _close_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null


func _show_offline() -> void:
	var off: Dictionary = game.offline
	game.offline = {}
	var col := _open_popup("PENDANT TON ABSENCE")
	var l := _label(col, "Ton garage a tourné pendant %s." % Economy.format_duration(float(off["seconds"])), _text, int(_u * 0.042), INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var g := _label(col, "+" + Economy.format_number(float(off["gain"])), _big, int(_u * 0.085), GOLD)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _button(col, "RÉCUPÉRER", _big, int(_u * 0.045))
	b.custom_minimum_size = Vector2(0, _u * 0.11)
	b.pressed.connect(_close_popup)


func _show_garage_menu() -> void:
	var col := _open_popup("MON GARAGE")
	var fs := int(_u * 0.04)
	# Places.
	var r1 := HBoxContainer.new()
	col.add_child(r1)
	var l1 := _label(r1, "PLACES  %d / %d" % [game.slots, Economy.MAX_SLOTS], _text, fs, INK)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if game.can_buy_slot():
		var b1 := _button(r1, "+1 PLACE  " + Economy.format_number(game.slot_price()), _big, int(_u * 0.032))
		b1.custom_minimum_size = Vector2(_u * 0.42, _u * 0.09)
		b1.disabled = game.coins < game.slot_price()
		b1.pressed.connect(func():
			if game.buy_slot():
				garage.celebrate(false)
				_show_garage_menu())
	# Étape suivante.
	var r2 := HBoxContainer.new()
	col.add_child(r2)
	if game.has_next_stage():
		var nxt: Dictionary = Economy.STAGES[game.stage + 1]
		var l2 := _label(r2, "%s : %d PIÈCES" % [String(nxt["name"]).to_upper(), int(nxt["parts"])], _text, fs, INK)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b2 := _button(r2, Economy.format_number(game.stage_price()), _big, int(_u * 0.032))
		b2.custom_minimum_size = Vector2(_u * 0.42, _u * 0.09)
		b2.disabled = game.coins < game.stage_price()
		b2.pressed.connect(func():
			if game.buy_stage():
				garage.celebrate(true)
				_show_garage_menu())
	else:
		_label(r2, "ÉTAPE MAXIMALE : HANGAR", _text, fs, DIM)
	# Réserve : voitures sans place.
	var reserve: Array = []
	for c in game.cars:
		if not game.is_parked(int(c["uid"])):
			reserve.append(c)
	var lr := _label(col, "RÉSERVE (%d)" % reserve.size(), _big, int(_u * 0.036), ORANGE)
	lr.add_theme_constant_override("line_spacing", 0)
	if reserve.is_empty():
		_label(col, "Spotte des voitures en balade pour agrandir ta collection.", _text, int(_u * 0.034), DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(reserve.size(), 4) * _u * 0.1)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for c in reserve:
		var row := HBoxContainer.new()
		list.add_child(row)
		var rarity: int = game.rarity_of(c)
		var nl := _label(row, Catalog.display_name(String(c["model"])).to_upper(), _text, fs, RARITY_COLORS[rarity])
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		var uid := int(c["uid"])
		var bg := _button(row, "GARER", _big, int(_u * 0.03))
		bg.custom_minimum_size = Vector2(_u * 0.22, _u * 0.08)
		bg.pressed.connect(func():
			# Places pleines : elle prend la place de la voiture qui rapporte le moins.
			var worst := -1
			var low := INF
			for pu in game.parked:
				var inc: float = game.car_income(game.get_car(pu))
				if inc < low:
					low = inc
					worst = pu
			if game.park(uid, worst):
				game.select(uid)
				_show_garage_menu())
	var close := _button(col, "FERMER", _big, int(_u * 0.04))
	close.custom_minimum_size = Vector2(0, _u * 0.1)
	close.pressed.connect(_close_popup)
