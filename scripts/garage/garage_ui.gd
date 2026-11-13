## Interface du garage, par-dessus la scène 3D, dessinée en code (ui_kit.gd) :
## - en haut : l'argent (pièce d'or, chiffre qui roule), le revenu par seconde (pastille,
##   orange pendant le rush) et l'étape du garage avec ses places ;
## - au-dessus de la fiche : la voiture choisie (rareté, marque, modèle, revenu) et deux
##   flèches pour changer de voiture (ou toucher une voiture garée) ;
## - la fiche : ×1 / ×10 / MAX et les 10 pièces en tuiles (icône, niveau, progression
##   vers le palier ×2, prix ; pièces verrouillées par l'étape du garage) ;
## - en bas : GARAGE (places, étape suivante, réserve), SERVIR (pièces qui s'envolent vers
##   le compteur, jauge du rush ×2), BALADE ;
## - au retour d'une absence : ce que le garage a rapporté.
## Portrait : fiche en bas ; paysage : fiche à droite. Polices fixées une fois.
extends CanvasLayer

const Economy = preload("res://scripts/core/economy.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const K = preload("res://scripts/garage/ui_kit.gd")
const MULTS: Array[int] = [1, 10, -1]


## Zone touchable dessinée par une fonction ; s'enfonce sur ressort quand on appuie.
class Btn extends Control:
	signal pressed
	var paint: Callable
	var data := {}
	var enabled := true
	var _down := false

	func _init(fn: Callable) -> void:
		paint = fn
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		paint.call(self)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = true
				pivot_offset = size / 2.0
				scale = Vector2(0.94, 0.94)
			elif _down:
				_down = false
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				if Rect2(Vector2.ZERO, size).has_point(e.position) and enabled:
					pressed.emit()


var garage: Node3D
var game: Node
var _u := 1.0
var _k := 1.0
var _portrait := true
var _size := Vector2.ZERO
var _big: Font
var _text: Font
var _root: Control
var _hud: Control
var _fx: Control
var _tiles: Array[Btn] = []
var _mult_btns: Array[Btn] = []
var _mult := 0
var _serve: Btn
var _garage_btn: Btn
var _popup: Control
var _shown_coins := 0.0
var _coin_pos := Vector2.ZERO
var _coin_pulse := 0.0
var _flying: Array = []   # [départ, arrivée, t, durée]
var _title_rect := Rect2()
var _top_rect := Rect2()
var _t := 0.0


func _ready() -> void:
	game = get_node("/root/Game")
	# Les boutons de l'interface se touchent du doigt (la balade lit les doigts elle-même).
	Input.emulate_mouse_from_touch = true
	_big = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_text = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_build()
	game.changed.connect(_refresh)
	_shown_coins = game.coins
	_refresh()
	if not game.offline.is_empty():
		_show_offline()


func _fs(x: float) -> int:
	return maxi(8, int(_k * x))


# ------------------------------------------------------------------ construction

func _build() -> void:
	if _root:
		_root.queue_free()
	_tiles.clear()
	_mult_btns.clear()
	_size = get_viewport().get_visible_rect().size
	_u = minf(_size.x, _size.y)
	_portrait = _size.y >= _size.x
	_k = _u if _portrait else _u * 0.72
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var pad := _u * 0.035
	var nav_h := _k * 0.2
	var drawer: Rect2
	var nav: Rect2
	if _portrait:
		var top := _size.y * 0.5
		nav = Rect2(pad, _size.y - pad - nav_h, _size.x - pad * 2.0, nav_h)
		drawer = Rect2(pad * 0.5, top, _size.x - pad, nav.position.y - pad * 0.6 - top)
		_top_rect = Rect2(pad, pad, _size.x - pad * 2.0, _k * 0.2)
		garage.cover_bottom = 1.0 - top / _size.y
		garage.cover_top = (_k * 0.17 + pad) / _size.y
	else:
		var x0 := _size.x * 0.6
		nav = Rect2(x0, _size.y - pad - nav_h, _size.x - x0 - pad, nav_h)
		drawer = Rect2(x0, pad, _size.x - x0 - pad, nav.position.y - pad * 1.6)
		_top_rect = Rect2(pad * 1.5, pad, x0 - pad * 3.0, _k * 0.2)
		garage.cover_right = 1.0 - x0 / _size.x
	# Titre de la voiture : en haut de la fiche (le diorama reste dégagé).
	_title_rect = Rect2(drawer.position + Vector2(_k * 0.03, _k * 0.02), Vector2(drawer.size.x - _k * 0.06, _k * 0.2))
	garage._place_camera()
	# Couche dessinée sous les boutons : en-tête, titre de la voiture, fond de la fiche.
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud.bind(drawer))
	_root.add_child(_hud)
	_build_title_arrows()
	_build_drawer(drawer)
	_build_nav(nav)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)


