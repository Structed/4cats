## Zentraler Spielzustand: getragene Katzen, Katzen zu Hause, Muenzen, Upgrades.
##
## Autoload -- ueberall als `GameState` erreichbar.
extends Node

signal coins_changed(amount: int)
signal carried_changed(carried: int, capacity: int)
signal home_cats_changed()
signal cat_rescued(cat: CatData)
signal cat_picked_up(cat: CatData, location: String)
signal cat_adopted(cat: CatData, reward: int)
signal upgrade_purchased(upgrade_id: String, level: int)
signal home_layout_changed()
signal supplies_changed()
signal cat_died(cat: CatData)
signal home_item_purchased(kind: String, price: int)

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
		"description": "Bedürfnisse sinken zu Hause langsamer.",
		"costs": [60, 140, 300],
	},
	"vet": {
		"name": "Tierarzt",
		"description": "Katzen genesen schneller und werden früher vermittelt.",
		"costs": [70, 160, 340],
	},
}

var coins: int = 0
var rescued_total: int = 0
var adopted_total: int = 0
var deceased_total: int = 0
var last_loss_name: String = ""
var difficulty_id: String = DifficultyRules.DEFAULT
var supplies: SupplyState
var supply_actions: SupplyActions
var analytics: GameplayStats
var _critical_cats: Dictionary = {}

## Katzen, die der Spieler gerade traegt.
var carried_cats: Array[CatData] = []

## Katzen, die zu Hause leben.
var home_cats: Array[CatData] = []
var home: HomeData
var home_simulation: HomeSimulation
var simulation_active: bool = false

## Upgrade-Id -> gekaufte Stufe (0 = nicht gekauft).
var upgrade_levels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func _process(delta: float) -> void:
	if simulation_active and not get_tree().paused:
		analytics.tick(delta, home_cats)
		if _tick_needs(delta):
			SaveManager.save_game()


## Setzt alles auf den Anfangszustand zurueck (neues Spiel).
func reset(mode: String = DifficultyRules.DEFAULT) -> void:
	if not DifficultyRules.IDS.has(mode):
		push_error("Unbekannter Schwierigkeitsgrad: %s" % mode)
		return
	coins = 0
	rescued_total = 0
	adopted_total = 0
	deceased_total = 0
	last_loss_name = ""
	difficulty_id = mode
	analytics = GameplayStats.new()
	_critical_cats.clear()
	carried_cats.clear()
	home_cats.clear()
	home = HomeData.starter()
	supplies = SupplyState.new()
	_bind_home()
	simulation_active = false
	upgrade_levels.clear()
	for key: String in UPGRADES:
		upgrade_levels[key] = 0
	coins_changed.emit(coins)
	home_cats_changed.emit()
	home_layout_changed.emit()
	carried_changed.emit(0, carry_capacity())
	supplies_changed.emit()


func _bind_home() -> void:
	if home_simulation != null:
		if home_simulation.cat_picked_up.is_connected(_on_home_cat_picked_up):
			home_simulation.cat_picked_up.disconnect(_on_home_cat_picked_up)
		if home_simulation.supply_consumed.is_connected(_on_supply_consumed):
			home_simulation.supply_consumed.disconnect(_on_supply_consumed)
	home_simulation = HomeSimulation.new(home, home_cats, supplies)
	home_simulation.cat_picked_up.connect(_on_home_cat_picked_up)
	home_simulation.supply_consumed.connect(_on_supply_consumed)
	supply_actions = SupplyActions.new(supplies, home, home_simulation)
	_critical_cats.clear()
	if DifficultyRules.allows_death(difficulty_id):
		for cat in home_cats:
			if cat.is_starving() and is_zero_approx(cat.health):
				_critical_cats[cat.id] = true


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
	cat_picked_up.emit(cat, "outdoor")
	carried_changed.emit(carried_cats.size(), carry_capacity())
	return true


