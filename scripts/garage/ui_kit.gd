## Kit de dessin de l'interface du garage : couleurs, icônes vectorielles dessinées en
## code (pièce d'or, pièces de voiture, cadenas, garage, drapeau), formes à coins coupés.
## Tout est dessiné à la taille de l'écran (net sur tous les téléphones), sans image.
extends RefCounted

# Style cartoon (diorama) : brun chaud foncé, crème, orange et or francs.
const CHARCOAL := Color(0.14, 0.1, 0.09)
const PANEL := Color(0.17, 0.12, 0.11, 0.97)
const TILE := Color(0.26, 0.19, 0.17)
const TILE_HI := Color(0.36, 0.26, 0.2)
const INK := Color(1.0, 0.96, 0.88)
const DIM := Color(1.0, 0.94, 0.84, 0.6)
const FAINT := Color(1.0, 0.94, 0.84, 0.14)
const GOLD := Color(1.0, 0.82, 0.22)
const ORANGE := Color(1.0, 0.58, 0.12)
const ORANGE_DEEP := Color(0.85, 0.34, 0.05)
const RED := Color(0.95, 0.24, 0.14)
const DARK_TEXT := Color(0.3, 0.13, 0.03)
const RARITY: Array[Color] = [Color(0.75, 0.74, 0.72), Color(0.45, 0.88, 0.42), Color(0.36, 0.72, 1.0), Color(0.78, 0.48, 1.0), Color(1.0, 0.74, 0.22), Color(1.0, 0.32, 0.26)]
const PART_ICONS: Array[String] = ["admission", "exhaust", "tire", "chip", "turbo", "gearbox", "weight", "clutch", "wing", "nitro"]


## Polygone à coins coupés (haut gauche et bas droit), le style des boutons de la balade.
static func cut_rect(r: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.45)
	return PackedVector2Array([
		r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - c),
		r.end - Vector2(c, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, c)])


## Bloc arrondi « épais » : un rebord plus sombre dessous, comme un bouton qu'on peut
## enfoncer (style des jeux mobiles cartoon). `cut` = rayon des coins.
static func fill_cut(ci: CanvasItem, r: Rect2, cut: float, col: Color) -> void:
	var rad := int(minf(cut * 1.3, minf(r.size.x, r.size.y) * 0.5))
	var lip := maxf(2.0, minf(r.size.y * 0.08, cut * 0.7))
	if col.a > 0.5:
		var under := StyleBoxFlat.new()
		under.bg_color = Color(col.r * 0.55, col.g * 0.5, col.b * 0.5, col.a)
		under.set_corner_radius_all(rad)
		under.anti_aliasing_size = 1.0
		ci.draw_style_box(under, r)
		r = Rect2(r.position, Vector2(r.size.x, r.size.y - lip))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	sb.anti_aliasing_size = 1.0
	ci.draw_style_box(sb, r)


static func stroke_cut(ci: CanvasItem, r: Rect2, cut: float, col: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(maxf(1.0, w)))
	sb.set_corner_radius_all(int(minf(cut * 1.3, minf(r.size.x, r.size.y) * 0.5)))
	ci.draw_style_box(sb, r)


## Rectangle aux bouts arrondis (pastilles, barres).
static func pill(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var rad := r.size.y / 2.0
	if r.size.x <= r.size.y:
		ci.draw_circle(r.get_center(), rad, col)
		return
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - rad * 2.0, r.size.y)), col)
	ci.draw_circle(r.position + Vector2(rad, rad), rad, col)
	ci.draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, col)


## Pièce d'or : disque, liseré, reflet.
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0.55, 0.32, 0.05))
	ci.draw_circle(c, r, GOLD)
	ci.draw_arc(c, r * 0.72, 0, TAU, 24, Color(0.78, 0.5, 0.08), maxf(1.0, r * 0.14), true)
	ci.draw_line(c + Vector2(0, -r * 0.38), c + Vector2(0, r * 0.38), Color(0.78, 0.5, 0.08), maxf(1.0, r * 0.2))
	ci.draw_arc(c + Vector2(-r * 0.2, -r * 0.25), r * 0.35, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.55), maxf(1.0, r * 0.1), true)