func _btn(parent: Control, r: Rect2, fn: Callable) -> Btn:
	var b := Btn.new(fn)
	b.position = r.position
	b.size = r.size
	parent.add_child(b)
	return b


func _build_title_arrows() -> void:
	var s := _k * 0.12
	var y := _title_rect.position.y + _title_rect.size.y * 0.5 - s / 2.0
	for d in [-1, 1]:
		var x := _title_rect.position.x if d < 0 else _title_rect.end.x - s
		var b := _btn(_root, Rect2(x, y, s, s), func(c: Control):
			K.fill_cut(c, Rect2(Vector2.ZERO, c.size), c.size.x * 0.4, K.TILE_HI)
			K.icon(c, "chevron_left" if d < 0 else "chevron_right", c.size / 2.0 - Vector2(0, c.size.y * 0.04), c.size.x * 0.3, K.INK))
		b.pressed.connect(_cycle.bind(d))


func _build_drawer(r: Rect2) -> void:
	var pad := _k * 0.03
	# Sous le titre de la voiture : AMÉLIORATIONS et le choix ×1 / ×10 / MAX.
	var title_h := _k * 0.23
	r = Rect2(r.position + Vector2(0, title_h), r.size - Vector2(0, title_h))
	var seg_w := _k * 0.115
	var seg_h := _k * 0.07
	for i in MULTS.size():
		var x := r.end.x - pad - (MULTS.size() - i) * (seg_w + _k * 0.01)
		var b := _btn(_root, Rect2(x, r.position.y + pad, seg_w, seg_h), _draw_mult.bind(i))
		b.pressed.connect(_set_mult.bind(i))
		_mult_btns.append(b)
	var scroll := ScrollContainer.new()
	scroll.position = r.position + Vector2(pad, pad * 2.0 + seg_h)
	scroll.size = Vector2(r.size.x - pad * 2.0, r.size.y - pad * 3.0 - seg_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	var gap := _k * 0.022
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	scroll.add_child(grid)
	var tw := (scroll.size.x - gap) / 2.0
	var th := _k * 0.27
	for p in Economy.PARTS.size():
		var t := Btn.new(_draw_tile)
		t.custom_minimum_size = Vector2(tw, th)
		t.data = {"part": p}
		t.pressed.connect(_buy.bind(p))
		# Le défilement passe à travers les tuiles.
		t.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(t)
		_tiles.append(t)


func _build_nav(r: Rect2) -> void:
	var gap := _k * 0.025
	var side := r.size.x * 0.24
	var g := _btn(_root, Rect2(r.position, Vector2(side, r.size.y)), _draw_nav.bind("garage", ""))
	_garage_btn = g
	g.pressed.connect(_show_garage_menu)
	var b := _btn(_root, Rect2(Vector2(r.end.x - side, r.position.y), Vector2(side, r.size.y)), _draw_nav.bind("flag", "BALADE"))
	b.pressed.connect(_go_drive)
	_serve = _btn(_root, Rect2(r.position + Vector2(side + gap, 0), Vector2(r.size.x - (side + gap) * 2.0, r.size.y)), _draw_serve)
	# SERVIR répond dès l'appui (on peut tapoter vite).
	_serve.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_do_serve(e.position))


# ------------------------------------------------------------------ dessin