## Legt alle getragenen Katzen zu Hause ab.
func deliver_carried_cats() -> int:
	var delivered := carried_cats.size()
	var rescued := carried_cats.duplicate()
	for cat in carried_cats:
		cat.state = CatData.State.AT_HOME
		home_cats.append(cat)
	carried_cats.clear()
	home_simulation.sync_cats()
	if delivered > 0:
		analytics.record("cat_delivered", delivered)
		home_cats_changed.emit()
		for cat: CatData in rescued:
			cat_rescued.emit(cat)
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
	return pow(0.85, float(upgrade_level("comfort"))) * DifficultyRules.value(difficulty_id, "decay")


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


func _tick_needs(delta: float) -> bool:
	var ready_before := supplies.ready_count()
	var arrived := supplies.step(delta)
	if arrived:
		var count := supplies.ready_count() - ready_before
		analytics.record("food_arrived", count)
		analytics.add_amount("food_arrived_units", count * SupplyCatalog.PACKAGE_UNITS)
		supplies_changed.emit()
	if home_cats.is_empty():
		return arrived

	var decay := decay_multiplier() * delta
	var already_critical := {}
	for cat in home_cats:
		already_critical[cat.id] = cat.is_starving() and is_zero_approx(cat.health)
		cat.hunger = maxf(cat.hunger - DECAY_HUNGER * decay, 0.0)
		cat.thirst = maxf(cat.thirst - DECAY_THIRST * decay, 0.0)
		cat.cleanliness = maxf(cat.cleanliness - DECAY_CLEANLINESS * decay, 0.0)
		cat.enrichment = maxf(cat.enrichment - HomeSimulation.DECAY_ENRICHMENT * decay, 0.0)

		# Die Gesundheit faellt nur, wenn die Katze wirklich vernachlaessigt wird.
		if cat.is_starving():
			var damage := DifficultyRules.value(difficulty_id, "damage")
			if cat.age_group == CatData.Age.SENIOR:
				damage *= DifficultyRules.value(difficulty_id, "senior")
			cat.health = maxf(cat.health - HEALTH_DECAY_WHEN_STARVING * decay * damage, 0.0)

	home_simulation.step(delta)
	var recovery_speed := recovery_rate()
	var adopted: Array[CatData] = []
	var deceased: Array[CatData] = []
	var care_event := false
	for cat in home_cats:
		if DifficultyRules.allows_death(difficulty_id) and cat.is_starving() \
				and is_zero_approx(cat.health):
			if not _critical_cats.has(cat.id):
				_critical_cats[cat.id] = true
				analytics.record("cat_became_critical")
				care_event = true
			# Der Schritt, der Gesundheit auf null senkt, verbraucht keine Schonfrist.
			if bool(already_critical[cat.id]):
				cat.critical_elapsed += delta
			if cat.critical_elapsed >= DifficultyRules.value(difficulty_id, "grace"):
				deceased.append(cat)
				continue
		else:
			if _critical_cats.erase(cat.id):
				analytics.record("cat_recovered_from_critical")
				care_event = true
			cat.critical_elapsed = 0.0
		if cat.all_needs_met():
			cat.recovery_timer += delta * recovery_speed
			if cat.recovery_timer >= CatData.RECOVERY_SECONDS \
					and home_simulation.held_cat_id != cat.id:
				adopted.append(cat)
		else:
			# Rueckschlag, aber nicht komplett bei null anfangen.
			cat.recovery_timer = maxf(cat.recovery_timer - delta * 2.0, 0.0)

	for cat in adopted:
		_adopt(cat)
	for cat in deceased:
		_die(cat)
	return arrived or care_event or not adopted.is_empty() or not deceased.is_empty()


func _adopt(cat: CatData) -> void:
	if not _remove_home_cat(cat, CatData.State.ADOPTED):
		return
	adopted_total += 1
	analytics.record("cat_adopted")
	analytics.adopted_by_age[cat.age_group] += 1
	add_coins(ADOPTION_REWARD)
	cat_adopted.emit(cat, ADOPTION_REWARD)
	home_cats_changed.emit()


