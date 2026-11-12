## Précalcule les ombres du décor fixe (assets/balade/shadows.png) : le soleil de la balade
## ne bouge pas, donc l'ombre des pins, palmiers, rochers, cactus et buissons au sol est
## toujours la même. On la dessine une fois ici (2048², 50 cm par pixel, bords adoucis), et
## le terrain la lit : plus de passe d'ombre en temps réel pour des milliers d'arbres, et
## des bords lisses à toute résolution.
## À relancer après tout changement de vegetation.gd (placement, modèles) ou du soleil :
##   godot --headless --path . -s tools/bake_shadows.gd
extends SceneTree

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")
const WorldBuilder = preload("res://scripts/balade/world_builder.gd")

const RES := 2048
const TEXEL := WL.SIZE / RES   # 0,5 m
const OUT := "res://assets/balade/shadows.png"
const LIGHTS := "res://assets/balade/lights.png"

var mask := PackedFloat32Array()


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var data = WorldData.load_baked()
	var veg = load("res://scripts/balade/vegetation.gd").new()
	veg.data = data
	veg._body = StaticBody3D.new()
	# Même tirage que vegetation.build() : mêmes arbres aux mêmes places.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	veg._forest(rng)
	veg._dunes(rng)
	veg._beach(rng)
	mask.resize(RES * RES)
	var sun := WorldBuilder.sun_direction()
	var dir := -Vector2(sun.x, sun.z).normalized()
	var reach := Vector2(sun.x, sun.z).length() / sun.y   # recul de l'ombre par mètre de hauteur
	var n := 0
	for key in veg._cells:
		var kind: String = key[1]
		var p: Array = veg._proto[kind]
		for xf in veg._cells[key]:
			var s: float = (xf as Transform3D).basis.get_scale().y
			var h: float = p[1] * s
			var base := Vector2(xf.origin.x, xf.origin.z)
			_object(kind, base, h, dir, reach)
			n += 1
	# Ville, fermes, plage : bâtiments (boîtes), arbres des jardins et parasols.
	var town = load("res://scripts/balade/town.gd").new()
	town.data = data
	town._body = StaticBody3D.new()
	var trng := RandomNumberGenerator.new()
	trng.seed = 42
	town._city(trng)
	town._farms(trng)
	town._beach(trng)
	for key in town._cells:
		var path: String = key[1]
		var box: AABB = town._proto[path][1]
		for xf in town._cells[key]:
			var t := xf as Transform3D
			if path.contains("/building"):
				_box_shadow(t, box, dir, reach)
				n += 1
			elif path.ends_with("tree-large"):
				_object("tree_round", Vector2(t.origin.x, t.origin.z), box.size.y * t.basis.get_scale().y, dir, reach)
				n += 1
			elif path.contains("parasol"):
				var h := box.size.y * t.basis.get_scale().y
				_disc(Vector2(t.origin.x, t.origin.z) + dir * (h * 0.85 * reach), h * 0.5)
				n += 1
	# Nuit : la lumière des réverbères au sol (assets/balade/lights.png).
	var lamps: Array = load("res://scripts/balade/lamps.gd").positions(data, town)
	var light := PackedFloat32Array()
	light.resize(RES * RES)
	var Lamps = load("res://scripts/balade/lamps.gd")
	for l in lamps:
		var p: Vector3 = l[0]
		var d: Vector2 = l[1]
		var style: int = l[2]
		_glow(light, Vector2(p.x, p.z) + d * Lamps.LAMP_REACH[style], Lamps.GLOW_RADIUS[style])
	var limg := Image.create(RES, RES, false, Image.FORMAT_L8)
	for i in RES * RES:
		var v := clampf(light[i], 0.0, 1.0)
		limg.set_pixel(i % RES, i / RES, Color(v, v, v))
	limg.save_png(LIGHTS)
	print("%d réverbères, %s écrit" % [lamps.size(), LIGHTS])
	var img := Image.create(RES, RES, false, Image.FORMAT_L8)
	for i in RES * RES:
		var v := clampf(mask[i], 0.0, 1.0)
		img.set_pixel(i % RES, i / RES, Color(v, v, v))
	img.save_png(OUT)
	print("%d objets, %s écrit en %d ms" % [n, OUT, Time.get_ticks_msec() - t0])
	quit()


