## Lokale Analytics zaehlen nur echte Zustaende und ueberstehen Speichern ohne Wiederholungen.
extends RefCounted

var _failures: PackedStringArray = []

func run(tree: SceneTree) -> PackedStringArray:
	_test_supply_events()
	_test_consumption_and_time(tree)
	_test_care_events()
	_test_persistence()
	GameState.reset()
	return _failures

func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FEHLER", text])
	if not ok:
		_failures.append(text)

func _cat(age: CatData.Age = CatData.Age.ADULT) -> CatData:
	var cat := CatData.new()
	cat.id = "analytics_cat"
	cat.cat_name = "Nicht in Analytics speichern"
	cat.age_group = age
	cat.hunger = 20.0
	cat.thirst = 100.0
	cat.cleanliness = 100.0
	cat.health = 100.0
	cat.enrichment = 100.0
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	return cat

func _test_supply_events() -> void:
	print("--- Lokale Analytics: Versorgung und mehrere Lieferungen ---")
	GameState.reset("challenging")
	GameState.add_coins(100)
	GameState.use_supply_station("starter_pantry")
	GameState.refill_bowl("starter_food")
	GameState.use_supply_station("starter_pantry")
	GameState.use_supply_station("starter_pantry")
	GameState.use_supply_station("starter_faucet")
	GameState.home.item_by_id("starter_water").stock = 15
	GameState.refill_bowl("starter_water")
	GameState.use_supply_station("starter_faucet")
	var stats := GameState.analytics
	_check(stats.events["food_taken"] == 2 and stats.events["food_refilled"] == 1
		and stats.amounts["food_refilled_units"] == 12 and stats.amounts["food_returned_units"] == 12,
		"Futter holen, einfuellen und zuruecktragen zaehlt Aktionen und genaue Mengen")
	_check(stats.events["water_drawn"] == 1 and stats.events["water_refilled"] == 1
		and stats.amounts["water_refilled_units"] == 1 and stats.amounts["water_returned_units"] == 15,
		"Wasser-Analytics unterscheiden Teilfuellung und zurueckgegebenes Wasser")
	GameState.buy_food_package()
	var before := JSON.stringify(stats.to_dict())
	GameState.buy_food_package()
	GameState.refill_bowl("starter_food")
	_check(JSON.stringify(stats.to_dict()) == before, "Abgelehnte Aktionen erzeugen keine fiktiven Analytics")
	GameState.use_supply_station("starter_pantry")
	GameState.order_food()
	GameState.order_food()
	var duration := DifficultyRules.value(GameState.difficulty_id, "delivery_seconds")
	GameState._tick_needs(duration)
	GameState._tick_needs(duration)
	_check(stats.events["food_package_bought"] == 1 and stats.events["food_ordered"] == 2
		and stats.events["food_arrived"] == 2
		and stats.amounts["food_purchased_units"] == 3 * SupplyCatalog.PACKAGE_UNITS
		and stats.amounts["food_arrived_units"] == 2 * SupplyCatalog.PACKAGE_UNITS
		and stats.amounts["coins_spent_food"] == 3 * GameState.food_price()
		and stats.amounts["coins_spent_delivery"] == 2 * GameState.delivery_fee(),
		"Parallelbestellungen, Ankunft und beide Kostenanteile werden genau einmal erfasst")
	var id := GameState.supplies.orders[0].id
	GameState.collect_delivery(id)
	GameState.use_supply_station("starter_pantry")
	GameState.collect_delivery(id)
	_check(stats.events["parcel_collected"] == 1 and stats.events["food_unpacked"] == 2,
		"Erneute Paketabholung dupliziert weder Abhol- noch Einraeumstatistik")
	GameState.reset("realistic")
	GameState.supplies.food_stock = 0
	GameState.buy_food_package(true)
	_check(GameState.analytics.events["emergency_claimed"] == 1
		and GameState.analytics.amounts["emergency_food_units"] == SupplyCatalog.EMERGENCY_UNITS
		and GameState.analytics.events["food_package_bought"] == 0,
		"Notversorgung wird getrennt vom regulaeren Einkauf gesammelt")