func _draw_hud(drawer: Rect2) -> void:
	var c := _hud
	var t: float = game.now()
	# --- En-tête : argent.
	var cy := _top_rect.position.y + _k * 0.07
	var amount := Economy.format_number(_shown_coins)
	var fs := _fs(0.085)
	var w := _big.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var coin_r := _k * 0.036 * (1.0 + 0.18 * _coin_pulse)
	var total := coin_r * 2.0 + _k * 0.02 + w
	var x0 := _top_rect.position.x + (_top_rect.size.x - total) / 2.0 if _portrait else _top_rect.position.x
	_coin_pos = Vector2(x0 + coin_r, cy)
	K.coin(c, _coin_pos, coin_r)
	K.text(c, _big, fs, amount, Vector2(x0 + coin_r * 2.0 + _k * 0.02, cy + fs * 0.36), K.INK, -1, _k * 0.012)
	# Revenu : pastille (orange pendant le rush).
	var rush: bool = game.rush_active(t)
	var inc := "+%s /s" % Economy.format_number(game.income(t))
	if rush:
		inc += "   ×2  %d s" % ceili(game.rush_until - t)
	var ifs := _fs(0.04)
	var iw := _text.get_string_size(inc, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x + _k * 0.05
	var py := cy + _k * 0.065
	var pr := Rect2(Vector2((_top_rect.position.x + (_top_rect.size.x - iw) / 2.0) if _portrait else x0, py), Vector2(iw, _k * 0.06))
	K.pill(c, pr, Color(0.45, 0.2, 0.02, 0.85) if rush else Color(0, 0, 0, 0.45))
	K.text(c, _text, ifs, inc, pr.get_center() + Vector2(0, ifs * 0.34), K.ORANGE if rush else K.GOLD, 0)
	# Étape et places (paysage seulement ; en portrait, sur le bouton GARAGE).
	var stage := "%s   ·   %d / %d PLACES" % [String(Economy.STAGES[game.stage]["name"]).to_upper(), game.parked.size(), game.slots]
	var reserve: int = game.cars.size() - game.parked.size()
	if reserve > 0:
		stage += "   ·   %d EN RÉSERVE" % reserve
	if not _portrait:
		K.text(c, _text, _fs(0.03), stage, Vector2(x0, pr.end.y + _k * 0.045), K.DIM, -1, _k * 0.006)
	# --- Fond de la fiche, puis le titre de la voiture dedans.
	K.fill_cut(c, drawer, _k * 0.05, K.PANEL)
	var car: Dictionary = game.get_car(game.selected)
	if not car.is_empty():
		var model := Catalog.get_car(String(car["model"]))
		var rarity := int(model["rarity"])
		var rc := K.RARITY[rarity]
		var mid := _title_rect.position.x + _title_rect.size.x / 2.0
		var ty := _title_rect.position.y
		var line1 := "%s  ·  %s" % [Economy.RARITY_NAMES[rarity].to_upper(), String(model["brand"]).to_upper()]
		var rfs := _fs(0.03)
		var lw := _text.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
		var marks_w := (rarity + 1) * _k * 0.02 * 1.25
		var rx := mid - (lw + marks_w + _k * 0.015) / 2.0
		K.rarity_marks(c, Vector2(rx + _k * 0.01, ty + _k * 0.035), _k * 0.02, rarity, rc)
		K.text(c, _text, rfs, line1, Vector2(rx + marks_w + _k * 0.015, ty + _k * 0.035 + rfs * 0.36), rc)
		K.text(c, _big, _fs(0.066), String(model["name"]).to_upper(), Vector2(mid, ty + _k * 0.125), K.INK, 0, _k * 0.01)
		var parked: bool = game.is_parked(int(car["uid"]))
		var info := ("+%s /s" % Economy.format_number(game.car_income(car))) if parked else "EN RÉSERVE  ·  NE RAPPORTE RIEN"
		K.text(c, _big, _fs(0.036), info, Vector2(mid, ty + _k * 0.18), K.GOLD if parked else K.DIM, 0)
	var sep_y := drawer.position.y + _k * 0.23
	c.draw_line(Vector2(drawer.position.x + _k * 0.04, sep_y), Vector2(drawer.end.x - _k * 0.04, sep_y), K.FAINT, maxf(1.0, _k * 0.004))
	K.text(c, _big, _fs(0.04), "AMÉLIORATIONS", Vector2(drawer.position.x + _k * 0.035, sep_y + _k * 0.03 + _k * 0.05), K.ORANGE)


func _draw_mult(c: Control, i: int) -> void:
	var on := i == _mult
	var r := Rect2(Vector2.ZERO, c.size)
	K.fill_cut(c, r, c.size.y * 0.25, K.ORANGE if on else Color(1, 1, 1, 0.07))
	var label := "×%d" % MULTS[i] if MULTS[i] > 0 else "MAX"
	K.text(c, _big, _fs(0.03), label, c.size / 2.0 + Vector2(0, _fs(0.03) * 0.36), K.DARK_TEXT if on else K.INK, 0)


func _draw_tile(c: Control) -> void:
	var tile := c as Btn
	var d: Dictionary = tile.data
	if not d.has("level"):
		return
	var r := Rect2(Vector2.ZERO, c.size)
	var cut := _k * 0.03
	var locked: bool = d["locked"]
	var flash: float = d.get("flash", 0.0)
	K.fill_cut(c, r, cut, K.TILE.lerp(K.TILE_HI, flash) if not locked else Color(0.1, 0.092, 0.092, 0.85))
	if flash > 0.0:
		K.stroke_cut(c, r, cut, Color(K.GOLD.r, K.GOLD.g, K.GOLD.b, flash), maxf(2.0, _k * 0.006))
	var pad := _k * 0.025
	var ir := _k * 0.04
	var ic := Vector2(pad + ir, pad + ir)
	var p: int = d["part"]
	var name := String(Economy.PARTS[p]["name"]).to_upper()
	if locked:
		c.draw_circle(ic, ir, Color(1, 1, 1, 0.05))
		K.icon(c, "lock", ic, ir * 0.62, Color(1, 1, 1, 0.3))
		K.text(c, _text, _fs(0.034), name, Vector2(ic.x + ir + pad * 0.6, ic.y + _fs(0.034) * 0.35), Color(1, 1, 1, 0.3))
		var need := String(d["need"])
		var br := Rect2(pad, r.size.y - pad - _k * 0.07, r.size.x - pad * 2.0, _k * 0.07)
		K.fill_cut(c, br, br.size.y * 0.25, Color(1, 1, 1, 0.04))
		K.text(c, _text, _fs(0.03), "ÉTAPE " + need, br.get_center() + Vector2(0, _fs(0.03) * 0.36), Color(1, 1, 1, 0.32), 0)
		return
	c.draw_circle(ic, ir, Color(1.0, 0.5, 0.1, 0.16))
	K.icon(c, K.PART_ICONS[p], ic, ir * 0.66, K.ORANGE)
	var nfs := _fs(0.032)
	K.text(c, _text, nfs, name, Vector2(ic.x + ir + pad * 0.6, ic.y - ir * 0.15), K.INK)
	var lv := int(d["level"])
	var pop: float = d.get("pop", 0.0)
	K.text(c, _big, int(_fs(0.04) * (1.0 + 0.35 * pop)), "NIV. %d" % lv, Vector2(ic.x + ir + pad * 0.6, ic.y + ir * 0.95), K.GOLD.lerp(Color.WHITE, pop))
	# Progression vers le prochain palier ×2.
	var by := ic.y + ir + pad * 0.9
	var bar := Rect2(pad, by, r.size.x - pad * 2.0, maxf(3.0, _k * 0.011))
	K.pill(c, bar, Color(1, 1, 1, 0.08))
	var prog: float = d["progress"]
	if prog > 0.0:
		K.pill(c, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * prog), bar.size.y)), K.ORANGE)
	var nm := int(d["next"])
	K.text(c, _text, _fs(0.026), ("×2 AU NIV. %d" % nm) if nm > 0 else "NIVEAU MAX", Vector2(r.size.x - pad, by - _k * 0.008), K.DIM, 1)
	# Bouton de prix.
	var br := Rect2(pad, r.size.y - pad - _k * 0.072, r.size.x - pad * 2.0, _k * 0.072)
	if lv >= Economy.MAX_LEVEL:
		K.fill_cut(c, br, br.size.y * 0.25, Color(1, 1, 1, 0.06))
		K.text(c, _big, _fs(0.032), "MAX", br.get_center() + Vector2(0, _fs(0.032) * 0.36), K.GOLD, 0)
		return
	var ok: bool = d["affordable"]
	K.fill_cut(c, br, br.size.y * 0.25, K.ORANGE if ok else Color(1, 1, 1, 0.07))
	if ok:
		c.draw_line(br.position + Vector2(br.size.y * 0.25, br.size.y * 0.2), Vector2(br.end.x - br.size.y * 0.1, br.position.y + br.size.y * 0.2), Color(1, 1, 1, 0.25), maxf(1.0, _k * 0.004))
	var label := Economy.format_number(float(d["cost"]))
	var count := int(d["count"])
	var pfs := _fs(0.034)
	var lw := _big.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var cr := pfs * 0.38
	var extra := ("+%d " % count) if count > 1 else ""
	var ew := _text.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var total := ew + cr * 2.0 + _k * 0.012 + lw
	var x := br.get_center().x - total / 2.0
	var col := K.DARK_TEXT if ok else Color(1, 1, 1, 0.4)
	if extra != "":
		K.text(c, _text, pfs, extra, Vector2(x, br.get_center().y + pfs * 0.36), col)
	K.coin(c, Vector2(x + ew + cr, br.get_center().y), cr)
	K.text(c, _big, pfs, label, Vector2(x + ew + cr * 2.0 + _k * 0.012, br.get_center().y + pfs * 0.36), col)


