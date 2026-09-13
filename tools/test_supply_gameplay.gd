## Regeln fuer Vorratstransfers, Lieferungen, Schwierigkeitsgrade und Migration.
extends RefCounted

var _failures: PackedStringArray = []
var _next_cat: int = 0

func run(tree: SceneTree) -> PackedStringArray:
	_test_transfers()
	_test_purchases()
	_test_deliveries(tree)
	_test_emergency()
	_test_age_and_mortality()
	_test_rescue_and_cleanup()
	_test_roundtrip()
	_test_legacy()
	tree.paused = false
	GameState.reset()
	return _failures

func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FEHLER", text])
	if not ok:
		_failures.append(text)

func _cat(age: CatData.Age = CatData.Age.ADULT, health: float = 0.0) -> CatData:
	var cat := CatData.new()
	_next_cat += 1
	cat.id = "supply_test_%d" % _next_cat
	cat.cat_name = "Pflegekatze"
	cat.age_group = age
	cat.hunger = 0.0
	cat.thirst = 0.0
	cat.health = health
	cat.cleanliness = 20.0
	cat.enrichment = 20.0
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	return cat

func _test_transfers() -> void:
	print("--- Versorgung: echte, begrenzte Transfers ---")
	GameState.reset()
	var supplies := GameState.supplies
	var food := GameState.home.item_by_id("starter_food")
	var water := GameState.home.item_by_id("starter_water")
	var before := JSON.stringify(GameState.to_dict())
	_check(not GameState.refill_bowl(food.id).is_empty()
		and JSON.stringify(GameState.to_dict()) == before, "Ohne geholtes Futter wird kein Napf gefuellt")
	_check(GameState.use_supply_station("starter_pantry").is_empty()
		and supplies.cargo_amount == HomeCatalog.capacity("food")
		and supplies.food_stock == SupplyCatalog.START_FOOD - supplies.cargo_amount,
		"Futterholen bucht Portionen vom gemeinsamen Schrank in die Haende")
	_check(GameState.refill_bowl(food.id).is_empty()
		and food.stock == HomeCatalog.capacity("food") and supplies.cargo_kind.is_empty(),
		"Eine passende Ladung fuellt den Napf und wird dabei verbraucht")
	GameState.use_supply_station("starter_pantry")
	before = JSON.stringify(GameState.to_dict())
	_check(not GameState.refill_bowl(food.id).is_empty()
		and JSON.stringify(GameState.to_dict()) == before, "Ein voller Napf verbraucht keine Portionen")
	food.stock -= 3
	var available := GameState.supply_actions.available_food()
	GameState.refill_bowl(food.id)
	_check(supplies.cargo_amount == HomeCatalog.capacity("food") - 3
		and GameState.supply_actions.available_food() == available,
		"Teilfuellungen erhalten Restmenge und Gesamtbestand exakt")
	before = JSON.stringify(GameState.to_dict())
	_check(not GameState.refill_bowl(water.id).is_empty()
		and JSON.stringify(GameState.to_dict()) == before, "Die falsche Ladung veraendert keinen Bestand")
	GameState.use_supply_station("starter_pantry")
	_check(supplies.cargo_kind.is_empty() and supplies.food_stock == available - food.stock,
		"Uebriges Futter wird verlustfrei in den Schrank zurueckgelegt")
	GameState.use_supply_station("starter_faucet")
	water.stock = HomeCatalog.capacity("water") - 2
	GameState.refill_bowl(water.id)
	_check(water.stock == HomeCatalog.capacity("water")
		and supplies.cargo_amount == HomeCatalog.capacity("water") - 2,
		"Wasser wird nur am Hahn erzeugt und am Napf passend portioniert")
	GameState.use_supply_station("starter_faucet")
	_check(supplies.cargo_kind.is_empty() and GameState.coins == 0,
		"Wasser zurueckgeben ist explizit und kostet keine Muenzen")
	var cat := _cat()
	GameState.use_supply_station("starter_faucet")
	_check(not GameState.home_simulation.pick_up(cat.id), "Ladung und Hauskatze passen nicht gleichzeitig auf den Arm")
	GameState.use_supply_station("starter_faucet")
	GameState.home_simulation.pick_up(cat.id)
	_check(not GameState.use_supply_station("starter_pantry").is_empty(),
		"Eine getragene Hauskatze sperrt die physische Vorratsaufnahme")
	GameState.home_simulation.drop(GameState.home_simulation.layout.free_position())
	var stock := supplies.food_stock
	GameState.store_home_item("starter_pantry")
	_check(not GameState.use_supply_station("starter_pantry").is_empty()
		and supplies.food_stock == stock, "Ein eingelagerter Schrank ist nicht aus der Ferne bedienbar")
	var extra := GameState.buy_home_item("pantry")
	_check(extra != null and supplies.food_stock == stock, "Neue Schraenke duplizieren kein Futter")

