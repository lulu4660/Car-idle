## État de la partie idle : argent, voitures, pièces, places, étapes du garage, SERVIR,
## gains hors ligne, voitures spottées en balade ; sauvegarde dans user://save.json.
## Chargé une fois pour tout le jeu (autoload « Game ») : le garage et la balade le
## partagent.
## Les règles (prix, revenus, paliers) sont dans scripts/core/economy.gd ; ici, seulement
## l'état et les actions du joueur. Le serveur fera foi plus tard (étape 7).
## Revenus : jamais additionnés en continu. On garde l'heure de la dernière récolte, et le
## gain est le revenu × le temps écoulé depuis (`settle`) : appelé à chaque image tant que
## le jeu est ouvert, et avant tout achat ; au retour, l'absence est payée selon les règles
## du hors ligne (100 % pendant 2 h, puis 50 % jusqu'à 8 h).
extends Node

const Economy = preload("res://scripts/core/economy.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
## Voiture offerte au départ.
const STARTER := "clia5"
## Absence plus courte : pas de fenêtre « pendant ton absence » (déjà payée en direct).
const OFFLINE_POPUP_MIN := 60.0

signal changed
## Une voiture vient d'être spottée en balade : {uid, model, rarity, gain, is_new, parked}.
signal spotted(info: Dictionary)

var coins := 0.0
var lifetime := 0.0
## Voitures possédées : {uid, model, color, levels (10 niveaux)}.
var cars: Array[Dictionary] = []
## Voitures garées dans les places (elles seules rapportent) ; les autres sont en réserve.
var parked: Array[int] = []
var slots := Economy.START_SLOTS
var stage := 0
var next_uid := 1
## Voiture choisie (affichée sur le plateau, conduite en balade).
var selected := -1
## Heure (secondes Unix) de la dernière récolte.
var last_collect := 0.0
## SERVIR : la jauge se remplit à chaque appui ; pleine, revenus ×2 pendant 30 s.
var rush_charge := 0.0
## Fin du rush (heure Unix ; 0 = pas de rush).
var rush_until := 0.0
var spots := 0
## Gain du hors ligne en attente d'être affiché (fenêtre au retour dans le garage).
var offline := {}
var rng := RandomNumberGenerator.new()
## Pas de sauvegarde sur disque (tests).
var no_save := false
var _save_timer := 0.0


func _ready() -> void:
	rng.randomize()
	if not no_save and load_game(now()) < 0.0:
		new_game(now())


## Heure Unix ; les tests la fixent (`fake_time`).
var fake_time := -1.0


func now() -> float:
	return fake_time if fake_time >= 0.0 else Time.get_unix_time_from_system()


func new_game(t: float) -> void:
	coins = 0.0
	lifetime = 0.0
	cars.clear()
	parked.clear()
	slots = Economy.START_SLOTS
	stage = 0
	next_uid = 1
	rush_charge = 0.0
	rush_until = 0.0
	spots = 0
	offline = {}
	last_collect = t
	selected = add_car(STARTER)
	changed.emit()


# --- Voitures -----------------------------------------------------------

func add_car(model_id: String, color := "") -> int:
	var model := Catalog.get_car(model_id)
	if model.is_empty():
		return -1
	var levels: Array[int] = []
	levels.resize(Economy.PARTS.size())
	levels.fill(0)
	var car := {"uid": next_uid, "model": model_id, "color": color if color != "" else String(model["color"]), "levels": levels}
	next_uid += 1
	cars.append(car)
	if parked.size() < slots:
		parked.append(int(car["uid"]))
	return int(car["uid"])


func get_car(uid: int) -> Dictionary:
	for c in cars:
		if int(c["uid"]) == uid:
			return c
	return {}


func model_of(uid: int) -> Dictionary:
	var c := get_car(uid)
	return {} if c.is_empty() else Catalog.get_car(String(c["model"]))


func rarity_of(car: Dictionary) -> int:
	return int(Catalog.get_car(String(car["model"]))["rarity"])


func owns_model(model_id: String) -> bool:
	for c in cars:
		if c["model"] == model_id:
			return true
	return false


func unique_models() -> int:
	var seen := {}
	for c in cars:
		seen[c["model"]] = true
	return seen.size()


func is_parked(uid: int) -> bool:
	return parked.has(uid)


func unlocked_parts() -> int:
	return int(Economy.STAGES[stage]["parts"])


## Gare une voiture de la réserve ; si les places sont pleines, elle prend la place de
## `replace` (qui part en réserve).
func park(uid: int, replace := -1) -> bool:
	if get_car(uid).is_empty() or parked.has(uid):
		return false
	settle(now())
	if parked.size() >= slots:
		var i := parked.find(replace)
		if i < 0:
			return false
		parked[i] = uid
	else:
		parked.append(uid)
	changed.emit()
	return true


func unpark(uid: int) -> bool:
	if not parked.has(uid):
		return false
	settle(now())
	parked.erase(uid)
	changed.emit()
	return true


func select(uid: int) -> void:
	if not get_car(uid).is_empty() and uid != selected:
		selected = uid
		changed.emit()


# --- Revenus ------------------------------------------------------------

func car_income(car: Dictionary) -> float:
	return Economy.car_income(rarity_of(car), car["levels"]) * income_multiplier()


## Bonus de collection : +1 % par modèle différent possédé (les bonus s'additionnent).
func income_multiplier() -> float:
	return Economy.collection_multiplier(unique_models())


## Revenu par seconde du garage au repos (voitures garées seulement).
func base_income() -> float:
	var total := 0.0
	for uid in parked:
		var car := get_car(uid)
		if not car.is_empty():
			total += Economy.car_income(rarity_of(car), car["levels"])
	return total * income_multiplier()


func rush_active(t: float) -> bool:
	return t < rush_until


func income(t: float) -> float:
	return base_income() * (Economy.RUSH_MULT if rush_active(t) else 1.0)


func _earn(amount: float) -> void:
	coins += amount
	lifetime += amount


## Récolte : revenu × temps écoulé depuis la dernière récolte (le rush ne compte que
## jusqu'à sa fin). À appeler avant tout changement du revenu.
func settle(t: float) -> void:
	var dt := t - last_collect
	if dt <= 0.0:
		last_collect = minf(last_collect, t)
		return
	var base := base_income()
	var boosted := clampf(rush_until - last_collect, 0.0, dt)
	_earn(base * (dt + boosted * (Economy.RUSH_MULT - 1.0)))
	last_collect = t
	if not rush_active(t):
		rush_charge = maxf(0.0, rush_charge - Economy.RUSH_DECAY * dt)


## Appelé à chaque image tant que le jeu tourne (garage ou balade).
func _process(delta: float) -> void:
	if no_save:
		return
	settle(now())
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = 5.0
		save_game(now())


func _notification(what: int) -> void:
	if no_save:
		return
	# Appli mise en arrière-plan ou fermée : on sauvegarde, l'absence sera payée au retour.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		settle(now())
		save_game(now())
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_pay_absence(now())


## SERVIR : un client servi rapporte 5 % du revenu (au moins 1) ; 20 appuis remplissent
## la jauge : revenus ×2 pendant 30 s.
func tap(t: float) -> float:
	settle(t)
	var gain := Economy.tap_gain(income(t))
	_earn(gain)
	if not rush_active(t):
		rush_charge += 1.0 / Economy.RUSH_TAPS
		if rush_charge >= 1.0:
			rush_charge = 0.0
			rush_until = t + Economy.RUSH_DURATION
	changed.emit()
	return gain


# --- Achats -------------------------------------------------------------

## Devis pour `count` niveaux (count = -1 : le maximum payable, au moins 1 pour l'affichage).
func part_quote(uid: int, part: int, count: int) -> Dictionary:
	var car := get_car(uid)
	var rarity := rarity_of(car)
	var level := int(car["levels"][part])
	var n := count
	if count < 0:
		n = maxi(1, Economy.max_affordable(rarity, level, coins))
	n = mini(n, Economy.MAX_LEVEL - level)
	return {"count": n, "cost": Economy.cost_for_levels(rarity, level, n)}


func buy_part(uid: int, part: int, count: int) -> bool:
	var car := get_car(uid)
	if car.is_empty() or part >= unlocked_parts():
		return false
	settle(now())
	var q := part_quote(uid, part, count)
	var n := int(q["count"])
	if n <= 0 or coins < float(q["cost"]):
		return false
	coins -= float(q["cost"])
	car["levels"][part] = int(car["levels"][part]) + n
	changed.emit()
	return true


func slot_price() -> float:
	return Economy.slot_cost(slots + 1)


func can_buy_slot() -> bool:
	return slots < Economy.MAX_SLOTS


func buy_slot() -> bool:
	if not can_buy_slot() or coins < slot_price():
		return false
	settle(now())
	coins -= slot_price()
	slots += 1
	# Une voiture de la réserve prend la nouvelle place.
	for c in cars:
		if parked.size() >= slots:
			break
		if not parked.has(int(c["uid"])):
			parked.append(int(c["uid"]))
	changed.emit()
	return true


func has_next_stage() -> bool:
	return stage + 1 < Economy.STAGES.size()


func stage_price() -> float:
	return float(Economy.STAGES[stage + 1]["cost"]) if has_next_stage() else INF


func buy_stage() -> bool:
	if not has_next_stage() or coins < stage_price():
		return false
	settle(now())
	coins -= stage_price()
	stage += 1
	changed.emit()
	return true


# --- Spot en balade -------------------------------------------------------

## Tire la voiture qu'on trouvera à un endroit de la balade : rareté au hasard, de
## préférence un modèle pas encore possédé.
func roll_spot_model() -> String:
	var rarity := Economy.roll_rarity(rng.randf())
	var pool := Catalog.by_rarity(rarity)
	var fresh: Array[Dictionary] = []
	for m in pool:
		if not owns_model(String(m["id"])):
			fresh.append(m)
	var from: Array[Dictionary] = fresh if not fresh.is_empty() else pool
	return String(from[rng.randi() % from.size()]["id"])


## La voiture `model_id` vient d'être spottée : gain immédiat (20 à 240 min de revenus
## selon la rareté) et la voiture rejoint le garage (garée s'il reste une place, sinon en
## réserve).
func spot(model_id: String, t: float) -> Dictionary:
	var model := Catalog.get_car(model_id)
	if model.is_empty():
		return {}
	settle(t)
	var rarity := int(model["rarity"])
	var is_new := not owns_model(model_id)
	var gain := Economy.spot_gain(rarity, base_income())
	_earn(gain)
	var uid := add_car(model_id)
	spots += 1
	var info := {"uid": uid, "model": model_id, "rarity": rarity, "gain": gain, "is_new": is_new, "parked": parked.has(uid)}
	changed.emit()
	spotted.emit(info)
	return info


# --- Hors ligne et sauvegarde -------------------------------------------

## Absence payée selon les règles du hors ligne (le revenu du garage au repos).
func _pay_absence(t: float) -> void:
	var away := t - last_collect
	if away <= 1.0:
		return
	var gain := Economy.offline_gain(base_income(), away)
	_earn(gain)
	last_collect = t
	rush_until = minf(rush_until, t)
	if away >= OFFLINE_POPUP_MIN and gain > 0.0:
		offline = {"seconds": away, "gain": gain}
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins,
		"lifetime": lifetime,
		"cars": cars,
		"parked": parked,
		"slots": slots,
		"stage": stage,
		"next_uid": next_uid,
		"selected": selected,
		"last_collect": last_collect,
		"rush_charge": rush_charge,
		"rush_until": rush_until,
		"spots": spots,
	}


