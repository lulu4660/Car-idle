## Voitures à spotter pendant la balade : quelques voitures du catalogue garées au bord de
## la piste, chacune signalée par un faisceau de lumière de la couleur de sa rareté (visible
## de loin, de jour comme de nuit). On passe tout près pour la spotter : gain immédiat et
## la voiture rejoint le garage (Game.spot). Une autre apparaît ailleurs un peu plus tard.
## Une flèche au bord de l'écran montre la plus proche, avec sa distance.
extends Node3D

const WL = preload("res://scripts/core/world_layout.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const CarModels = preload("res://scripts/game/car_models.gd")

const ACTIVE := 6
const SPOT_RADIUS := 9.0
const RESPAWN_DELAY := 25.0
const MIN_SPAWN_DIST := 140.0
const RARITY_COLORS: Array[Color] = [Color(0.85, 0.85, 0.8), Color(0.45, 0.95, 0.4), Color(0.35, 0.7, 1.0), Color(0.8, 0.45, 1.0), Color(1.0, 0.75, 0.2), Color(1.0, 0.3, 0.25)]

var data: RefCounted
var game: Node
var target: Node3D
var camera: Camera3D
## Voitures en place : [nœud, modèle, rareté, anneau, faisceau].
var _cars: Array = []
var _pending: Array[float] = []
var _road: PackedVector2Array
var _rng := RandomNumberGenerator.new()
var _layer: CanvasLayer
var _arrow: Control
var _toast: Control
var _big: Font
var _text: Font
var _t := 0.0


func build(world_data: RefCounted, follow: Node3D, cam: Camera3D) -> void:
	data = world_data
	target = follow
	camera = cam
	game = get_node_or_null("/root/Game")
	_rng.randomize()
	_road = WL.road_polyline()
	_big = load("res://assets/fonts/RussoOne-Regular.ttf")
	_text = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_arrow = Control.new()
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	_layer.add_child(_arrow)
	if game == null:
		return
	for i in ACTIVE:
		_spawn(i < 2)


## Une voiture à spotter au bord de la piste, loin du joueur (`near` : la première à moins
## de 250 m, pour qu'on en trouve vite une).
func _spawn(near := false) -> void:
	var pos := Vector3.ZERO
	var yaw := 0.0
	for attempt in 40:
		var i := _rng.randi() % _road.size()
		var a := _road[i]
		var b := _road[(i + 1) % _road.size()]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (WL.ROAD_HALF + 3.5) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := a.lerp(b, _rng.randf()) + side
		var d := Vector2(target.global_position.x, target.global_position.z).distance_to(p) if target else 1000.0
		if d < MIN_SPAWN_DIST or (near and d > 250.0):
			continue
		var too_close := false
		for c in _cars:
			if (c[0] as Node3D).global_position.distance_to(Vector3(p.x, 0, p.y)) < 60.0:
				too_close = true
		if too_close:
			continue
		var y: float = data.height_at(p.x, p.y)
		if y < WL.SEA_LEVEL + 0.3:
			continue
		pos = Vector3(p.x, y, p.y)
		yaw = atan2(dir.x, dir.y) + (PI / 2.0 if _rng.randf() < 0.5 else 0.0) * 0.4
		break
	if pos == Vector3.ZERO:
		return
	var model: String = game.roll_spot_model()
	var rarity := int(Catalog.get_car(model)["rarity"])
	var node := Node3D.new()
	add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var color := Color.html(String(Catalog.get_car(model)["color"]))
	var mi := CarModels.showroom(CarModels.kit_for(model), color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var rc := RARITY_COLORS[rarity]
	var beam := _beam(rc, 26.0 + rarity * 6.0)
	node.add_child(beam)
	var ring := _ring(rc)
	node.add_child(ring)
	_cars.append([node, model, rarity, ring, beam])


func _additive(c: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = c
	m.albedo_texture = tex
	return m


## Faisceau vertical, plus intense en bas, qui s'efface en hauteur.
func _beam(c: Color, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.3
	cyl.bottom_radius = 0.7
	cyl.height = h
	cyl.radial_segments = 12
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	mi.material_override = _additive(c, tex)
	mi.position.y = h / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Anneau au sol qui pulse autour de la voiture.
func _ring(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(SPOT_RADIUS * 2.0, SPOT_RADIUS * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.9, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	mi.material_override = _additive(c, tex)
	mi.position.y = 0.25
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _process(delta: float) -> void:
	if game == null or target == null or not is_instance_valid(target):
		return
	_t += delta
	var me := target.global_position
	for i in range(_cars.size() - 1, -1, -1):
		var c: Array = _cars[i]
		var node := c[0] as Node3D
		var ring := c[3] as Node3D
		var k := 1.0 + 0.08 * sin(_t * 4.0 + i)
		ring.scale = Vector3(k, 1.0, k)
		var d := Vector2(me.x - node.global_position.x, me.z - node.global_position.z).length()
		if d < SPOT_RADIUS:
			_cars.remove_at(i)
			_spotted(c)
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] <= 0.0:
			_pending.remove_at(i)
			_spawn()
	_arrow.queue_redraw()


func _spotted(c: Array) -> void:
	var node := c[0] as Node3D
	var info: Dictionary = game.spot(String(c[1]), game.now())
	_pending.append(RESPAWN_DELAY)
	# La voiture s'envole vers le haut en rétrécissant (direction le garage).
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", node.position.y + 6.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(node.queue_free)
	if not info.is_empty():
		_show_toast(info)


# ------------------------------------------------------------------ affichage

func _show_toast(info: Dictionary) -> void:
	if _toast:
		_toast.queue_free()
	var size := get_viewport().get_visible_rect().size
	var u := minf(size.x, size.y)
	var rarity := int(info["rarity"])
	var rc := RARITY_COLORS[rarity]
	_toast = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.07, 0.85)
	sb.border_color = rc
	sb.border_width_bottom = maxi(2, int(u * 0.006))
	sb.border_width_top = maxi(2, int(u * 0.006))
	sb.content_margin_left = u * 0.04
	sb.content_margin_right = u * 0.04
	sb.content_margin_top = u * 0.015
	sb.content_margin_bottom = u * 0.015
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_toast)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_toast.add_child(col)
	var title := "NOUVELLE VOITURE !" if info["is_new"] else "SPOTTÉE !"
	_line(col, title, _big, int(u * 0.05), rc)
	_line(col, Catalog.display_name(String(info["model"])).to_upper(), _big, int(u * 0.045), Color(0.96, 0.93, 0.88))
	var where := "GARÉE AU GARAGE" if info["parked"] else "EN RÉSERVE AU GARAGE"
	_line(col, "%s  ·  +%s  ·  %s" % [Economy.RARITY_NAMES[rarity].to_upper(), Economy.format_number(float(info["gain"])), where], _text, int(u * 0.034), Color(1.0, 0.78, 0.25))
	_toast.reset_size()
	_toast.position = Vector2((size.x - _toast.size.x) / 2.0, size.y * 0.2)
	_toast.pivot_offset = _toast.size / 2.0
	_toast.scale = Vector2(0.5, 0.5)
	_toast.modulate.a = 0.0
	var t := _toast
	var tw := t.create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(t, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(t.queue_free)


func _line(parent: Node, text: String, font: Font, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


## Flèche au bord de l'écran vers la voiture à spotter la plus proche (si elle n'est pas
## déjà bien visible), avec sa distance.
func _draw_arrow() -> void:
	if camera == null or _cars.is_empty() or target == null:
		return
	var me := target.global_position
	var best: Array = []
	var bd := INF
	for c in _cars:
		var d := me.distance_to((c[0] as Node3D).global_position)
		if d < bd:
			bd = d
			best = c
	var size := _arrow.size
	var u := minf(size.x, size.y)
	var pos := (best[0] as Node3D).global_position + Vector3(0, 1.0, 0)
	var center := size / 2.0
	var behind := camera.is_position_behind(pos)
	var sp := camera.unproject_position(pos)
	# La flèche tourne sur un cercle autour du centre de l'écran (jamais sur les boutons).
	var radius := u * 0.36
	var inside := not behind and sp.distance_to(center) < radius
	if inside and bd < 120.0:
		return
	var dir := (sp - center)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var p := center + dir * radius
	if inside:
		p = sp
	var rc := RARITY_COLORS[int(best[2])]
	var a := u * 0.035
	var pulse := 1.0 + 0.12 * sin(_t * 5.0)
	var side := Vector2(-dir.y, dir.x)
	var tip := p + dir * a * pulse
	var pts := PackedVector2Array([tip, p - dir * a * 0.6 + side * a * 0.8, p - dir * a * 0.2, p - dir * a * 0.6 - side * a * 0.8])
	_arrow.draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	var pts2 := PackedVector2Array()
	for q in pts:
		pts2.append(p + (q - p) * 0.8)
	_arrow.draw_colored_polygon(pts2, rc)
	var txt := "%d m" % int(bd)
	var fs := int(u * 0.032)
	var tw := _text.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := p - dir * a * 1.6 + Vector2(-tw / 2.0, fs * 0.35)
	_arrow.draw_string_outline(_text, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(u * 0.008), Color(0, 0, 0, 0.6))
	_arrow.draw_string(_text, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, rc)