func _test_purchases() -> void:
	print("--- Versorgung: Kosten und Paketinhalt ---")
	for mode in DifficultyRules.IDS:
		GameState.reset(mode)
		var price := GameState.food_price()
		_check(price + GameState.delivery_fee() < GameState.ADOPTION_REWARD,
			"Eine Vermittlung finanziert ein weiteres geliefertes Paket (%s)" % mode)
		if price > 0:
			var before := JSON.stringify(GameState.to_dict())
			_check(not GameState.buy_food_package().is_empty()
				and not GameState.order_food().is_empty()
				and JSON.stringify(GameState.to_dict()) == before,
				"Zu wenig Geld lehnt Abholung und Lieferung atomar ab (%s)" % mode)
		GameState.add_coins(price * 2)
		var basket_cat := CatData.create_random()
		GameState.pick_up_cat(basket_cat)
		_check(GameState.buy_food_package().is_empty()
			and GameState.coins == price
			and GameState.supplies.cargo_amount == SupplyCatalog.PACKAGE_UNITS
			and GameState.carried_cats.size() == 1,
			"Der Einkauf zahlt genau einmal und benutzt nicht den Rettungskorb (%s)" % mode)
		var before := JSON.stringify(GameState.to_dict())
		_check(not GameState.buy_food_package().is_empty()
			and not GameState.refill_bowl("starter_food").is_empty()
			and JSON.stringify(GameState.to_dict()) == before,
			"Volle Haende und ungeoeffnete Pakete werden nicht erneut verrechnet (%s)" % mode)
		GameState.use_supply_station("starter_pantry")
		_check(GameState.supplies.food_stock == SupplyCatalog.START_FOOD + SupplyCatalog.PACKAGE_UNITS
			and GameState.supplies.cargo_kind.is_empty(), "Einraeumen schreibt ein Paket genau einmal gut (%s)" % mode)

func _test_deliveries(tree: SceneTree) -> void:
	print("--- Versorgung: mehrere Lieferungen und aktive Spielzeit ---")
	GameState.reset("challenging")
	var cost := GameState.food_price() + GameState.delivery_fee()
	GameState.add_coins(cost * 4)
	var duration := DifficultyRules.value(GameState.difficulty_id, "delivery_seconds")
	GameState.order_food()
	var first := GameState.supplies.orders[0]
	GameState._process(duration * 2)
	_check(first.remaining == duration, "Inaktiver Spielkontext haelt Lieferungen an")
	GameState.simulation_active = true
	tree.paused = true
	GameState._process(duration * 2)
	tree.paused = false
	_check(first.remaining == duration, "Pause haelt Lieferungen auch ohne Hauskatzen an")
	GameState._process(5.0)
	GameState.order_food()
	_check(GameState.supplies.orders.size() == 2 and GameState.coins == cost * 2
		and GameState.supplies.orders[0].id != GameState.supplies.orders[1].id,
		"Mehrere Bestellungen haben eigene IDs, Laufzeiten und exakte Kosten")
	GameState._process(duration - 5.0 - 0.01)
	_check(GameState.supplies.ready_count() == 0, "Vor der Liefergrenze ist kein Paket abholbar")
	GameState._process(0.02)
	_check(GameState.supplies.ready_count() == 1, "Nur die bereits faellige Lieferung kommt an")
	GameState.order_food()
	_check(GameState.supplies.orders.size() == 3, "Auch ein wartendes Paket sperrt keine weitere Bestellung")
	GameState._process(duration + 0.1)
	GameState._process(duration + 0.1)
	_check(GameState.supplies.ready_count() == 3 and GameState.supplies.food_stock == SupplyCatalog.START_FOOD,
		"Ankunft liefert genau die bestellten Pakete, nicht automatisch Schrankinhalt")
	var id := GameState.supplies.orders[1].id
	_check(GameState.collect_delivery(id).is_empty() and GameState.supplies.ready_count() == 2,
		"Eine Abholung nimmt genau das ausgewaehlte Paket")
	GameState.use_supply_station("starter_pantry")
	_check(not GameState.collect_delivery(id).is_empty() and GameState.supplies.ready_count() == 2,
		"Eine wiederholte Abholung derselben ID erzeugt nichts")
	while GameState.supplies.ready_count() > 0:
		GameState.collect_delivery()
		GameState.use_supply_station("starter_pantry")
	_check(GameState.supplies.food_stock == SupplyCatalog.START_FOOD + 3 * SupplyCatalog.PACKAGE_UNITS,
		"Alle drei Pakete lassen sich getrennt abholen und vollstaendig einraeumen")
	GameState.simulation_active = false