func _draw_nav(c: Control, icon: String, label: String) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	K.fill_cut(c, r, _k * 0.03, Color(0.1, 0.092, 0.092, 0.92))
	K.stroke_cut(c, r, _k * 0.03, Color(1, 1, 1, 0.1), maxf(1.0, _k * 0.003))
	K.icon(c, icon, Vector2(r.size.x / 2.0, r.size.y * 0.36), _k * 0.042, K.ORANGE)
	if label == "":
		# Bouton GARAGE : l'étape et les places.
		K.text(c, _big, _fs(0.026), String(Economy.STAGES[game.stage]["name"]).to_upper(), Vector2(r.size.x / 2.0, r.size.y * 0.74), K.INK, 0)
		K.text(c, _text, _fs(0.024), "%d / %d" % [game.parked.size(), game.slots], Vector2(r.size.x / 2.0, r.size.y * 0.9), K.DIM, 0)
	else:
		K.text(c, _big, _fs(0.026), label, Vector2(r.size.x / 2.0, r.size.y * 0.8), K.INK, 0)


func _draw_serve(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var t: float = game.now()
	var rush: bool = game.rush_active(t)
	var glow := 0.5 + 0.5 * sin(_t * 6.0)
	if rush:
		K.fill_cut(c, r.grow(_k * 0.012 * glow), _k * 0.045, Color(1.0, 0.6, 0.15, 0.35))
	K.fill_cut(c, r, _k * 0.04, K.ORANGE_DEEP)
	K.fill_cut(c, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.62)), _k * 0.04, K.ORANGE)
	c.draw_line(Vector2(_k * 0.04, r.size.y * 0.12), Vector2(r.size.x - _k * 0.02, r.size.y * 0.12), Color(1, 1, 1, 0.3), maxf(1.0, _k * 0.005))
	K.text(c, _big, _fs(0.058), "SERVIR", Vector2(r.size.x / 2.0, r.size.y * 0.52), K.DARK_TEXT, 0)
	# Jauge du rush.
	var bar := Rect2(r.size.x * 0.12, r.size.y * 0.72, r.size.x * 0.76, maxf(4.0, _k * 0.018))
	K.pill(c, bar, Color(0, 0, 0, 0.35))
	var v: float = 1.0 if rush else game.rush_charge
	if rush:
		v = clampf((game.rush_until - t) / Economy.RUSH_DURATION, 0.0, 1.0)
	if v > 0.0:
		K.pill(c, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * v), bar.size.y)), K.GOLD if not rush else Color(1, 0.95, 0.8))
	K.text(c, _text, _fs(0.024), "RUSH ×2 !" if rush else "RUSH ×2", Vector2(r.size.x / 2.0, bar.end.y + _k * 0.03), K.DARK_TEXT, 0)