func _remove_home_cat(cat: CatData, outcome: CatData.State) -> bool:
	if not home_cats.has(cat):
		return false
	home_cats.erase(cat)
	_critical_cats.erase(cat.id)
	home_simulation.sync_cats()
	cat.state = outcome
	return true


func _die(cat: CatData) -> void:
	if not _remove_home_cat(cat, CatData.State.DEAD):
		return
	deceased_total += 1
	analytics.record("cat_died")
	analytics.deceased_by_age[cat.age_group] += 1
	last_loss_name = cat.cat_name
	cat_died.emit(cat)
	home_cats_changed.emit()


func care_warning(cat: CatData) -> String:
	if DifficultyRules.allows_death(difficulty_id) and cat.is_starving() and cat.health <= 0.0:
		var remaining := maxf(0.0, DifficultyRules.value(difficulty_id, "grace") - cat.critical_elapsed)
		return "%s: Lebensgefahr! Futter/Wasser und Behandlung · noch %d s" % [
			cat.cat_name, ceili(remaining)]
	var needs: PackedStringArray = []
	if cat.hunger <= DifficultyRules.WARNING_THRESHOLD:
		needs.append("Futter")
	if cat.thirst <= DifficultyRules.WARNING_THRESHOLD:
		needs.append("Wasser")
	if cat.health <= DifficultyRules.WARNING_THRESHOLD:
		needs.append("Behandlung")
	return "%s braucht dringend %s." % [cat.cat_name, " und ".join(needs)] \
		if not needs.is_empty() else ""


# --- Versorgung ------------------------------------------------------------

func food_price() -> int:
	return int(DifficultyRules.value(difficulty_id, "food_price"))


func delivery_fee() -> int:
	return int(DifficultyRules.value(difficulty_id, "delivery_fee"))


func can_claim_emergency() -> bool:
	return coins < food_price() and supply_actions.available_food() == 0


func buy_food_package(emergency: bool = false) -> String:
	var error := supply_actions.free_hands_error()
	if not error.is_empty():
		return error
	if emergency and not can_claim_emergency():
		return "Notfutter gibt es nur ohne Futtervorrat und ohne genug Münzen für ein Paket."
	if not emergency and coins < food_price():
		return "Dafür reichen die Münzen nicht."
	supplies.cargo_kind = "package"
	supplies.cargo_amount = SupplyCatalog.EMERGENCY_UNITS if emergency else SupplyCatalog.PACKAGE_UNITS
	if emergency:
		analytics.record("emergency_claimed")
		analytics.add_amount("emergency_food_units", supplies.cargo_amount)
	else:
		analytics.record("food_package_bought")
		analytics.add_amount("food_purchased_units", supplies.cargo_amount)
		analytics.add_amount("coins_spent_food", food_price())
		add_coins(-food_price())
	supplies_changed.emit()
	return ""


func order_food() -> String:
	var price := food_price() + delivery_fee()
	if coins < price:
		return "Für Futter und Lieferung reichen die Münzen nicht."
	var order := SupplyOrder.new()
	order.id = supplies.next_order
	supplies.next_order += 1
	order.remaining = DifficultyRules.value(difficulty_id, "delivery_seconds")
	supplies.orders.append(order)
	analytics.record("food_ordered")
	analytics.add_amount("food_purchased_units", order.units)
	analytics.add_amount("coins_spent_food", food_price())
	analytics.add_amount("coins_spent_delivery", delivery_fee())
	add_coins(-price)
	supplies_changed.emit()
	return ""