func _test_emergency() -> void:
	print("--- Versorgung: Notration ohne Dauergeschenke ---")
	GameState.reset("realistic")
	GameState.supplies.food_stock = 0
	_check(GameState.can_claim_emergency() and GameState.buy_food_package(true).is_empty()
		and GameState.supplies.cargo_amount == SupplyCatalog.EMERGENCY_UNITS and GameState.coins == 0,
		"Bei Geldnot ist eine kleine Ration abholbar")
	_check(not GameState.can_claim_emergency() and not GameState.buy_food_package(true).is_empty(),
		"Eine bereits getragene Notration verhindert weitere Gratisrationen")
	GameState.use_supply_station("starter_pantry")
	_check(not GameState.can_claim_emergency(), "Auch eingeraeumtes Notfutter zaehlt als Vorrat")
	GameState.supplies.food_stock = 0
	var bowl := GameState.home.item_by_id("starter_food")
	bowl.stock = 1
	GameState.store_home_item(bowl.id)
	_check(not GameState.can_claim_emergency(), "Ein eingelagerter gefuellter Napf versteckt kein Futter")
	bowl.stock = 0
	GameState.add_coins(GameState.food_price() + GameState.delivery_fee())
	GameState.order_food()
	GameState._tick_needs(DifficultyRules.value(GameState.difficulty_id, "delivery_seconds"))
	_check(not GameState.can_claim_emergency(), "Abholbereite Pakete zaehlen als verfuegbares Futter")

func _test_age_and_mortality() -> void:
	print("--- Schwierigkeit: Senioren und genau einmalige Sterbefaelle ---")
	GameState.reset()
	var protected := _cat(CatData.Age.SENIOR)
	for i in 20:
		GameState._tick_needs(100.0)
	_check(protected.state == CatData.State.AT_HOME and GameState.deceased_total == 0,
		"Entspannt schuetzt auch vernachlaessigte Senioren dauerhaft")
	for mode in ["challenging", "realistic"]:
		GameState.reset(mode)
		var adult := _cat(CatData.Age.ADULT, 80.0)
		var senior := _cat(CatData.Age.SENIOR, 80.0)
		GameState._tick_needs(1.0)
		_check(senior.health < adult.health
			and is_equal_approx((80.0 - senior.health) / (80.0 - adult.health),
				DifficultyRules.value(mode, "senior")),
			"Senioren haben den konfigurierten hoeheren Gesundheitsverlust (%s)" % mode)
		GameState.reset(mode)
		var cat := _cat()
		var deaths: Array[CatData] = []
		var on_death := func(lost: CatData) -> void: deaths.append(lost)
		GameState.cat_died.connect(on_death)
		var grace := DifficultyRules.value(mode, "grace")
		GameState._tick_needs(grace - 0.01)
		_check(cat.state == CatData.State.AT_HOME and GameState.care_warning(cat).contains("Lebensgefahr"),
			"Vor Ablauf der Schonfrist bleibt die Katze mit Warnung am Leben (%s)" % mode)
		GameState._tick_needs(0.02)
		GameState._tick_needs(grace)
		GameState._die(cat)
		_check(deaths.size() == 1 and cat.state == CatData.State.DEAD and GameState.deceased_total == 1
			and GameState.home_cats.is_empty() and GameState.home.cats.is_empty()
			and GameState.adopted_total == 0 and GameState.coins == 0 and GameState.rescued_total == 1,
			"Nach der Grenze gibt es genau einen Verlust und keine Vermittlungsbelohnung (%s)" % mode)
		GameState.cat_died.disconnect(on_death)
		GameState.reset(mode)
		cat = _cat(CatData.Age.SENIOR, 25.0)
		GameState._tick_needs(1.0)
		_check(cat.state == CatData.State.AT_HOME and cat.critical_elapsed == 0.0,
			"Ein frisch aufgenommener Senior stirbt nicht sofort (%s)" % mode)