## Charge une sauvegarde puis paie l'absence ; renvoie l'heure de la dernière récolte, ou
## -1 si la sauvegarde est invalide.
func from_dict(d: Dictionary, t: float) -> float:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return -1.0
	coins = float(d.get("coins", 0.0))
	lifetime = float(d.get("lifetime", 0.0))
	cars.clear()
	for raw in d.get("cars", []):
		if Catalog.get_car(String(raw.get("model", ""))).is_empty():
			continue
		var levels: Array[int] = []
		for l in raw.get("levels", []):
			levels.append(clampi(int(l), 0, Economy.MAX_LEVEL))
		levels.resize(Economy.PARTS.size())
		cars.append({"uid": int(raw["uid"]), "model": String(raw["model"]), "color": String(raw.get("color", "")), "levels": levels})
	slots = clampi(int(d.get("slots", Economy.START_SLOTS)), Economy.START_SLOTS, Economy.MAX_SLOTS)
	parked.clear()
	for u in d.get("parked", []):
		if not get_car(int(u)).is_empty() and parked.size() < slots and not parked.has(int(u)):
			parked.append(int(u))
	stage = clampi(int(d.get("stage", 0)), 0, Economy.STAGES.size() - 1)
	next_uid = maxi(int(d.get("next_uid", 1)), cars.size() + 1)
	selected = int(d.get("selected", -1))
	if get_car(selected).is_empty():
		selected = int(cars[0]["uid"]) if not cars.is_empty() else -1
	last_collect = minf(float(d.get("last_collect", t)), t)
	rush_charge = float(d.get("rush_charge", 0.0))
	rush_until = float(d.get("rush_until", 0.0))
	spots = int(d.get("spots", 0))
	offline = {}
	var saved := last_collect
	_pay_absence(t)
	changed.emit()
	return saved


func save_game(t: float) -> void:
	if no_save:
		return
	settle(t)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game(t: float) -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		return -1.0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return -1.0
	return from_dict(data, t)