func _draw_fx() -> void:
	for f in _flying:
		var t := clampf(float(f[2]) / float(f[3]), 0.0, 1.0)
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var ctrl := a.lerp(b, 0.5) + Vector2((a.x - b.x) * 0.3, -_k * 0.2)
		var e := t * t * (3.0 - 2.0 * t)
		var p := a.lerp(ctrl, e).lerp(ctrl.lerp(b, e), e)
		K.coin(_fx, p, _k * 0.022 * (1.0 - 0.4 * t))


# ------------------------------------------------------------------ mise à jour

func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_visible_rect().size != _size:
		_build()
		_refresh()
	var target: float = game.coins
	_shown_coins = target if absf(target - _shown_coins) < 0.5 else lerpf(_shown_coins, target, minf(1.0, delta * 9.0))
	_coin_pulse = maxf(0.0, _coin_pulse - delta * 4.0)
	for i in range(_flying.size() - 1, -1, -1):
		_flying[i][2] += delta
		if _flying[i][2] >= _flying[i][3]:
			_flying.remove_at(i)
			_coin_pulse = 1.0
	for tile in _tiles:
		var d: Dictionary = tile.data
		if d.get("flash", 0.0) > 0.0 or d.get("pop", 0.0) > 0.0:
			d["flash"] = maxf(0.0, d.get("flash", 0.0) - delta * 2.5)
			d["pop"] = maxf(0.0, d.get("pop", 0.0) - delta * 4.0)
			tile.queue_redraw()
	_refresh_tiles()
	_hud.queue_redraw()
	_fx.queue_redraw()
	_serve.queue_redraw()