func _test_rescue_and_cleanup() -> void:
	print("--- Schwierigkeit: Eingreifen und Freigeben von Stationen ---")
	GameState.reset("realistic")
	var cat := _cat()
	var sim := GameState.home_simulation
	var grace := DifficultyRules.value(GameState.difficulty_id, "grace")
	GameState._tick_needs(grace - 1.0)
	sim.pick_up(cat.id)
	sim.begin_care(GameState.home.item_by_id("starter_vet"))
	GameState._tick_needs(HomeSimulation.CARE_SECONDS + 0.1)
	_check(cat.health == CatData.NEED_MAX and cat.critical_elapsed == 0.0
		and cat.state == CatData.State.AT_HOME,
		"Erfolgreiche Behandlung desselben Schritts rettet die Katze vor der Todesentscheidung")
	GameState.reset("realistic")
	cat = _cat()
	_cat(CatData.Age.SENIOR)
	sim = GameState.home_simulation
	sim.pick_up(cat.id)
	var wash := GameState.home.item_by_id("starter_wash")
	sim.begin_care(wash)
	cat.critical_elapsed = grace - 0.1
	GameState.home_cats[1].critical_elapsed = grace - 0.1
	GameState._tick_needs(0.2)
	_check(GameState.deceased_total == 2 and sim.held_cat_id.is_empty()
		and GameState.home.cats.is_empty() and not sim.item_in_use(wash.id),
		"Gleichzeitige Sterbefaelle loesen auch eine getragene Katze und ihre Pflegebelegung")
	GameState.reset("realistic")
	cat = _cat()
	cat.hunger = 100
	cat.thirst = 100
	GameState._tick_needs(grace)
	_check(cat.state == CatData.State.AT_HOME and cat.critical_elapsed == 0.0,
		"Fehlende Beschaeftigung oder niedrige Gesundheit allein loest keinen Tod aus")

func _test_roundtrip() -> void:
	print("--- Versorgung und Schwierigkeit: Speichern und ungueltige Daten ---")
	GameState.reset("realistic")
	var cat := _cat(CatData.Age.SENIOR)
	cat.critical_elapsed = 7.5
	GameState.add_coins(100)
	GameState.order_food()
	GameState.order_food()
	GameState.supplies.step(4.25)
	GameState.use_supply_station("starter_faucet")
	GameState.supplies.cargo_amount = 7
	var snapshot := JSON.stringify(GameState.to_dict())
	_check(SaveManager.save_game(), "Vorrats- und Risikospielstand wird gespeichert")
	var old_save := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	if old_save == null:
		_check(false, "Der isolierte Offline-Testspielstand kann geschrieben werden")
		return
	old_save.store_string(JSON.stringify({
		"version": SaveManager.SAVE_VERSION, "saved_at": 0, "state": GameState.to_dict()}))
	old_save.close()
	GameState.reset()
	_check(SaveManager.load_game() and JSON.stringify(GameState.to_dict()) == snapshot,
		"Auch ein alter Zeitstempel veraendert Modus, Senior, Risiko, Ladung und Lieferzeiten beim Laden nicht")
	var next := GameState.supplies.next_order
	GameState.order_food()
	_check(GameState.supplies.orders.back().id == next, "Neue Bestell-IDs bleiben nach Laden eindeutig")
	var corruptions: Array[Dictionary] = []
	var broken := GameState.to_dict()
	broken["difficulty_id"] = "unknown"
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["supplies"]["food_stock"] = -1
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["supplies"]["orders"].append(broken["supplies"]["orders"][0].duplicate())
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["supplies"]["cargo_kind"] = "package"
	broken["supplies"]["cargo_amount"] = 0
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["home_cats"][0]["age_group"] = 99
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["home_cats"][0]["critical_elapsed"] = INF
	corruptions.append(broken)
	broken = GameState.to_dict()
	broken["home_cats"][0]["health"] = "ungueltig"
	corruptions.append(broken)
	snapshot = JSON.stringify(GameState.to_dict())
	for data in corruptions:
		_check(not GameState.from_dict(data) and JSON.stringify(GameState.to_dict()) == snapshot,
			"Ungueltige neue Spielstanddaten werden vor einer Zustandsaenderung abgelehnt")

