## Précalcule la carte des obstacles au soleil (assets/balade/occluders.png) : pour chaque
## case de 50 cm, la hauteur du haut et du bas des objets fixes qui s'y trouvent (pins,
## palmiers, rochers, cactus, buissons, bâtiments, arbres des jardins, parasols), mesurée
## depuis leur pied, et la part de la case qu'ils couvrent. En jeu, la carte graphique en
## tire les ombres pour la position du soleil (ou de la lune) du moment
## (scripts/balade/sun_shadows.gd) : les ombres tournent et s'allongent au fil de la journée.
## Aussi : la lumière des réverbères au sol (assets/balade/lights.png).
## À relancer après tout changement de vegetation.gd, town.gd ou des rochers :
##   godot --headless --path . -s tools/bake_shadows.gd
extends SceneTree

const WL = preload("res://scripts/core/world_layout.gd")
const WorldData = preload("res://scripts/balade/world_data.gd")
const WorldBuilder = preload("res://scripts/balade/world_builder.gd")

const RES := 2048
const TEXEL := WL.SIZE / RES   # 0,5 m
const OUT := "res://assets/balade/occluders.png"
const LIGHTS := "res://assets/balade/lights.png"
## Hauteurs codées par pas de 10 cm (jusqu'à 25,5 m).
const Q := 10.0
## Échantillons fins : 2 × 2 par case (part couverte de la case).
const SUB := 2
## Haut (0 = vide) et bas des objets, par échantillon fin.
var ftop := PackedByteArray()
var fbot := PackedByteArray()


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
	# Ville, fermes, plage : bâtiments (boîtes), arbres des jardins et parasols.
	var town = load("res://scripts/balade/town.gd").new()
	town.data = data
	town._body = StaticBody3D.new()
	var trng := RandomNumberGenerator.new()
	trng.seed = 42
	town._city(trng)
	town._farms(trng)
	town._beach(trng)
	var rocks: Array = WorldBuilder.rock_placements(data)
	var fn := RES * SUB
	ftop.resize(fn * fn)
	fbot.resize(fn * fn)
	fbot.fill(255)
	var n := 0
	for key in veg._cells:
		var kind: String = key[1]
		var p: Array = veg._proto[kind]
		for xf in veg._cells[key]:
			var t := xf as Transform3D
			var s: float = t.basis.get_scale().y
			# Pied de l'objet : là où vegetation._add l'a posé (un peu enfoncé).
			var ground: float = t.origin.y + 0.15 + float(p[2]) * s
			_raster_mesh(p[0], t, ground)
			n += 1
	# Grands rochers posés par world_builder (mêmes places qu'en jeu).
	for k in (rocks[0] as Array).size():
		for xf in rocks[1][k]:
			_raster_mesh(rocks[0][k], xf, (xf as Transform3D).origin.y + (xf as Transform3D).basis.get_scale().y * 0.25)
			n += 1
	for key in town._cells:
		var path: String = key[1]
		var box: AABB = town._proto[path][1]
		for xf in town._cells[key]:
			var t := xf as Transform3D
			if path.contains("/building"):
				_box(t, box)
				n += 1
			elif path.ends_with("tree-large") or path.contains("parasol"):
				_raster_mesh(town._proto[path][0], t, t.origin.y)
				n += 1
	print("%d objets en %d ms" % [n, Time.get_ticks_msec() - t0])
	# Échantillons fins -> cases : haut le plus haut, bas le plus bas, part couverte.
	var top := PackedByteArray()
	var bot := PackedByteArray()
	var cov := PackedByteArray()
	top.resize(RES * RES)
	bot.resize(RES * RES)
	cov.resize(RES * RES)
	for z in RES:
		for x in RES:
			var o := z * SUB * fn + x * SUB
			var c := 0
			var tp := 0
			var bt := 255
			for d in [0, 1, fn, fn + 1]:
				var v: int = ftop[o + d]
				if v > 0:
					c += 1
					tp = maxi(tp, v)
					bt = mini(bt, fbot[o + d])
			var i := z * RES + x
			if c > 0:
				top[i] = tp
				bot[i] = bt
				cov[i] = c * 255 / 4
	# Les cases vides au bord d'un objet reprennent ses hauteurs (seule la part couverte
	# fait le contour) : le filtrage de la carte graphique n'écrase pas les hauteurs.
	var top2 := top.duplicate()
	var bot2 := bot.duplicate()
	for z in range(1, RES - 1):
		for x in range(1, RES - 1):
			var i := z * RES + x
			if cov[i] > 0:
				continue
			var tp := 0
			var bt := 255
			for d in [-1, 1, -RES, RES, -RES - 1, -RES + 1, RES - 1, RES + 1]:
				if cov[i + d] > 0:
					tp = maxi(tp, top[i + d])
					bt = mini(bt, bot[i + d])
			if tp > 0:
				top2[i] = tp
				bot2[i] = bt
	var img_data := PackedByteArray()
	img_data.resize(RES * RES * 3)
	for i in RES * RES:
		img_data[i * 3] = top2[i]
		img_data[i * 3 + 1] = bot2[i]
		img_data[i * 3 + 2] = cov[i]
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGB8, img_data)
	img.save_png(OUT)
	print("%s écrit en %d ms" % [OUT, Time.get_ticks_msec() - t0])
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
	quit()


