## Zentraler Spielzustand: getragene Katzen, Katzen zu Hause, Muenzen, Upgrades.
##
## Autoload -- ueberall als `GameState` erreichbar.
extends Node

signal coins_changed(amount: int)
signal carried_changed(carried: int, capacity: int)
signal home_cats_changed()
signal cat_rescued(cat: CatData)
signal cat_adopted(cat: CatData, reward: int)
signal upgrade_purchased(upgrade_id: String, level: int)

## Muenzen pro vermittelter Katze.
const ADOPTION_REWARD := 25

## Grundkapazitaet, bevor Upgrades greifen.
const BASE_CARRY_CAPACITY := 2

## Abbau pro Sekunde bei Upgrade-Stufe 0.
const DECAY_HUNGER := 0.30
const DECAY_THIRST := 0.40
const DECAY_CLEANLINESS := 0.15

## Zusatzschaden auf die Gesundheit, wenn Hunger oder Durst bei 0 stehen.
const HEALTH_DECAY_WHEN_STARVING := 0.5

## Definition aller Upgrades. `costs` enthaelt den Preis je Stufe.
const UPGRADES := {
	"carry_capacity": {
		"name": "Tragekorb",
		"description": "Du kannst eine Katze mehr gleichzeitig tragen.",
		"costs": [50, 120, 260],
	},
	"treats": {
		"name": "Leckerlis",
		"description": "Katzen fassen schneller Vertrauen und sind weniger scheu.",
		"costs": [40, 100, 220],
	},
	"comfort": {
		"name": "Komfort",
		"description": "Beduerfnisse sinken zu Hause langsamer.",
		"costs": [60, 140, 300],
	},
	"vet": {
		"name": "Tierarzt",
		"description": "Katzen genesen schneller und werden frueher vermittelt.",
		"costs": [70, 160, 340],
	},
}

var coins: int = 0
var rescued_total: int = 0
var adopted_total: int = 0

## Katzen, die der Spieler gerade traegt.
var carried_cats: Array[CatData] = []

## Katzen, die zu Hause im Koerbchen liegen und gepflegt werden.
var home_cats: Array[CatData] = []

## Upgrade-Id -> gekaufte Stufe (0 = nicht gekauft).
var upgrade_levels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func _process(delta: float) -> void:
	_tick_needs(delta)


## Setzt alles auf den Anfangszustand zurueck (neues Spiel).
func reset() -> void:
	coins = 0
	rescued_total = 0
	adopted_total = 0
	carried_cats.clear()
	home_cats.clear()
	upgrade_levels.clear()
	for key: String in UPGRADES:
		upgrade_levels[key] = 0
	coins_changed.emit(coins)
	home_cats_changed.emit()
	carried_changed.emit(0, carry_capacity())


# --- Tragen -----------------------------------------------------------------

func carry_capacity() -> int:
	return BASE_CARRY_CAPACITY + upgrade_level("carry_capacity")


func can_carry_more() -> bool:
	return carried_cats.size() < carry_capacity()


## Nimmt eine Katze auf. Gibt false zurueck, wenn die Arme schon voll sind.
func pick_up_cat(cat: CatData) -> bool:
	if not can_carry_more():
		return false
	cat.state = CatData.State.CARRIED
	carried_cats.append(cat)
	rescued_total += 1
	cat_rescued.emit(cat)
	carried_changed.emit(carried_cats.size(), carry_capacity())
	return true


## Legt alle getragenen Katzen zu Hause ab.
func deliver_carried_cats() -> int:
	var delivered := carried_cats.size()
	for cat in carried_cats:
		cat.state = CatData.State.AT_HOME
		home_cats.append(cat)
	carried_cats.clear()
	if delivered > 0:
		home_cats_changed.emit()
	carried_changed.emit(0, carry_capacity())
	return delivered


## Eine getragene Katze entwischt (z.B. nach einem Schreck).
func lose_carried_cat() -> CatData:
	if carried_cats.is_empty():
		return null
	var cat: CatData = carried_cats.pop_back()
	cat.state = CatData.State.WILD
	rescued_total = maxi(rescued_total - 1, 0)
	carried_changed.emit(carried_cats.size(), carry_capacity())
	return cat


# --- Beduerfnisse -----------------------------------------------------------

## Multiplikator fuer den Beduerfnis-Abbau -- jede Komfort-Stufe bremst um 15 %.
func decay_multiplier() -> float:
	return pow(0.85, float(upgrade_level("comfort")))


## Multiplikator fuer die Genesungsdauer -- jede Tierarzt-Stufe spart 20 %.
func recovery_multiplier() -> float:
	return pow(0.8, float(upgrade_level("vet")))


func recovery_rate() -> float:
	return 1.0 / maxf(recovery_multiplier(), 0.01)