func _test_legacy() -> void:
	print("--- Versorgung: alte und dicht eingerichtete Haeuser ---")
	GameState.reset()
	var cat := _cat(CatData.Age.SENIOR)
	GameState.home.item_by_id("starter_food").stock = 7
	GameState.add_coins(71)
	var legacy := GameState.to_dict()
	var house: Dictionary = legacy["home"]
	var items: Array = house["items"]
	for i in range(items.size() - 1, -1, -1):
		if SupplyCatalog.FIXTURES.has(items[i]["kind"]):
			items.remove_at(i)
	var toy := HomeItemData.new()
	toy.id = "existing_toy"
	toy.kind = "toy"
	toy.cell = HomeCatalog.START_CELLS[6]
	items.append(toy.to_dict())
	var migrated := SaveManager._migrate(legacy, 2)
	_check(GameState.from_dict(migrated) and GameState.difficulty_id == DifficultyRules.DEFAULT
		and GameState.home_cats[0].age_group == CatData.Age.ADULT
		and GameState.home_cats[0].id == cat.id and GameState.coins == 71
		and GameState.home.item_by_id("starter_food").stock == 7,
		"Version 2 behaelt Katzen und vorhandene Vorrate und startet sicher in Entspannt")
	_check(GameState.home.item_by_id(toy.id).cell == toy.cell
		and GameState.home_simulation.layout.save_error().is_empty()
		and GameState.home.items.size() == HomeCatalog.KINDS.size() + 1,
		"Neue Stationen weichen belegten Plaetzen aus, ohne alte Einrichtung zu versetzen")
	GameState.supplies.food_stock = 3
	SaveManager.save_game()
	SaveManager.load_game()
	_check(GameState.supplies.food_stock == 3
		and GameState.home.items.size() == HomeCatalog.KINDS.size() + 1,
		"Wiederholtes Laden fuellt weder Vorrat noch Grundausstattung erneut auf")
	var crowded := HomeData.new()
	for y in range(1, HomeCatalog.ROOM_SIZE.y - 1, 2):
		for x in range(2, HomeCatalog.ROOM_SIZE.x - 2):
			var cell := Vector2i(x, y)
			if HomeCatalog.ENTRANCE_CLEARANCE.has_point(cell):
				continue
			var furniture := HomeItemData.new()
			furniture.id = "packed_%d_%d" % [x, y]
			furniture.kind = "toy"
			furniture.cell = cell
			crowded.items.append(furniture)
	_check(HomeLayout.new(crowded).save_error().is_empty(), "Dichtes Migrations-Testhaus bleibt begehbar")
	var original_count := crowded.items.size()
	crowded.add_supply_fixtures()
	_check(not crowded.item_by_id("starter_pantry").placed
		and not crowded.item_by_id("starter_faucet").placed
		and crowded.items.size() == original_count + 2
		and HomeLayout.new(crowded).save_error().is_empty(),
		"Ohne freien Platz landet die neue Grundausstattung sicher im Inventar")