func use_supply_station(id: String) -> String:
	var item := home.item_by_id(id)
	var before_kind := supplies.cargo_kind
	var before_amount := supplies.cargo_amount
	var error := supply_actions.use_station(id)
	if not error.is_empty():
		return error
	var event: String
	var amount: int
	if item.kind == "pantry":
		if before_kind in ["food", "package"]:
			event = "food_unpacked" if before_kind == "package" else "food_returned"
			amount = before_amount
		else:
			event = "food_taken"
			amount = supplies.cargo_amount
	else:
		event = "water_returned" if before_kind == "water" else "water_drawn"
		amount = before_amount if before_kind == "water" else supplies.cargo_amount
	analytics.record(event)
	analytics.add_amount(event + "_units", amount)
	return _supply_result("")


func refill_bowl(id: String) -> String:
	var before_amount := supplies.cargo_amount
	var error := supply_actions.refill_bowl(id)
	if not error.is_empty():
		return error
	var item := home.item_by_id(id)
	var event := item.kind + "_refilled"
	analytics.record(event)
	analytics.add_amount(event + "_units", before_amount - supplies.cargo_amount)
	return _supply_result("")


func collect_delivery(order_id: int = 0) -> String:
	var error := supply_actions.collect_delivery(order_id)
	if not error.is_empty():
		return error
	analytics.record("parcel_collected")
	return _supply_result("")


func _on_supply_consumed(kind: String, amount: int) -> void:
	analytics.add_amount(kind + "_consumed_units", amount)


func _supply_result(error: String) -> String:
	if error.is_empty():
		supplies_changed.emit()
	return error


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

func buy_home_item(kind: String) -> HomeItemData:
	if not HomeCatalog.KINDS.has(kind) or coins < HomeCatalog.price(kind):
		return null
	var item := HomeItemData.new()
	while home.item_by_id("item_%d" % home.next_item) != null:
		home.next_item += 1
	item.id = "item_%d" % home.next_item
	home.next_item += 1
	item.kind = kind
	item.placed = false
	home.items.append(item)
	var price := HomeCatalog.price(kind)
	add_coins(-price)
	home_layout_changed.emit()
	home_item_purchased.emit(kind, price)
	return item


func place_home_item(id: String, cell: Vector2i, turns: int,
		occupants: Array[Vector2]) -> String:
	if home_simulation.item_in_use(id):
		return "Dieser Gegenstand wird gerade benutzt."
	var error := home_simulation.layout.placement_error(id, cell, turns, occupants)
	if not error.is_empty():
		return error
	var item := home.item_by_id(id)
	item.cell = cell
	item.turns = posmod(turns, 4)
	item.placed = true
	home_simulation.rebuild_layout()
	home_layout_changed.emit()
	return ""


func store_home_item(id: String) -> String:
	var item := home.item_by_id(id)
	if item == null or not item.placed:
		return "Dieser Gegenstand steht nicht im Haus."
	if home_simulation.item_in_use(id):
		return "Dieser Gegenstand wird gerade benutzt."
	item.placed = false
	home_simulation.rebuild_layout()
	home_layout_changed.emit()
	return ""

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
		"deceased_total": deceased_total,
		"last_loss_name": last_loss_name,
		"difficulty_id": difficulty_id,
		"supplies": supplies.to_dict(),
		"analytics": analytics.to_dict(),
		"carried_cats": carried,
		"home_cats": at_home,
		"upgrade_levels": upgrade_levels.duplicate(),
		"home": home.to_dict(),
	}


