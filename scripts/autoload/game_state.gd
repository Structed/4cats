## Zentraler Spielzustand: getragene Katzen, Katzen zu Hause, Muenzen, Upgrades.
##
## Autoload -- ueberall als `GameState` erreichbar.
##
## Die Daten liegen in Abschnitten unter scripts/state/, die Pflegeregeln in
## NeedsSimulation. Diese Datei haelt sie zusammen und meldet Aenderungen ueber
## Signale weiter.
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

## Definition aller Upgrades. Gepflegt wird sie im UpgradeCatalog.
const UPGRADES := UpgradeCatalog.ENTRIES

# --- Abschnitte des Spielstands ---------------------------------------------
# Jeder Abschnitt haelt seine eigenen Felder und kennt sein eigenes Format.
# Dauerhafte Daten fuer ein neues Feature sind deshalb eine neue Datei unter
# scripts/state/ und ein Eintrag in _sections -- nicht vier neue Zeilen quer
# durch reset(), to_dict() und from_dict().

var _progress := ProgressSection.new()
var _upgrades := UpgradeSection.new()
var _roster := RosterSection.new()
var _supply := SupplySection.new()
var _house := HomeSection.new()
var _stats := StatsSection.new()
var _sections: Array[SaveSection] = []

## Beduerfnisse, Lebensgefahr und Genesung der Hauskatzen.
var _needs := NeedsSimulation.new()

var supply_actions: SupplyActions
var home_simulation: HomeSimulation
var simulation_active: bool = false

# --- Felder der Abschnitte --------------------------------------------------
# Weitergereicht, damit Aufrufstellen weiter `GameState.coins` lesen und
# schreiben koennen, ohne den Aufbau der Abschnitte zu kennen.

var coins: int:
	get: return _progress.coins
	set(value): _progress.coins = value

var rescued_total: int:
	get: return _progress.rescued_total
	set(value): _progress.rescued_total = value

var adopted_total: int:
	get: return _progress.adopted_total
	set(value): _progress.adopted_total = value

var deceased_total: int:
	get: return _progress.deceased_total
	set(value): _progress.deceased_total = value

var last_loss_name: String:
	get: return _progress.last_loss_name
	set(value): _progress.last_loss_name = value

var difficulty_id: String:
	get: return _progress.difficulty_id
	set(value): _progress.difficulty_id = value

## Upgrade-Id -> gekaufte Stufe (0 = nicht gekauft).
var upgrade_levels: Dictionary:
	get: return _upgrades.levels

## Katzen, die der Spieler gerade traegt.
var carried_cats: Array[CatData]:
	get: return _roster.carried

## Katzen, die zu Hause leben.
var home_cats: Array[CatData]:
	get: return _roster.at_home

var supplies: SupplyState:
	get: return _supply.state

var home: HomeData:
	get: return _house.house

var analytics: GameplayStats:
	get: return _stats.stats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sections = [_progress, _upgrades, _roster, _supply, _house, _stats]
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
	for section in _sections:
		section.reset(mode)
	_bind_home()
	simulation_active = false
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
	_needs.rebuild(home_cats, difficulty_id)


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
	return _upgrades.effect("comfort", 0.85) * DifficultyRules.value(difficulty_id, "decay")


## Multiplikator fuer die Genesungsdauer -- jede Tierarzt-Stufe spart 20 %.
func recovery_multiplier() -> float:
	return _upgrades.effect("vet", 0.8)


func recovery_rate() -> float:
	return 1.0 / maxf(recovery_multiplier(), 0.01)


## Verbleibende Echtzeit, solange alle Beduerfnisse erfuellt bleiben.
func recovery_seconds_remaining(cat: CatData) -> float:
	return maxf(CatData.RECOVERY_SECONDS - cat.recovery_timer, 0.0) / recovery_rate()


## Scheu-Multiplikator -- jede Leckerli-Stufe macht Katzen 20 % zutraulicher.
func shyness_multiplier() -> float:
	return _upgrades.effect("treats", 0.8)


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

	_needs.step(delta, home_cats, home_simulation, difficulty_id,
		decay_multiplier() * delta, recovery_rate(), analytics)
	for cat in _needs.adopted:
		_adopt(cat)
	for cat in _needs.deceased:
		_die(cat)
	return arrived or _needs.care_event or not _needs.adopted.is_empty() \
		or not _needs.deceased.is_empty()


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
	_needs.forget(cat.id)
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
	return _upgrades.level(upgrade_id)


func upgrade_max_level(upgrade_id: String) -> int:
	return UpgradeCatalog.max_level(upgrade_id)


## Preis der naechsten Stufe, oder -1 wenn bereits voll ausgebaut.
func upgrade_cost(upgrade_id: String) -> int:
	return _upgrades.cost(upgrade_id)


func can_afford_upgrade(upgrade_id: String) -> bool:
	return _upgrades.can_afford(upgrade_id, coins)


func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_afford_upgrade(upgrade_id):
		return false
	add_coins(-upgrade_cost(upgrade_id))
	var level := _upgrades.purchase(upgrade_id)
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
	var data := {}
	for section in _sections:
		section.write(data)
	return data


func from_dict(data: Dictionary) -> bool:
	# Erst pruefen alle Abschnitte, danach uebernehmen sie. Ein beschaedigter
	# Spielstand laesst den laufenden Zustand damit unveraendert.
	for section in _sections:
		if not section.read(data):
			return false
	for section in _sections:
		section.commit()
	_bind_home()
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