## Ombre d'un objet : des disques le long de sa hauteur, chacun projeté au sol dans la
## direction opposée au soleil (profil de rayon selon le type d'objet).
func _object(kind: String, base: Vector2, h: float, dir: Vector2, reach: float) -> void:
	var step := 0.6
	var y := 0.0
	while y <= h:
		var t := y / maxf(h, 0.01)
		var r := 0.0
		if kind.begins_with("tree_pine"):
			var wide := 0.2 if kind.contains("Tall") else 0.3
			r = 0.22 if t < 0.15 else h * wide * (1.0 - (t - 0.15) / 0.85) + 0.15
		elif kind.begins_with("tree_palm"):
			r = 0.18 if t < 0.82 else h * 0.32 * (1.0 - absf(t - 0.92) / 0.12)
		elif kind == "tree_round":
			r = 0.2 if t < 0.35 else h * 0.32 * sqrt(maxf(0.0, 1.0 - pow((t - 0.67) / 0.33, 2.0)))
		elif kind.begins_with("cactus"):
			r = 0.28 if t < 0.35 or t > 0.75 else 0.55
		elif kind.begins_with("rock"):
			r = h * 0.55 * sqrt(maxf(0.0, 1.0 - t))
		else:
			r = h * 0.65 * sqrt(maxf(0.0, 1.0 - t))
		if r > 0.05:
			_disc(base + dir * (y * reach), r)
		y += step


## Disque adouci (bord de ~0,5 m) dans la carte des ombres.
func _disc(c: Vector2, r: float) -> void:
	var half := WL.SIZE / 2.0
	var gx := (c.x + half) / TEXEL
	var gz := (c.y + half) / TEXEL
	var rr := r / TEXEL + 1.0
	for z in range(maxi(0, int(gz - rr)), mini(RES - 1, int(gz + rr)) + 1):
		for x in range(maxi(0, int(gx - rr)), mini(RES - 1, int(gx + rr)) + 1):
			var d := Vector2(x + 0.5 - gx, z + 0.5 - gz).length() * TEXEL
			var cover := clampf((r - d) / 0.5 + 0.5, 0.0, 1.0)
			if cover > 0.0:
				var o := z * RES + x
				mask[o] = maxf(mask[o], cover)


## Ombre d'un bâtiment : son emprise au sol, répétée le long de la direction de l'ombre à
## chaque mètre de hauteur (le volume projeté d'une boîte).
func _box_shadow(xf: Transform3D, box: AABB, dir: Vector2, reach: float) -> void:
	var sc := xf.basis.get_scale()
	# Ombre plafonnée à celle d'un immeuble de 18 m : vue d'en haut, les tours plongeraient
	# sinon toute la ville dans l'ombre.
	var h := minf(box.size.y * sc.y, 18.0)
	var hx := box.size.x * sc.x * 0.5
	var hz := box.size.z * sc.z * 0.5
	var ax := Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
	var az := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
	var c := Vector2(xf.origin.x, xf.origin.z)
	var half := WL.SIZE / 2.0
	var top := c + dir * (h * reach)
	var lo := Vector2(minf(c.x, top.x), minf(c.y, top.y)) - Vector2.ONE * (hx + hz)
	var hi := Vector2(maxf(c.x, top.x), maxf(c.y, top.y)) + Vector2.ONE * (hx + hz)
	var len := h * reach
	for z in range(maxi(0, int((lo.y + half) / TEXEL)), mini(RES - 1, int((hi.y + half) / TEXEL)) + 1):
		for x in range(maxi(0, int((lo.x + half) / TEXEL)), mini(RES - 1, int((hi.x + half) / TEXEL)) + 1):
			var p := Vector2(x + 0.5, z + 0.5) * TEXEL - Vector2(half, half) - c
			# Recule le point vers le bâtiment le long de l'ombre : dans l'emprise à une hauteur ?
			var t := clampf(p.dot(dir), 0.0, len)
			var q := p - dir * t
			var u := absf(q.dot(ax)) - hx
			var v := absf(q.dot(az)) - hz
			var outside := maxf(u, v)
			var cover := clampf(0.5 - outside / 0.5, 0.0, 1.0)
			if cover > 0.0:
				var o := z * RES + x
				mask[o] = maxf(mask[o], cover)


## Flaque de lumière d'un réverbère : forte sous la lampe, qui s'éteint doucement.
func _glow(buf: PackedFloat32Array, c: Vector2, r: float) -> void:
	var half := WL.SIZE / 2.0
	var gx := (c.x + half) / TEXEL
	var gz := (c.y + half) / TEXEL
	var rr := r / TEXEL
	for z in range(maxi(0, int(gz - rr)), mini(RES - 1, int(gz + rr)) + 1):
		for x in range(maxi(0, int(gx - rr)), mini(RES - 1, int(gx + rr)) + 1):
			var d := Vector2(x + 0.5 - gx, z + 0.5 - gz).length() / rr
			if d < 1.0:
				var o := z * RES + x
				buf[o] = minf(1.0, buf[o] + pow(1.0 - d, 1.6))