## Vraie forme d'un objet vue d'en haut : chaque triangle de son maillage est rempli dans
## la carte avec sa hauteur (depuis le pied de l'objet) ; ses arêtes aussi, pour les faces
## verticales (troncs, murs) qui n'ont pas d'aire vues d'en haut.
func _raster_mesh(mesh: Mesh, xf: Transform3D, ground: float) -> void:
	var half := WL.SIZE / 2.0
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var pts := PackedVector3Array()
		pts.resize(verts.size())
		for i in verts.size():
			var w := xf * verts[i]
			pts[i] = Vector3((w.x + half) / TEXEL * SUB, maxf(w.y - ground, 0.0), (w.z + half) / TEXEL * SUB)
		var count := idx.size() if not idx.is_empty() else verts.size()
		var k := 0
		while k + 2 < count:
			var a := pts[idx[k] if not idx.is_empty() else k]
			var b := pts[idx[k + 1] if not idx.is_empty() else k + 1]
			var c := pts[idx[k + 2] if not idx.is_empty() else k + 2]
			_fill_triangle(a, b, c)
			_edge(a, b)
			_edge(b, c)
			_edge(c, a)
			k += 3


func _put(x: int, z: int, y: float) -> void:
	var n := RES * SUB
	if x < 0 or z < 0 or x >= n or z >= n:
		return
	var o := z * n + x
	var q := clampi(roundi(y * Q), 0, 254)
	ftop[o] = maxi(ftop[o], q + 1)
	fbot[o] = mini(fbot[o], q)


## Arête : échantillons tous les quarts d'échantillon fin.
func _edge(a: Vector3, b: Vector3) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := int(ceil(l * 4.0)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_put(int(floor(p.x)), int(floor(p.z)), p.y)


## Remplit un triangle (en échantillons fins) : tous ceux dont le centre est dedans, avec
## la hauteur du triangle à cet endroit.
func _fill_triangle(a3: Vector3, b3: Vector3, c3: Vector3) -> void:
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var c := Vector2(c3.x, c3.z)
	var area := (b - a).cross(c - a)
	if absf(area) < 0.05:
		return
	var ylo := minf(a3.y, minf(b3.y, c3.y))
	var yhi := maxf(a3.y, maxf(b3.y, c3.y))
	var n := RES * SUB
	var x0 := maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
	var x1 := mini(n - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
	var z0 := maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
	var z1 := mini(n - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, z + 0.5)
			var wc := (b - a).cross(p - a) / area
			var wa := (c - b).cross(p - b) / area
			var wb := (a - c).cross(p - c) / area
			if wa >= 0.0 and wb >= 0.0 and wc >= 0.0:
				_put(x, z, clampf(wa * a3.y + wb * b3.y + wc * c3.y, ylo, yhi))


## Bâtiment : son emprise au sol, à sa hauteur (plafonnée à 18 m : vue d'en haut, les
## tours plongeraient sinon toute la ville dans l'ombre).
func _box(xf: Transform3D, box: AABB) -> void:
	var sc := xf.basis.get_scale()
	var h := minf(box.size.y * sc.y, 18.0)
	var hx := box.size.x * sc.x * 0.5
	var hz := box.size.z * sc.z * 0.5
	var ax := Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
	var az := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
	var c := Vector2(xf.origin.x, xf.origin.z)
	var half := WL.SIZE / 2.0
	var r := hx + hz
	var step := TEXEL / SUB
	var n := RES * SUB
	for z in range(maxi(0, int((c.y - r + half) / step)), mini(n - 1, int((c.y + r + half) / step)) + 1):
		for x in range(maxi(0, int((c.x - r + half) / step)), mini(n - 1, int((c.x + r + half) / step)) + 1):
			var q := Vector2(x + 0.5, z + 0.5) * step - Vector2(half, half) - c
			if absf(q.dot(ax)) <= hx and absf(q.dot(az)) <= hz:
				_put(x, z, h)
				var o := z * n + x
				fbot[o] = 0


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