func _refresh() -> void:
	if _hud == null:
		return
	_refresh_tiles()
	for b in _mult_btns:
		b.queue_redraw()
	_garage_btn.queue_redraw()


## Données des tuiles (prix, niveaux) ; on ne redessine que celles qui changent.
func _refresh_tiles() -> void:
	var car: Dictionary = game.get_car(game.selected)
	if car.is_empty():
		return
	for tile in _tiles:
		var p: int = tile.data["part"]
		var level := int(car["levels"][p])
		var nd := {"part": p, "level": level, "locked": p >= game.unlocked_parts()}
		if nd["locked"]:
			for s in Economy.STAGES.size():
				if int(Economy.STAGES[s]["parts"]) > p:
					nd["need"] = String(Economy.STAGES[s]["name"]).to_upper()
					break
		else:
			var nm := Economy.next_milestone(level)
			var prev := 0
			for s in Economy.MILESTONES:
				if level >= s:
					prev = s
			nd["next"] = nm
			nd["progress"] = 1.0 if nm < 0 else float(level - prev) / float(nm - prev)
			if level < Economy.MAX_LEVEL:
				var q: Dictionary = game.part_quote(int(car["uid"]), p, MULTS[_mult])
				nd["cost"] = float(q["cost"])
				nd["count"] = int(q["count"])
				nd["affordable"] = game.coins >= float(q["cost"])
			else:
				nd["affordable"] = false
		var changed := false
		for key in nd:
			if not tile.data.has(key) or tile.data[key] != nd[key]:
				changed = true
				tile.data[key] = nd[key]
		tile.enabled = not nd["locked"]
		if changed:
			tile.queue_redraw()


# ------------------------------------------------------------------ actions

func _set_mult(i: int) -> void:
	_mult = i
	for b in _mult_btns:
		b.queue_redraw()
	_refresh_tiles()


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
		var tile := _tiles[part]
		tile.data["flash"] = 1.0
		tile.data["pop"] = 1.0
		var at := tile.global_position + Vector2(tile.size.x * 0.5, 0)
		_float_text("REVENU ×2 !" if big else "+%d NIV." % (after - before), at, K.GOLD if big else K.INK)


func _do_serve(local: Vector2) -> void:
	var gain: float = game.tap(game.now())
	var from := _serve.global_position + local
	for i in 3:
		_flying.append([from + Vector2(randf_range(-1, 1), randf_range(-1, 0)) * _k * 0.04, _coin_pos, -i * 0.06, 0.55 + randf() * 0.15])
	_float_text("+" + Economy.format_number(gain), from - Vector2(0, _k * 0.05), K.GOLD)