func _test_consumption_and_time(tree: SceneTree) -> void:
	print("--- Lokale Analytics: Verbrauch und aktive Katzensekunden ---")
	GameState.reset()
	var cat := _cat()
	GameState._process(2.0)
	GameState.simulation_active = true
	tree.paused = true
	GameState._process(3.0)
	tree.paused = false
	_check(GameState.analytics.active_play_seconds == 0.0,
		"Inaktivitaet und Pause sammeln keine Spielzeit oder Mangelzeit")
	GameState._process(2.0)
	_check(GameState.analytics.active_play_seconds == 2.0
		and GameState.analytics.need_low_seconds["hunger"] == 2.0
		and GameState.analytics.need_low_seconds["health"] == 0.0,
		"Nur aktive Spielzeit und tatsaechlich niedrige Beduerfnisse werden zeitlich erfasst")
	GameState.simulation_active = false
	var food := GameState.home.item_by_id("starter_food")
	food.stock = HomeCatalog.capacity("food")
	var state: HomeCatState = GameState.home.cats[cat.id]
	state.position = HomeCatalog.world(food.port())
	state.clear_task()
	var before := food.stock
	for step in 50:
		GameState._tick_needs(0.1)
	_check(GameState.analytics.amounts["food_consumed_units"] == before - food.stock
		and int(GameState.analytics.amounts["food_consumed_units"]) > 0,
		"Verbrauchs-Analytics stammen aus den echten Fressaktionen der Simulation")

func _test_care_events() -> void:
	print("--- Lokale Analytics: Pflegefolgen nach Altersgruppe ---")
	GameState.reset("realistic")
	var cat := _cat(CatData.Age.SENIOR)
	cat.hunger = 0
	cat.thirst = 0
	cat.health = 0
	GameState._tick_needs(0.1)
	GameState._tick_needs(0.1)
	_check(GameState.analytics.events["cat_became_critical"] == 1,
		"Eine kritische Phase wird nicht pro Frame erneut gezaehlt")
	SaveManager.save_game()
	SaveManager.load_game()
	GameState._tick_needs(0.1)
	_check(GameState.analytics.events["cat_became_critical"] == 1,
		"Laden zaehlt eine bereits kritische Katze nicht noch einmal")
	cat = GameState.home_cats[0]
	var sim := GameState.home_simulation
	sim.pick_up(cat.id)
	sim.begin_care(GameState.home.item_by_id("starter_vet"))
	GameState._tick_needs(HomeSimulation.CARE_SECONDS + 0.1)
	_check(GameState.analytics.events["cat_recovered_from_critical"] == 1,
		"Erfolgreiches Eingreifen wird als Ende der kritischen Phase erfasst")
	cat.health = 0
	GameState._tick_needs(DifficultyRules.value(GameState.difficulty_id, "grace") + 0.1)
	GameState._tick_needs(1.0)
	_check(GameState.analytics.events["cat_became_critical"] == 2
		and GameState.analytics.events["cat_died"] == 1
		and GameState.analytics.deceased_by_age == [0, 0, 1],
		"Ein neuer Vorfall und der Verlust eines Seniors werden genau einmal zugeordnet")
	GameState.reset()
	cat = _cat(CatData.Age.YOUNG)
	cat.hunger = 100
	cat.recovery_timer = CatData.RECOVERY_SECONDS
	GameState._tick_needs(0.1)
	_check(GameState.analytics.events["cat_adopted"] == 1
		and GameState.analytics.adopted_by_age == [1, 0, 0],
		"Auch erfolgreiche Vermittlungen sind nach Altersgruppe auswertbar")
	_check(not JSON.stringify(GameState.analytics.to_dict()).contains(cat.cat_name)
		and not JSON.stringify(GameState.analytics.to_dict()).contains(cat.id),
		"Analytics speichern keine Katzennamen oder individuellen Kennungen")

func _test_persistence() -> void:
	print("--- Lokale Analytics: Versionierung und fehlerhafte Daten ---")
	GameState.reset("challenging")
	GameState.add_coins(GameState.food_price() + GameState.delivery_fee())
	_check(GameState.order_food().is_empty(), "Der Statistik-Spielstand enthaelt eine echte Bestellung")
	GameState.use_supply_station("starter_faucet")
	var snapshot := JSON.stringify(GameState.to_dict())
	SaveManager.save_game()
	GameState.reset()
	_check(SaveManager.load_game() and JSON.stringify(GameState.to_dict()) == snapshot,
		"Analytics werden mit dem Spielstand ohne erneutes Ausloesen gespeichert")
	var legacy := GameState.to_dict()
	legacy.erase("analytics")
	var migrated := SaveManager._migrate(legacy, 3)
	_check(GameState.from_dict(migrated) and GameState.difficulty_id == "challenging"
		and GameState.supplies.cargo_kind == "water"
		and GameState.supplies.orders.size() == 1
		and GameState.analytics.events["water_drawn"] == 0,
		"Version 3 behaelt Modus und Ladung; alte Analytics werden nicht erfunden")
	var broken := GameState.to_dict()
	broken["analytics"]["events"]["food_ordered"] = -1
	snapshot = JSON.stringify(GameState.to_dict())
	_check(not GameState.from_dict(broken) and JSON.stringify(GameState.to_dict()) == snapshot,
		"Beschaedigte Statistikdaten werden vor jeder Zustandsaenderung abgelehnt")