func from_dict(data: Dictionary) -> bool:
	var raw_analytics: Variant = data.get("analytics")
	if raw_analytics is not Dictionary:
		push_warning("Im Spielstand fehlt die lokale Statistik.")
		return false
	var loaded_analytics := GameplayStats.from_dict(raw_analytics)
	if loaded_analytics == null:
		push_warning("Die lokale Spielstatistik ist beschädigt.")
		return false
	var mode: Variant = data.get("difficulty_id")
	var raw_supplies: Variant = data.get("supplies")
	if mode is not String or not DifficultyRules.IDS.has(mode) or raw_supplies is not Dictionary:
		push_warning("Im Spielstand fehlen gültige Versorgungsregeln.")
		return false
	var loaded_supplies := SupplyState.from_dict(raw_supplies)
	if loaded_supplies == null or not SupplyCatalog.is_count(data.get("deceased_total")) \
			or data.get("last_loss_name") is not String:
		push_warning("Die gespeicherten Vorräte oder Verlustdaten sind beschädigt.")
		return false
	for order in loaded_supplies.orders:
		if order.remaining > DifficultyRules.value(mode, "delivery_seconds"):
			push_warning("Die gespeicherte Lieferzeit ist ungültig.")
			return false
	var raw_home: Variant = data.get("home")
	if raw_home is not Dictionary:
		push_warning("Im Spielstand fehlen die Hausdaten.")
		return false
	var loaded_home := HomeData.from_dict(raw_home)
	if loaded_home == null:
		push_warning("Die gespeicherten Hausdaten sind beschaedigt.")
		return false
	var loaded_layout := HomeLayout.new(loaded_home)
	var layout_error := loaded_layout.save_error()
	if not layout_error.is_empty():
		push_warning("Hausspielstand: %s" % layout_error)
		return false
	var loaded_carried: Array[CatData] = []
	var loaded_cats: Array[CatData] = []
	var cat_ids := {}
	for key in ["carried_cats", "home_cats"]:
		var entries: Variant = data.get(key, [])
		if entries is not Array:
			push_warning("Die gespeicherte Katzenliste ist beschädigt.")
			return false
		for entry: Variant in entries:
			if entry is not Dictionary:
				push_warning("Die gespeicherten Katzendaten sind beschädigt.")
				return false
			var cat := CatData.from_dict(entry)
			var expected := CatData.State.CARRIED if key == "carried_cats" else CatData.State.AT_HOME
			if cat == null or cat.id.is_empty() or cat_ids.has(cat.id) or cat.state != expected:
				push_warning("Ungültige oder doppelte Katze im Spielstand.")
				return false
			cat_ids[cat.id] = true
			if key == "carried_cats":
				loaded_carried.append(cat)
			else:
				loaded_cats.append(cat)
	var stored: Variant = data.get("upgrade_levels", {})
	if stored is not Dictionary:
		push_warning("Die gespeicherten Ausbauten sind beschädigt.")
		return false
	for key in ["coins", "rescued_total", "adopted_total"]:
		if not SupplyCatalog.is_count(data.get(key, 0)):
			push_warning("Die gespeicherten Zähler sind beschädigt.")
			return false
	for key: String in UPGRADES:
		if not SupplyCatalog.is_count(stored.get(key, 0)):
			push_warning("Die gespeicherten Ausbaustufen sind beschädigt.")
			return false
	coins = int(data.get("coins", 0))
	rescued_total = int(data.get("rescued_total", 0))
	adopted_total = int(data.get("adopted_total", 0))
	deceased_total = int(data["deceased_total"])
	last_loss_name = data["last_loss_name"]
	difficulty_id = mode
	supplies = loaded_supplies
	analytics = loaded_analytics
	carried_cats.assign(loaded_carried)
	home_cats.assign(loaded_cats)
	home = loaded_home
	_bind_home()

	# Unbekannte Upgrade-Ids aus alten Staenden werden verworfen.
	upgrade_levels.clear()
	for key: String in UPGRADES:
		upgrade_levels[key] = clampi(int(stored.get(key, 0)), 0, upgrade_max_level(key))

	coins_changed.emit(coins)
	home_cats_changed.emit()
	home_layout_changed.emit()
	carried_changed.emit(carried_cats.size(), carry_capacity())
	supplies_changed.emit()
	return true


func _on_home_cat_picked_up(cat_id: String) -> void:
	var cat := home_simulation.cat_by_id(cat_id)
	if cat == null:
		push_error("Aufgehobene Hauskatze fehlt in der Simulation.")
		return
	cat_picked_up.emit(cat, "indoor")
