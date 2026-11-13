## Tests des règles du jeu, sans affichage :
##   godot --headless --path . -s tests/run_tests.gd
extends SceneTree

const Economy = preload("res://scripts/core/economy.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const WL = preload("res://scripts/core/world_layout.gd")

var _failures := 0
var _count := 0


func _init() -> void:
	_test_costs()
	_test_affordable()
	_test_income()
	_test_offline()
	_test_rarity()
	_test_format()
	_test_progression()
	_test_missions_and_achievements()
	_test_collections()
	_test_world_layout()
	_test_game_state()
	print("%d vérifications, %d échec(s)" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_count += 1
	if not cond:
		_failures += 1
		printerr("ÉCHEC : " + what)


func near(a: float, b: float, rel := 1e-9) -> bool:
	return absf(a - b) <= rel * maxf(1.0, absf(b))


func _test_costs() -> void:
	check(near(Economy.part_cost(0, 0), 20.0), "coût niv 0 commune = 20")
	check(near(Economy.part_cost(5, 10), 20.0 * 100.0 * pow(1.1, 10)), "coût suit 20 × B × 1,10^ℓ")
	var total := 0.0
	for l in range(7, 7 + 25):
		total += Economy.part_cost(2, l)
	check(near(Economy.cost_for_levels(2, 7, 25), total), "somme géométrique = somme niveau par niveau")
	check(Economy.cost_for_levels(0, 0, 0) == 0.0, "0 niveau ne coûte rien")
	check(near(Economy.slot_cost(4), 500.0), "4e place = 100 × 5")
	check(near(Economy.slot_cost(3), 100.0), "place n = 100 × 5^(n−3)")


func _test_affordable() -> void:
	check(Economy.max_affordable(0, 0, 19.99) == 0, "pas assez pour 1 niveau")
	check(Economy.max_affordable(0, 0, 20.0) == 1, "pile 1 niveau")
	var budget := Economy.cost_for_levels(1, 3, 17)
	check(Economy.max_affordable(1, 3, budget) == 17, "budget exact de 17 niveaux")
	check(Economy.max_affordable(1, 3, budget * 0.999) == 16, "un peu moins = 16")
	check(Economy.max_affordable(0, 195, 1e300) == 5, "plafonné au niveau 200")
	check(Economy.max_affordable(0, 0, INF) == 200, "budget illimité = tout")


func _test_income() -> void:
	var zero: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	check(near(Economy.car_income(0, zero), 1.0), "commune neuve = 1 pièce/s (revenu de base du GDD)")
	check(near(Economy.car_income(5, zero), 100.0), "mythique neuve = 100 pièces/s")
	check(Economy.milestones_passed(24) == 0 and Economy.milestones_passed(25) == 1 and Economy.milestones_passed(200) == 5, "paliers 25/…/200")
	check(Economy.next_milestone(25) == 50 and Economy.next_milestone(200) == -1, "prochain palier")
	var one: Array[int] = [25, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	check(near(Economy.car_income(0, one), (26.0 * 2.0 + 9.0) / 10.0), "x2 sur la seule pièce au palier")
	# Régression v1 du GDD : les paliers des pièces ne doivent jamais se multiplier entre eux.
	var all_max: Array[int] = [200, 200, 200, 200, 200, 200, 200, 200, 200, 200]
	check(near(Economy.car_income(0, all_max), 201.0 * 32.0), "max théorique additif = 201 × 2⁵ par commune")
	check(near(Economy.collection_multiplier(12), 1.12), "+1 % par modèle unique")


func _test_offline() -> void:
	check(near(Economy.offline_gain(10.0, 3600.0), 36000.0), "1 h hors ligne à 100 %")
	check(near(Economy.offline_gain(10.0, 4.0 * 3600.0), 10.0 * (7200.0 + 0.5 * 7200.0)), "4 h : 2 h pleines + 2 h à 50 %")
	check(near(Economy.offline_gain(10.0, 48.0 * 3600.0), 10.0 * (7200.0 + 0.5 * 21600.0)), "plafond à 8 h")
	check(Economy.offline_gain(10.0, -50.0) == 0.0, "horloge reculée : rien")


func _test_rarity() -> void:
	check(Economy.roll_rarity(0.0) == 0 and Economy.roll_rarity(0.5999) == 0, "60 % communes")
	check(Economy.roll_rarity(0.6) == 1 and Economy.roll_rarity(0.849) == 1, "25 % peu communes")
	check(Economy.roll_rarity(0.9995) == 5, "0,1 % mythiques")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 100000:
		counts[Economy.roll_rarity(rng.randf())] += 1
	check(absf(counts[0] / 100000.0 - 0.60) < 0.01 and absf(counts[2] / 100000.0 - 0.10) < 0.01, "distribution des raretés")
	check(near(Economy.spot_gain(0, 2.0), 2.0 * 20.0 * 60.0), "spot commune = 20 min de revenu")


func _test_format() -> void:
	check(Economy.format_number(999.0) == "999", "999")
	check(Economy.format_number(1.5) == "1,5", "1,5")
	check(Economy.format_number(12345.0) == "12,3 K", "12,3 K, got " + Economy.format_number(12345.0))
	check(Economy.format_number(2.0e6) == "2,00 M", "2,00 M")
	check(Economy.format_number(999999.0) == "1,00 M", "arrondi au suffixe suivant, got " + Economy.format_number(999999.0))
	check(Economy.format_number(1.0e15) == "1,00 aa", "après T : aa")
	check(Economy.format_number(9.96) == "10", "9,96 s'affiche 10")


func _test_progression() -> void:
	check(Progression.prestige_points(Progression.PRESTIGE_DIVISOR) == 1 and Progression.prestige_points(Progression.PRESTIGE_DIVISOR * 100.0) == 10, "points de prestige en racine carrée")
	check(Progression.prestige_points(0.0) == 0, "pas de point sans gains")
	check(near(Progression.earnings_for_points(3), 9.0 * Progression.PRESTIGE_DIVISOR), "gains pour 3 points")
	check(near(Progression.rep_bonus(4), 0.2), "réputation : +10 % × √points")
	var ids := {}
	for sk in Progression.SKILLS:
		var pre := Progression.prerequisite(String(sk["id"]))
		check(pre == "" or Progression.skill(pre)["branch"] == sk["branch"], "prérequis dans la même branche : %s" % sk["id"])
		ids[sk["id"]] = true
		for k in sk["fx"]:
			check(Progression.empty_effects().has(k), "effet connu : %s" % k)
	check(ids.size() == 24, "24 compétences (4 branches × 6)")
	var fx := Progression.empty_effects()
	Progression.add_effects(fx, Progression.skill("s2")["fx"])
	Progression.add_effects(fx, Progression.skill("s4")["fx"])
	check(near(fx["extra_spots"], 3.0), "spots en plus par balade : 1 + 2")
	Progression.add_effects(fx, Progression.skill("a1")["fx"])
	Progression.add_effects(fx, Progression.skill("a3")["fx"])
	check(near(fx["upgrade_cost_mult"], 0.9 * 0.85), "réductions de coût multipliées")


func _test_missions_and_achievements() -> void:
	var a := Progression.daily_missions("2026-11-11")
	var b := Progression.daily_missions("2026-11-11")
	check(a.size() == 3, "3 missions par jour")
	check(a[0]["id"] == b[0]["id"] and a[2]["goal"] == b[2]["goal"], "mêmes missions le même jour")
	check(a[0]["id"] != a[1]["id"] and a[1]["id"] != a[2]["id"] and a[0]["id"] != a[2]["id"], "3 missions différentes")
	var differs := false
	for d in ["2026-11-12", "2026-11-13", "2026-11-14"]:
		if Progression.daily_missions(d)[0]["id"] != a[0]["id"]:
			differs = true
	check(differs, "les missions changent selon les jours")
	check(Progression.stable_hash("abc") == 440920331, "hachage FNV-1a stable")
	var seen := {}
	for g in Progression.ACHIEVEMENTS:
		check(not seen.has(g["id"]), "succès unique : %s" % g["id"])
		seen[g["id"]] = true
		check(g["reward"].has("minutes"), "récompense en minutes : %s" % g["id"])
	check(seen.has("first_spot") and seen.has("drives_10"), "succès de balade présents")


func _test_collections() -> void:
	var jdm: Dictionary = Progression.SERIES[2]
	check(Progression.series_tier(jdm, 1) == 0 and Progression.series_tier(jdm, 2) == 1 and Progression.series_tier(jdm, 5) == 3, "paliers de la série JDM")
	check(near(Progression.series_bonus(2), 0.06), "bonus des paliers additionnés")
	var count := 0
	for car in Catalog.CARS:
		if Progression.in_series(jdm, car):
			count += 1
	check(count >= 3, "le catalogue a des voitures JDM")


func _test_world_layout() -> void:
	var half := WL.SIZE / 2.0
	var worst := 0.0
	var x := -half
	while x < half - 2.0:
		var z := -half
		while z < half - 2.0:
			# Les montagnes du bord (fin de carte) peuvent être raides ; la vallée, non.
			if WL.mountain_factor(x, z) < 0.02 and WL.mountain_factor(x + 2.0, z + 2.0) < 0.02:
				var h := WL.height(x, z)
				worst = maxf(worst, absf(WL.height(x + 2.0, z) - h))
				worst = maxf(worst, absf(WL.height(x, z + 2.0) - h))
			z += 6.0
		x += 2.0
	check(worst < 1.6, "pas de falaise (pire dénivelé sur 2 m : %.2f)" % worst)
	x = WL.CITY_START
	while x < WL.CITY_END - 30.0:
		var z := -WL.VALLEY_HALF + 20.0
		while z < WL.VALLEY_HALF - 20.0:
			check(absf(WL.height(x, z) - WL.GROUND_LEVEL) < 1e-4, "ville plate (%d, %d)" % [x, z])
			z += 41.0
		x += 37.0
	# Fin de carte : montagnes à l'ouest, au nord et au sud.
	for e in [Vector2(-half + 10.0, 0.0), Vector2(0.0, -half + 10.0), Vector2(-100.0, half - 10.0)]:
		check(WL.height(e.x, e.y) > WL.GROUND_LEVEL + 35.0, "montagnes au bord (%d, %d)" % [e.x, e.y])
	check(_at(-380.0, 0.0) == WL.Surface.ASPHALT and _at(-20.0, 0.0) == WL.Surface.DIRT and _at(250.0, 0.0) == WL.Surface.SAND and _at(480.0, 0.0) == WL.Surface.WATER, "zones dans l'ordre d'ouest en est")
	var z2 := -half
	while z2 < half:
		check(WL.height(half - 5.0, z2) < WL.SEA_LEVEL - 1.0, "mer à l'est")
		check(WL.height(WL.DUNES_END - 40.0, z2) > WL.SEA_LEVEL + 1.0, "dunes au sec")
		z2 += 40.0
	var hs := WL.height(WL.SPAWN_X, WL.SPAWN_Z)
	check(hs > WL.SEA_LEVEL + 1.0 and WL.surface_at(WL.SPAWN_X, WL.SPAWN_Z, hs) == WL.Surface.SAND, "départ sur le sable sec")
	check(WL.grip(WL.Surface.ASPHALT) > WL.grip(WL.Surface.DIRT) and WL.grip(WL.Surface.DIRT) > WL.grip(WL.Surface.SAND) and WL.grip(WL.Surface.SAND) > WL.grip(WL.Surface.WATER), "adhérence : bitume > terre > sable > eau")
	check(WL.is_street(5.0, 30.0) and not WL.is_street(40.0, 40.0), "rues et pâtés de maisons")


func _at(x: float, z: float) -> int:
	return WL.surface_at(x, z, WL.height(x, z))


func _test_game_state() -> void:
	var g: Node = load("res://scripts/game/game_state.gd").new()
	g.no_save = true
	var t := 1000.0
	g.new_game(t)
	check(g.cars.size() == 1 and g.parked.size() == 1 and g.selected == g.cars[0]["uid"], "partie neuve : une voiture garée et choisie")
	var inc: float = g.base_income()
	check(near(inc, 1.0 * 1.01), "revenu de départ 1/s × bonus de collection")
	# Revenus calculés depuis la dernière récolte, pas additionnés image par image.
	g.settle(t + 10.0)
	check(near(g.coins, inc * 10.0), "10 s de revenus")
	g.settle(t + 10.0)
	check(near(g.coins, inc * 10.0), "deux récoltes au même instant ne paient qu'une fois")
	# SERVIR : 20 appuis -> rush ×2 pendant 30 s.
	t += 10.0
	for i in 20:
		g.tap(t)
	check(g.rush_active(t) and not g.rush_active(t + 31.0), "rush de 30 s après 20 appuis")
	var before: float = g.coins
	g.settle(t + 40.0)
	check(near(g.coins - before, inc * (40.0 + 30.0)), "rush : ×2 seulement pendant ses 30 s")
	t += 40.0
	# Achat d'une pièce (les achats récoltent d'abord, à l'heure du jeu).
	g.fake_time = t
	g.coins = 1000.0
	var uid: int = g.selected
	check(g.buy_part(uid, 0, 1) and g.get_car(uid)["levels"][0] == 1, "achat d'un niveau")
	check(near(g.coins, 1000.0 - Economy.part_cost(0, 0), 1e-6), "le niveau est payé")
	check(not g.buy_part(uid, 5, 1), "pièce verrouillée à l'étape Box")
	g.coins = 0.0
	check(not g.buy_part(uid, 0, 1), "pas d'achat sans argent")
	# Places : les voitures en trop vont en réserve.
	for m in ["peujo280", "gulf8", "yariz"]:
		g.add_car(m)
	check(g.parked.size() == 3 and g.cars.size() == 4, "3 places : la 4e voiture est en réserve")
	g.coins = g.slot_price()
	check(g.buy_slot() and g.parked.size() == 4, "nouvelle place : la voiture de réserve s'y gare")
	# Spot : gain et voiture ajoutée.
	g.coins = 0.0
	var info: Dictionary = g.spot("gulf_gti", t)
	check(info["is_new"] and near(info["gain"], Economy.spot_gain(1, g.base_income() / 1.0) , 0.2) and g.owns_model("gulf_gti"), "spot : voiture et gain")
	check(not g.spot("gulf_gti", t)["is_new"], "deuxième spot du même modèle : pas nouveau")
	g.rng.seed = 7
	var models := {}
	for i in 200:
		models[g.roll_spot_model()] = true
	check(models.size() > 10, "le tirage varie les modèles")
	# Sauvegarde, puis retour après 3 h : 2 h à 100 %, 1 h à 50 %.
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var inc2: float = g.base_income()
	var coins_before: float = g.coins
	var h: Node = load("res://scripts/game/game_state.gd").new()
	h.no_save = true
	check(h.from_dict(d, t + 3.0 * 3600.0) > 0.0, "sauvegarde relue")
	check(near(h.coins - coins_before, inc2 * (7200.0 + 0.5 * 3600.0), 1e-6), "absence de 3 h payée selon le hors ligne")
	check(not h.offline.is_empty(), "fenêtre « pendant ton absence »")
	check(h.cars.size() == g.cars.size() and h.parked == g.parked and h.slots == g.slots, "voitures et places relues")
	g.free()
	h.free()
