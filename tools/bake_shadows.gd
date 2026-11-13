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
## Objets : silhouettes remplies à double résolution (4 échantillons par pixel), puis
## moyennées : bords nets et lisses, sans flou.
const SUB := 2
var fine := PackedByteArray()


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
	var rng_hills := RandomNumberGenerator.new()
	rng_hills.seed = 78
	veg._foothills(rng_hills)
	mask.resize(RES * RES)
	fine.resize(RES * SUB * RES * SUB)
	var sun := WorldBuilder.sun_direction()
	var dir := -Vector2(sun.x, sun.z).normalized()
	var reach := Vector2(sun.x, sun.z).length() / sun.y   # recul de l'ombre par mètre de hauteur
	var n := 0
	for key in veg._cells:
		var kind: String = key[1]
		var p: Array = veg._proto[kind]
		for xf in veg._cells[key]:
			var t := xf as Transform3D
			var s: float = t.basis.get_scale().y
			# Pied de l'objet : là où vegetation._add l'a posé (un peu enfoncé).
			var ground: float = t.origin.y + 0.15 + float(p[2]) * s
			_project_mesh(p[0], t, ground, dir, reach)
			n += 1
	# Grands rochers posés par world_builder (mêmes places qu'en jeu).
	var rocks: Array = WorldBuilder.rock_placements(data)
	for k in (rocks[0] as Array).size():
		for xf in rocks[1][k]:
			_project_mesh(rocks[0][k], xf, (xf as Transform3D).origin.y + (xf as Transform3D).basis.get_scale().y * 0.25, dir, reach)
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
			elif path.ends_with("tree-large") or path.contains("parasol"):
				_project_mesh(town._proto[path][0], t, t.origin.y, dir, reach)
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
	# Échantillons fins -> couverture de chaque pixel (0, 1/4, 1/2, 3/4, 1).
	var fw := RES * SUB
	for z in RES:
		for x in RES:
			var o := z * SUB * fw + x * SUB
			var cover := (fine[o] + fine[o + 1] + fine[o + fw] + fine[o + fw + 1]) * 0.25
			if cover > 0.0:
				mask[z * RES + x] = maxf(mask[z * RES + x], cover)
	var img := Image.create(RES, RES, false, Image.FORMAT_L8)
	for i in RES * RES:
		var v := clampf(mask[i], 0.0, 1.0)
		img.set_pixel(i % RES, i / RES, Color(v, v, v))
	img.save_png(OUT)
	print("%d objets, %s écrit en %d ms" % [n, OUT, Time.get_ticks_msec() - t0])
	quit()


## Ombre d'un objet : des disques le long de sa hauteur, chacun projeté au sol dans la
## direction opposée au soleil (profil de rayon selon le type d'objet).
## Ombre portée de la vraie forme d'un objet : chaque triangle de son maillage est projeté
## au sol le long des rayons du soleil (un point à y mètres au-dessus du pied recule de
## y × reach), puis rempli dans la carte. La silhouette de l'ombre est celle de l'objet.
func _project_mesh(mesh: Mesh, xf: Transform3D, ground: float, dir: Vector2, reach: float) -> void:
	var half := WL.SIZE / 2.0
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var pts := PackedVector2Array()
		pts.resize(verts.size())
		for i in verts.size():
			var w := xf * verts[i]
			var p := Vector2(w.x, w.z) + dir * (maxf(w.y - ground, 0.0) * reach)
			pts[i] = (p + Vector2(half, half)) / TEXEL * SUB
		var count := idx.size() if not idx.is_empty() else verts.size()
		var k := 0
		while k + 2 < count:
			var a := pts[idx[k] if not idx.is_empty() else k]
			var b := pts[idx[k + 1] if not idx.is_empty() else k + 1]
			var c := pts[idx[k + 2] if not idx.is_empty() else k + 2]
			_fill_triangle(a, b, c)
			k += 3


## Remplit un triangle (en échantillons fins) : tous ceux dont le centre est dedans.
func _fill_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	# Triangle légèrement élargi (un demi-échantillon) : les tiges fines (troncs, mâts)
	# gardent une ombre continue au lieu d'une ligne de pointillés.
	var g := (a + b + c) / 3.0
	a += (a - g).normalized() * 0.5
	b += (b - g).normalized() * 0.5
	c += (c - g).normalized() * 0.5
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-4:
		return
	var n := RES * SUB
	var x0 := maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
	var x1 := mini(n - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
	var z0 := maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
	var z1 := mini(n - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, z + 0.5)
			var w0 := (b - a).cross(p - a) / area
			var w1 := (c - b).cross(p - b) / area
			var w2 := (a - c).cross(p - c) / area
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				fine[z * n + x] = 1


## Bords adoucis : un léger flou (noyau 1-2-1 dans les deux sens) sur toute la carte.
func _soften() -> void:
	var tmp := PackedFloat32Array()
	tmp.resize(RES * RES)
	for z in RES:
		var row := z * RES
		for x in range(1, RES - 1):
			tmp[row + x] = (mask[row + x - 1] + 2.0 * mask[row + x] + mask[row + x + 1]) * 0.25
	for z in range(1, RES - 1):
		var row := z * RES
		for x in RES:
			mask[row + x] = (tmp[row + x - RES] + 2.0 * tmp[row + x] + tmp[row + x + RES]) * 0.25


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
