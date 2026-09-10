## Deterministische Regeln fuer Einrichtung, Versorgung und alte Spielstaende.
extends RefCounted

const AUTO_NEEDS: PackedStringArray = ["hunger", "thirst", "enrichment"]
var _failures: PackedStringArray = []

func run(tree: SceneTree) -> PackedStringArray:
	_test_layout()
	_test_autonomous_care()
	_test_litter()
	_test_manual_care()
	_test_pause(tree)
	_test_saves()
	GameState.reset()
	return _failures

func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FEHLER", description])
	if not condition:
		_failures.append(description)

func _cat() -> CatData:
	var cat := CatData.new()
	cat.id = "home_test_%d" % GameState.rescued_total
	cat.cat_name = "Hauskatze"
	cat.hunger = 25
	cat.thirst = 25
	cat.cleanliness = 30
	cat.health = 30
	cat.enrichment = 25
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	return cat

func _test_layout() -> void:
	print("--- Haus: Einrichtung und Inventar ---")
	GameState.reset()
	var layout := GameState.home_simulation.layout
	_check(GameState.home.items.size() == 6 and layout.save_error().is_empty(),
		"Das kostenlose Haus ist vollstaendig und erreichbar")
	_check(GameState.buy_home_item("toy") == null, "Zusaetzliche Einrichtung braucht Muenzen")
	GameState.add_coins(100)
	var toy := GameState.buy_home_item("toy")
	_check(toy != null and not toy.placed and GameState.coins == 80,
		"Ein Kauf bezahlt genau einmal und legt den Gegenstand ins Inventar")
	var snapshot := JSON.stringify(toy.to_dict())
	for cell in [Vector2i(-1, 4), HomeCatalog.ENTRY, HomeCatalog.START_CELLS[0],
			GameState.home.item_by_id("starter_food").port()]:
		_check(not GameState.place_home_item(toy.id, cell, 0, []).is_empty(),
			"Unzulaessiger Platz %s wird zurueckgewiesen" % cell)
	_check(not layout.placement_error("starter_wash", Vector2i(1, 1), 1, []).is_empty(),
		"Eine nach aussen gedrehte Bedienseite wird abgelehnt")
	var occupied: Array[Vector2] = [HomeCatalog.world(Vector2i(12, 11))]
	_check(not layout.placement_error(toy.id, Vector2i(12, 11), 0, occupied).is_empty(),
		"Figuren duerfen nicht ueberbaut werden")
	_check(layout.placement_error(toy.id, Vector2i(12, 11), 3, []).is_empty(),
		"Die freie Vorschau mit gedrehter Bedienseite ist gueltig")
	_check(JSON.stringify(toy.to_dict()) == snapshot, "Vorschauen veraendern keine gespeicherten Daten")
	_check(GameState.place_home_item(toy.id, Vector2i(12, 11), 3, []).is_empty(),
		"Ein gueltiger Gegenstand laesst sich aufstellen")
	_check(toy.placed and toy.turns == 3 and GameState.coins == 80,
		"Platzieren erhaelt Orientierung und berechnet keinen zweiten Kauf")
	var food := GameState.home.item_by_id("starter_food")
	food.stock = 7
	_check(GameState.store_home_item(food.id).is_empty() and food.stock == 7,
		"Einlagern erhaelt den Vorrat")
	_check(GameState.place_home_item(food.id, HomeCatalog.START_CELLS[0], 0, []).is_empty(),
		"Eingelagerte Gegenstaende lassen sich wieder aufstellen")
	_check(GameState.home.items.size() == 7, "Versetzen und Einlagern duplizieren nichts")