## Verbleibende Echtzeit, solange alle Beduerfnisse erfuellt bleiben.
func recovery_seconds_remaining(cat: CatData) -> float:
	return maxf(CatData.RECOVERY_SECONDS - cat.recovery_timer, 0.0) / recovery_rate()


## Scheu-Multiplikator -- jede Leckerli-Stufe macht Katzen 20 % zutraulicher.
func shyness_multiplier() -> float:
	return pow(0.8, float(upgrade_level("treats")))


func _tick_needs(delta: float) -> void:
	if home_cats.is_empty():
		return

	var decay := decay_multiplier() * delta
	var recovery_speed := recovery_rate()
	var adopted: Array[CatData] = []

	for cat in home_cats:
		cat.hunger = maxf(cat.hunger - DECAY_HUNGER * decay, 0.0)
		cat.thirst = maxf(cat.thirst - DECAY_THIRST * decay, 0.0)
		cat.cleanliness = maxf(cat.cleanliness - DECAY_CLEANLINESS * decay, 0.0)

		# Die Gesundheit faellt nur, wenn die Katze wirklich vernachlaessigt wird.
		if is_zero_approx(cat.hunger) or is_zero_approx(cat.thirst):
			cat.health = maxf(cat.health - HEALTH_DECAY_WHEN_STARVING * decay, 0.0)

		if cat.all_needs_met():
			cat.recovery_timer += delta * recovery_speed
			if cat.recovery_timer >= CatData.RECOVERY_SECONDS:
				adopted.append(cat)
		else:
			# Rueckschlag, aber nicht komplett bei null anfangen.
			cat.recovery_timer = maxf(cat.recovery_timer - delta * 2.0, 0.0)

	for cat in adopted:
		_adopt(cat)


func _adopt(cat: CatData) -> void:
	home_cats.erase(cat)
	cat.state = CatData.State.ADOPTED
	adopted_total += 1
	add_coins(ADOPTION_REWARD)
	cat_adopted.emit(cat, ADOPTION_REWARD)
	home_cats_changed.emit()


# --- Muenzen und Upgrades ---------------------------------------------------

func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


func upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func upgrade_max_level(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return 0
	return (UPGRADES[upgrade_id]["costs"] as Array).size()


## Preis der naechsten Stufe, oder -1 wenn bereits voll ausgebaut.
func upgrade_cost(upgrade_id: String) -> int:
	var level := upgrade_level(upgrade_id)
	if level >= upgrade_max_level(upgrade_id):
		return -1
	return int((UPGRADES[upgrade_id]["costs"] as Array)[level])


func can_afford_upgrade(upgrade_id: String) -> bool:
	var cost := upgrade_cost(upgrade_id)
	return cost >= 0 and coins >= cost


func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_afford_upgrade(upgrade_id):
		return false
	add_coins(-upgrade_cost(upgrade_id))
	var level := upgrade_level(upgrade_id) + 1
	upgrade_levels[upgrade_id] = level
	upgrade_purchased.emit(upgrade_id, level)
	if upgrade_id == "carry_capacity":
		carried_changed.emit(carried_cats.size(), carry_capacity())
	return true


# --- Speichern --------------------------------------------------------------

func to_dict() -> Dictionary:
	var carried: Array = []
	for cat in carried_cats:
		carried.append(cat.to_dict())
	var at_home: Array = []
	for cat in home_cats:
		at_home.append(cat.to_dict())
	return {
		"coins": coins,
		"rescued_total": rescued_total,
		"adopted_total": adopted_total,
		"carried_cats": carried,
		"home_cats": at_home,
		"upgrade_levels": upgrade_levels.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	coins = maxi(int(data.get("coins", 0)), 0)
	rescued_total = maxi(int(data.get("rescued_total", 0)), 0)
	adopted_total = maxi(int(data.get("adopted_total", 0)), 0)

	carried_cats.clear()
	var carried_raw: Array = data.get("carried_cats", [])
	for entry: Variant in carried_raw:
		if entry is Dictionary:
			carried_cats.append(CatData.from_dict(entry))

	home_cats.clear()
	var home_raw: Array = data.get("home_cats", [])
	for entry: Variant in home_raw:
		if entry is Dictionary:
			home_cats.append(CatData.from_dict(entry))

	# Unbekannte Upgrade-Ids aus alten Staenden werden verworfen.
	var stored: Dictionary = data.get("upgrade_levels", {})
	upgrade_levels.clear()
	for key: String in UPGRADES:
		upgrade_levels[key] = clampi(int(stored.get(key, 0)), 0, upgrade_max_level(key))

	coins_changed.emit(coins)
	home_cats_changed.emit()
	carried_changed.emit(carried_cats.size(), carry_capacity())