## Icônes au trait, centrées sur `c`, dans un cercle de rayon `r`.
static func icon(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, r * 0.17)
	match kind:
		"admission":
			# Filtre à air : boîte ronde à lamelles et sa prise d'air.
			ci.draw_arc(c + Vector2(0, r * 0.1), r * 0.62, 0, TAU, 24, col, w, true)
			for i in 5:
				var x := (i - 2) * r * 0.22
				var h := sqrt(maxf(0.0, 1.0 - pow(x / (r * 0.62), 2.0))) * r * 0.42
				ci.draw_line(c + Vector2(x, r * 0.1 - h), c + Vector2(x, r * 0.1 + h), col, w * 0.7)
			ci.draw_line(c + Vector2(0, -r * 0.52), c + Vector2(0, -r * 0.9), col, w)
		"exhaust":
			# Deux sorties d'échappement.
			for k in [-1.0, 1.0]:
				var o := c + Vector2(k * r * 0.36, 0)
				ci.draw_arc(o, r * 0.32, 0, TAU, 18, col, w, true)
				ci.draw_circle(o, r * 0.13, col)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.55), c + Vector2(r * 0.9, r * 0.55), col, w * 0.8)
		"tire":
			ci.draw_arc(c, r * 0.78, 0, TAU, 28, col, w * 1.6, true)
			ci.draw_arc(c, r * 0.36, 0, TAU, 18, col, w, true)
			for i in 5:
				var a := TAU * i / 5.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.36, c + Vector2(cos(a), sin(a)) * r * 0.6, col, w * 0.8)
		"chip":
			# Puce de reprogrammation : carré et ses pattes.
			ci.draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.45), Vector2(r * 0.9, r * 0.9)), col, false, w)
			ci.draw_rect(Rect2(c - Vector2(r * 0.18, r * 0.18), Vector2(r * 0.36, r * 0.36)), col)
			for i in 3:
				var o := (i - 1) * r * 0.28
				for s in [-1.0, 1.0]:
					ci.draw_line(c + Vector2(o, s * r * 0.45), c + Vector2(o, s * r * 0.78), col, w * 0.7)
					ci.draw_line(c + Vector2(s * r * 0.45, o), c + Vector2(s * r * 0.78, o), col, w * 0.7)
		"turbo":
			# Escargot du turbo : spirale.
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				var a := t * TAU * 1.6
				var rr := r * (0.15 + 0.65 * t)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_polyline(pts, col, w, true)
			ci.draw_line(c + Vector2(r * 0.8, 0), c + Vector2(r * 0.8, -r * 0.8), col, w)
		"gearbox":
			# Grille de boîte en H et pommeau.
			for x in [-0.55, 0.0, 0.55]:
				ci.draw_line(c + Vector2(x * r, -r * 0.6), c + Vector2(x * r, r * 0.6), col, w)
			ci.draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(r * 0.55, 0), col, w)
			ci.draw_circle(c + Vector2(r * 0.55, -r * 0.6), r * 0.2, col)
		"weight":
			# Poids barré : allègement.
			var poly := PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.3), c + Vector2(r * 0.45, -r * 0.3), c + Vector2(r * 0.7, r * 0.65), c + Vector2(-r * 0.7, r * 0.65)])
			poly.append(poly[0])
			ci.draw_polyline(poly, col, w, true)
			ci.draw_arc(c + Vector2(0, -r * 0.48), r * 0.2, 0, TAU, 12, col, w * 0.8, true)
			ci.draw_line(c + Vector2(-r * 0.3, r * 0.2), c + Vector2(r * 0.3, r * 0.2), col, w)
		"clutch":
			# Disque d'embrayage : couronne et trous.
			ci.draw_arc(c, r * 0.8, 0, TAU, 28, col, w, true)
			ci.draw_arc(c, r * 0.26, 0, TAU, 14, col, w, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.54, r * 0.09, col)
		"wing":
			# Aileron : lame et deux pieds.
			ci.draw_line(c + Vector2(-r * 0.9, -r * 0.35), c + Vector2(r * 0.9, -r * 0.5), col, w * 1.6)
			ci.draw_line(c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(-r * 0.4, r * 0.55), col, w)
			ci.draw_line(c + Vector2(r * 0.4, -r * 0.43), c + Vector2(r * 0.4, r * 0.55), col, w)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.55), c + Vector2(r * 0.9, r * 0.55), col, w * 0.8)
		"nitro":
			# Bouteille de nitro.
			ci.draw_rect(Rect2(c + Vector2(-r * 0.32, -r * 0.4), Vector2(r * 0.64, r * 1.2)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.14, -r * 0.72), Vector2(r * 0.28, r * 0.32)), col)
			ci.draw_line(c + Vector2(-r * 0.32, r * 0.1), c + Vector2(r * 0.32, r * 0.1), col, w * 0.8)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.1), Vector2(r, r * 0.8)), col)
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.34, PI, TAU, 14, col, w, false)
		"garage":
			# Garage : toit et rideau.
			var roof := PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.15), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.9, -r * 0.15)])
			ci.draw_polyline(roof, col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.85)), col, false, w)
			for i in 3:
				var y := -r * 0.1 + r * 0.22 * (i + 1)
				ci.draw_line(c + Vector2(-r * 0.55, y), c + Vector2(r * 0.55, y), col, w * 0.6)
		"flag":
			# Drapeau à damier (la balade).
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.85), c + Vector2(-r * 0.6, r * 0.9), col, w)
			var s := r * 0.3
			for i in 4:
				for j in 3:
					if (i + j) % 2 == 0:
						ci.draw_rect(Rect2(c + Vector2(-r * 0.6 + i * s, -r * 0.85 + j * s), Vector2(s, s)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.85), Vector2(s * 4.0, s * 3.0)), col, false, w * 0.6)
		"plus":
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), col, w * 1.2)
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), col, w * 1.2)
		"chevron_left", "chevron_right":
			var d := -1.0 if kind == "chevron_left" else 1.0
			ci.draw_polyline(PackedVector2Array([c + Vector2(-d * r * 0.3, -r * 0.6), c + Vector2(d * r * 0.3, 0), c + Vector2(-d * r * 0.3, r * 0.6)]), col, w * 1.3, true)


## Losanges de rareté (1 à 6).
static func rarity_marks(ci: CanvasItem, at: Vector2, size: float, rarity: int, col: Color) -> void:
	for i in rarity + 1:
		var c := at + Vector2(i * size * 1.25, 0)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -size * 0.5), c + Vector2(size * 0.5, 0), c + Vector2(0, size * 0.5), c + Vector2(-size * 0.5, 0)]), col)


## Texte avec contour sombre, ancré à gauche, au centre ou à droite (`align` -1, 0, 1)
## sur la ligne de base `pos.y`.
static func text(ci: CanvasItem, font: Font, size: int, s: String, pos: Vector2, col: Color, align := -1, outline := 0.0) -> float:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * (0.5 if align == 0 else (1.0 if align > 0 else 0.0)), 0)
	if outline > 0.0:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(outline), Color(0, 0, 0, 0.55 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w