func _test_autonomous_care() -> void:
	print("--- Haus: autonome Versorgung mehrerer Katzen ---")
	GameState.reset()
	var peaks := {}
	for i in 4:
		var cat := _cat()
		peaks[cat.id] = {"hunger": 0.0, "thirst": 0.0, "enrichment": 0.0}
	var food := GameState.home.item_by_id("starter_food")
	var water := GameState.home.item_by_id("starter_water")
	var food_used := 0
	var water_used := 0
	for step in 1200:
		# Eine Station pro Art bleibt knapp; der Spieler haelt ihren Vorrat bereit.
		if step % 50 == 0:
			food.stock = HomeCatalog.capacity("food")
			water.stock = HomeCatalog.capacity("water")
		var food_before := food.stock
		var water_before := water.stock
		GameState._tick_needs(0.1)
		food_used += food_before - food.stock
		water_used += water_before - water.stock
		for cat in GameState.home_cats:
			var seen: Dictionary = peaks[cat.id]
			for need in AUTO_NEEDS:
				seen[need] = maxf(float(seen[need]), float(cat.get(need)))
	for cat in GameState.home_cats:
		var seen: Dictionary = peaks[cat.id]
		_check(float(seen["hunger"]) > 90 and float(seen["thirst"]) > 90 \
				and float(seen["enrichment"]) > 90,
			"Auch %s kommt bei gemeinsamem Stationsangebot an die Reihe" % cat.id)
		if float(seen["hunger"]) <= 90 or float(seen["thirst"]) <= 90 or float(seen["enrichment"]) <= 90:
			printerr("Hoechstwerte %s: %s" % [cat.id, seen])
		var state: HomeCatState = GameState.home.cats[cat.id]
		_check(not GameState.home_simulation.layout.blocked(HomeCatalog.cell(state.position)),
			"Die Katze bleibt auf begehbarem Boden")
	_check(food.stock >= 0 and food.stock <= HomeCatalog.capacity("food")
			and water.stock >= 0 and water.stock <= HomeCatalog.capacity("water")
			and food_used > 0 and water_used > 0,
		"Autonome Versorgung verbraucht begrenzte Vorratsmengen")
	_check(GameState.adopted_total == 0, "Ohne manuelle Behandlung gibt es keine automatische Heilung")

func _test_litter() -> void:
	print("--- Haus: Toilettenhygiene ---")
	GameState.reset()
	var cat := _cat()
	cat.hunger = 100
	cat.thirst = 100
	cat.enrichment = 100
	var litter := GameState.home.item_by_id("starter_litter")
	litter.dirt = HomeCatalog.capacity("litter")
	var state: HomeCatState = GameState.home.cats[cat.id]
	state.toilet_elapsed = HomeSimulation.TOILET_OVERDUE + 1
	var before := cat.cleanliness
	for i in 10:
		GameState._tick_needs(0.1)
	_check(before - cat.cleanliness > 0.9, "Ein volles Katzenklo beeintraechtigt die Sauberkeit")
	litter.dirt = 0
	state.clear_task()
	state.position = HomeCatalog.world(litter.port())
	for i in 40:
		GameState._tick_needs(0.1)
	_check(litter.dirt == 1 and state.toilet_elapsed < 6,
		"Die Katze benutzt das gereinigte Katzenklo und verschmutzt es")
	_check(not GameState.home_simulation.item_in_use(litter.id),
		"Nach der Toilettenbenutzung wird die Station freigegeben")

func _test_manual_care() -> void:
	print("--- Haus: Tragen, Pflege und Vermittlung ---")
	GameState.reset()
	var cat := _cat()
	var sim := GameState.home_simulation
	var wash := GameState.home.item_by_id("starter_wash")
	var vet := GameState.home.item_by_id("starter_vet")
	_check(sim.pick_up(cat.id), "Eine Hauskatze laesst sich gezielt aufnehmen")
	_check(GameState.carried_cats.is_empty() and GameState.rescued_total == 1,
		"Haus-Tragen veraendert den Rettungskorb und Rettungszaehler nicht")
	_check(sim.begin_care(wash), "Eine Waschaktion beginnt")
	sim.step(HomeSimulation.CARE_SECONDS / 2)
	_check(cat.cleanliness == 30 and sim.item_in_use(wash.id),
		"Unfertige Pflege ist belegt, aber noch nicht gutgeschrieben")
	_check(not GameState.store_home_item(wash.id).is_empty(),
		"Ein benutzter Waschplatz laesst sich nicht einlagern")
	sim.cancel_care()
	_check(cat.cleanliness == 30 and not sim.item_in_use(wash.id),
		"Abbrechen loest die Reservierung ohne Pflegebonus")
	sim.begin_care(wash)
	sim.step(HomeSimulation.CARE_SECONDS + 0.1)
	_check(cat.cleanliness == 100, "Abgeschlossene Waschpflege stellt die Sauberkeit her")
	sim.begin_care(vet)
	sim.step(HomeSimulation.CARE_SECONDS + 0.1)
	_check(cat.health == 100 and GameState.coins == 0, "Behandlung ist wirksam und kostenlos")
	cat.hunger = 100
	cat.thirst = 100
	cat.recovery_timer = CatData.RECOVERY_SECONDS
	_check(not cat.all_needs_met(), "Vier gute Werte ohne Beschaeftigung reichen nicht")
	cat.enrichment = 100
	GameState._tick_needs(0.1)
	_check(GameState.adopted_total == 0, "Eine getragene Katze verschwindet nicht durch Adoption")
	_check(sim.drop(sim.layout.free_position()), "Die Katze laesst sich wieder absetzen")
	GameState._tick_needs(0.1)
	GameState._tick_needs(1.0)
	_check(GameState.adopted_total == 1 and GameState.coins == GameState.ADOPTION_REWARD,
		"Erfuellte fuenf Beduerfnisse vermitteln und belohnen genau einmal")
	_check(GameState.home.cats.is_empty(), "Vermittlung hinterlaesst keinen alten Hauszustand")