func _go_drive() -> void:
	game.save_game(game.now())
	Input.emulate_mouse_from_touch = false
	get_tree().change_scene_to_file("res://scenes/balade.tscn")


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _big)
	l.add_theme_font_size_override("font_size", _fs(0.045))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", int(_k * 0.012))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x * 0.5, l.size.y)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.5, 0.5)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - _k * 0.12, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	# Toucher une voiture garée la met sur le plateau.
	if _popup == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var uid: int = garage.car_at_screen(event.position)
		if uid >= 0:
			game.select(uid)


# ------------------------------------------------------------------ fenêtres

## Fenêtre : fond assombri, panneau à coins coupés qui surgit. Rend la colonne où ajouter
## les lignes (hauteur fixée par l'appelant via `_line_*`).
func _open_popup(title: String, rows: Array) -> void:
	_close_popup()
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_popup)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_popup())
	_popup.add_child(shade)
	var w := minf(_size.x * 0.9, _k * 1.05)
	var pad := _k * 0.045
	var h := pad * 2.0 + _k * 0.1
	for r in rows:
		h += float(r[0]) + _k * 0.02
	var panel := Control.new()
	panel.size = Vector2(w, h)
	panel.position = Vector2((_size.x - w) / 2.0, maxf(_u * 0.06, (_size.y - h) * 0.35))
	panel.draw.connect(func():
		K.fill_cut(panel, Rect2(Vector2.ZERO, panel.size), _k * 0.05, Color(0.08, 0.072, 0.075, 0.98))
		panel.draw_line(Vector2(_k * 0.05, 0), Vector2(panel.size.x, 0), K.ORANGE, maxf(2.0, _k * 0.006))
		K.text(panel, _big, _fs(0.05), title, Vector2(panel.size.x / 2.0, pad + _k * 0.055), K.ORANGE, 0))
	_popup.add_child(panel)
	var y := pad + _k * 0.1
	for r in rows:
		var row_h: float = r[0]
		var fn: Callable = r[1]
		fn.call(panel, Rect2(pad, y, w - pad * 2.0, row_h))
		y += row_h + _k * 0.02
	panel.pivot_offset = Vector2(w / 2.0, h / 2.0)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _close_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null


## Ligne de texte simple (centrée).
func _row_text(text: String, font: Font, size: int, color: Color) -> Array:
	return [size * 1.4, func(parent: Control, r: Rect2):
		var l := Control.new()
		l.position = r.position
		l.size = r.size
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.draw.connect(func(): K.text(l, font, size, text, Vector2(r.size.x / 2.0, r.size.y * 0.72), color, 0))
		parent.add_child(l)]


## Ligne « libellé ... bouton ».
func _row_action(label: String, sub: String, button: String, cost: float, enabled: bool, action: Callable, label_color := K.INK) -> Array:
	return [_k * 0.11, func(parent: Control, r: Rect2):
		var bg := Control.new()
		bg.position = r.position
		bg.size = r.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.draw.connect(func():
			K.fill_cut(bg, Rect2(Vector2.ZERO, r.size), _k * 0.025, Color(1, 1, 1, 0.04))
			K.text(bg, _text, _fs(0.036), label, Vector2(_k * 0.03, r.size.y * 0.47), label_color)
			if sub != "":
				K.text(bg, _text, _fs(0.027), sub, Vector2(_k * 0.03, r.size.y * 0.8), K.DIM))
		parent.add_child(bg)
		var bw := r.size.x * 0.38
		var b := _btn(parent, Rect2(r.end.x - bw - _k * 0.015, r.position.y + r.size.y * 0.14, bw, r.size.y * 0.72), func(c: Control):
			var rr := Rect2(Vector2.ZERO, c.size)
			K.fill_cut(c, rr, c.size.y * 0.25, K.ORANGE if enabled else Color(1, 1, 1, 0.07))
			var fs := _fs(0.03)
			var col := K.DARK_TEXT if enabled else Color(1, 1, 1, 0.4)
			if cost >= 0.0:
				var s := Economy.format_number(cost)
				var lw := _big.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var cr := fs * 0.38
				var x := (c.size.x - (cr * 2.0 + _k * 0.01 + lw)) / 2.0
				K.coin(c, Vector2(x + cr, c.size.y / 2.0), cr)
				K.text(c, _big, fs, s, Vector2(x + cr * 2.0 + _k * 0.01, c.size.y / 2.0 + fs * 0.36), col)
			else:
				K.text(c, _big, fs, button, c.size / 2.0 + Vector2(0, fs * 0.36), col, 0))
		b.enabled = enabled
		b.pressed.connect(action)]


## Grand bouton sur toute la largeur.
func _row_button(label: String, action: Callable, primary := true) -> Array:
	return [_k * 0.11, func(parent: Control, r: Rect2):
		var b := _btn(parent, r, func(c: Control):
			var rr := Rect2(Vector2.ZERO, c.size)
			K.fill_cut(c, rr, _k * 0.03, K.ORANGE if primary else Color(1, 1, 1, 0.08))
			K.text(c, _big, _fs(0.042), label, c.size / 2.0 + Vector2(0, _fs(0.042) * 0.36), K.DARK_TEXT if primary else K.INK, 0))
		b.pressed.connect(action)]


func _show_offline() -> void:
	var off: Dictionary = game.offline
	game.offline = {}
	_open_popup("PENDANT TON ABSENCE", [
		_row_text("Ton garage a tourné pendant %s." % Economy.format_duration(float(off["seconds"])), _text, _fs(0.04), K.INK),
		[_k * 0.13, func(parent: Control, r: Rect2):
			var l := Control.new()
			l.position = r.position
			l.size = r.size
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.draw.connect(func():
				var s := "+" + Economy.format_number(float(off["gain"]))
				var fs := _fs(0.09)
				var w := _big.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var cr := fs * 0.36
				var x := (r.size.x - w - cr * 2.0 - _k * 0.02) / 2.0
				K.coin(l, Vector2(x + cr, r.size.y * 0.5), cr)
				K.text(l, _big, fs, s, Vector2(x + cr * 2.0 + _k * 0.02, r.size.y * 0.5 + fs * 0.36), K.GOLD, -1, _k * 0.01))
			parent.add_child(l)],
		_row_button("RÉCUPÉRER", _close_popup),
	])


func _show_garage_menu() -> void:
	var rows: Array = []
	if game.can_buy_slot():
		rows.append(_row_action("NOUVELLE PLACE", "%d / %d places" % [game.slots, Economy.MAX_SLOTS], "", game.slot_price(), game.coins >= game.slot_price(), func():
			if game.buy_slot():
				garage.celebrate(false)
				_show_garage_menu()))
	else:
		rows.append(_row_text("Toutes les places sont achetées", _text, _fs(0.034), K.DIM))
	if game.has_next_stage():
		var nxt: Dictionary = Economy.STAGES[game.stage + 1]
		rows.append(_row_action("PASSER EN " + String(nxt["name"]).to_upper(), "débloque %d pièces par voiture" % int(nxt["parts"]), "", game.stage_price(), game.coins >= game.stage_price(), func():
			if game.buy_stage():
				garage.celebrate(true)
				_show_garage_menu()))
	else:
		rows.append(_row_text("Étape maximale : HANGAR", _text, _fs(0.034), K.DIM))
	var reserve: Array = []
	for c in game.cars:
		if not game.is_parked(int(c["uid"])):
			reserve.append(c)
	rows.append(_row_text("RÉSERVE  (%d)" % reserve.size(), _big, _fs(0.034), K.ORANGE))
	if reserve.is_empty():
		rows.append(_row_text("Spotte des voitures en balade !", _text, _fs(0.032), K.DIM))
	for c in reserve.slice(0, 4):
		var uid := int(c["uid"])
		var rarity: int = game.rarity_of(c)
		rows.append(_row_action(Catalog.display_name(String(c["model"])).to_upper(), Economy.RARITY_NAMES[rarity], "GARER", -1.0, true, func():
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
				_show_garage_menu(), K.RARITY[rarity]))
	rows.append(_row_button("FERMER", _close_popup, false))
	_open_popup("MON GARAGE", rows)