func _test_pause(tree: SceneTree) -> void:
	print("--- Haus: aktive Spielzeit ---")
	GameState.reset()
	var cat := _cat()
	var before := cat.hunger
	GameState._process(1.0)
	_check(cat.hunger == before, "Inaktiver Spielkontext haelt die Versorgung an")
	GameState.simulation_active = true
	tree.paused = true
	GameState._process(1.0)
	_check(cat.hunger == before, "Pause haelt auch den Always-Autoload an")
	tree.paused = false
	GameState._process(1.0)
	_check(cat.hunger < before, "Aktive Spielzeit treibt dieselbe zentrale Versorgung an")
	GameState.simulation_active = false

func _test_saves() -> void:
	print("--- Haus: Speichern und Migration ---")
	GameState.reset()
	var cat := _cat()
	cat.enrichment = 63
	GameState.add_coins(500)
	GameState.purchase_upgrade("comfort")
	var toy := GameState.buy_home_item("toy")
	GameState.place_home_item(toy.id, Vector2i(12, 11), 3, [])
	GameState.buy_home_item("water")
	GameState.home.item_by_id("starter_food").stock = 7
	GameState.home.item_by_id("starter_water").stock = 11
	GameState.home.item_by_id("starter_litter").dirt = 4
	var state: HomeCatState = GameState.home.cats[cat.id]
	state.toilet_elapsed = 33
	var coins := GameState.coins
	var toy_id := toy.id
	GameState.home_simulation.pick_up(cat.id)
	_check(SaveManager.save_path != SaveManager.SAVE_PATH
			and SaveManager.settings_path != SaveManager.SETTINGS_PATH,
		"Automatische Tests benutzen isolierte Speicherpfade")
	_check(SaveManager.save_game(), "Hausspielstand wird geschrieben")
	GameState.reset()
	_check(SaveManager.load_game(), "Hausspielstand wird geladen")
	_check(GameState.coins == coins and GameState.upgrade_level("comfort") == 1,
		"Muenzen und Upgrades bleiben erhalten")
	_check(GameState.home.items.size() == 8 and GameState.home.item_by_id(toy_id).turns == 3,
		"Einrichtung, Inventar und Drehung bleiben erhalten")
	_check(GameState.home.item_by_id("starter_food").stock == 7
			and GameState.home.item_by_id("starter_water").stock == 11
			and GameState.home.item_by_id("starter_litter").dirt == 4,
		"Vorrat und Verschmutzung ueberstehen das Laden")
	var restored: CatData = GameState.home_cats[0]
	var restored_state: HomeCatState = GameState.home.cats[restored.id]
	_check(restored.enrichment == 63 and restored_state.toilet_elapsed == 33
			and GameState.home_simulation.held_cat_id.is_empty(),
		"Katzenwerte bleiben erhalten; ein unterbrochenes Tragen wird sicher geloest")
	var legacy := GameState.to_dict()
	legacy.erase("home")
	for raw_cat: Dictionary in legacy["home_cats"]:
		raw_cat.erase("enrichment")
	for version in [0, 1]:
		var old_state := legacy.duplicate(true)
		if version == 0:
			old_state.erase("upgrade_levels")
		var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"version": version, "state": old_state}))
		file.close()
		GameState.reset()
		_check(SaveManager.load_game(), "Spielstand Version %d wird migriert" % version)
		_check(GameState.coins == coins and GameState.home_cats.size() == 1
				and GameState.home_cats[0].enrichment == 100 and GameState.home.items.size() == 6,
			"Migration erhaelt Katzen/Muenzen und liefert einmalig die Grundausstattung")
	SaveManager.save_game()
	SaveManager.load_game()
	_check(GameState.home.items.size() == 6, "Erneutes Laden schenkt keine weitere Ausstattung")
	var snapshot := JSON.stringify(GameState.to_dict())
	var broken := GameState.to_dict()
	var home: Dictionary = broken["home"]
	var items: Array = home["items"]
	items[0]["stock"] = -1
	_check(not GameState.from_dict(broken), "Beschaedigte Hausdaten werden abgelehnt")
	_check(JSON.stringify(GameState.to_dict()) == snapshot, "Fehlgeschlagenes Laden bleibt atomar")
	SaveManager.delete_save()
