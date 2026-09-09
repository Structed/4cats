## Automatischer Durchlauf der Spiellogik.
##
## Aufruf:
##   godot --headless --path . -- --test
##
## Prueft die Kette Retten -> Tragen -> Zuhause -> Pflegen -> Adoption sowie
## Muenzen, Upgrades und das Speichern. Exit-Code 1, wenn etwas nicht stimmt.
##
## Der Test laeuft bewusst im normalen Spielstart mit, weil die Autoloads
## (GameState, SaveManager) nur dort zur Verfuegung stehen.
extends Node

const CAR_FACING_REGIONS := {
	true: [Rect2i(272, 235, 16, 21), Rect2i(272, 267, 16, 21)],
	false: [Rect2i(320, 235, 16, 21), Rect2i(320, 267, 16, 21)],
}

var _failures: PackedStringArray = []


func _ready() -> void:
	run_all()


## Fuehrt alle Tests aus und beendet das Programm mit passendem Exit-Code.
func run_all() -> void:
	_test_cat_data()
	_test_movement_balance()
	_test_car_directions()
	_test_carrying()
	_test_care_and_adoption()
	_test_upgrades()
	_test_save_roundtrip()
	_test_level_generation()

	print("")
	if _failures.is_empty():
		print("Alle Tests bestanden.")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FEHLGESCHLAGEN: %s" % failure)
		printerr("%d Test(s) fehlgeschlagen." % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [ok]    %s" % description)
	else:
		print("  [FEHLER] %s" % description)
		_failures.append(description)


# --- Tests -------------------------------------------------------------------

## Die Tempo-Werte muessen zueinander passen, sonst ist das Spiel unspielbar.
## Genau hier lag der urspruengliche Fehler: der Spieler war schneller als das
## Ruhe-Limit der Katzen, dadurch flohen sie *immer* und Vertrauen konnte nie
## wachsen.
func _test_movement_balance() -> void:
	print("--- Tempo-Verhaeltnisse ---")

	_check(Player.WALK_SPEED < Cat.CALM_SPEED_LIMIT,
		"Gehen (%.0f) bleibt unter dem Ruhe-Limit (%.0f) -- sonst fliehen Katzen immer"
			% [Player.WALK_SPEED, Cat.CALM_SPEED_LIMIT])

	_check(Player.SPRINT_SPEED > Cat.CALM_SPEED_LIMIT,
		"Sprinten (%.0f) liegt ueber dem Ruhe-Limit (%.0f) -- sonst hat Rennen keine Folgen"
			% [Player.SPRINT_SPEED, Cat.CALM_SPEED_LIMIT])

	_check(Cat.FLEE_SPEED < Player.WALK_SPEED,
		"Fliehen (%.0f) ist langsamer als Gehen (%.0f) -- eine Katze muss einholbar sein"
			% [Cat.FLEE_SPEED, Player.WALK_SPEED])

	_check(Cat.WANDER_SPEED < Cat.FLEE_SPEED, "Streunen ist gemuetlicher als Fliehen")

	_check(Cat.TRUST_RADIUS <= Cat.NOTICE_RADIUS,
		"Vertrauensradius liegt innerhalb des Aufmerksamkeitsradius")

	_check(Cat.FLEE_DURATION > 0.0 and Cat.FLEE_DURATION < 3.0,
		"Panik dauert %.1f s -- lang genug zum Wegkommen, kurz genug zum Wiederkommen"
			% Cat.FLEE_DURATION)

	# Eine fliehende Katze muss den Schreckbereich eines Hundes verlassen
	# koennen, sonst wird sie sofort wieder aufgeschreckt und bleibt fuer
	# immer unfangbar.
	var flee_distance := Cat.FLEE_SPEED * Cat.FLEE_DURATION
	_check(flee_distance > Dog.SCARE_RADIUS,
		"Eine Flucht traegt %.0f px und damit aus dem Hunde-Radius (%.0f) heraus"
			% [flee_distance, Dog.SCARE_RADIUS])

	# Wie lange dauert es, eine ruhige Katze zu gewinnen? Der Wert soll sich
	# nach Zuwendung anfuehlen, nicht nach Warteschleife.
	var seconds_shy := Cat.TRUST_THRESHOLD / (Cat.TRUST_GAIN * (1.0 - 0.6 * 1.0))
	var seconds_bold := Cat.TRUST_THRESHOLD / Cat.TRUST_GAIN
	print("  Vertrauen dauert %.1f s (zutraulich) bis %.1f s (sehr scheu)"
		% [seconds_bold, seconds_shy])
	_check(seconds_shy < 8.0, "Auch die scheuste Katze ist in unter 8 s gewonnen")


func _test_car_directions() -> void:
	print("--- Fahrtrichtung der Autos ---")
	var scene: PackedScene = load("res://scenes/rescue/hazards/car.tscn")

	for driving_down: bool in [true, false]:
		var direction_name := "unten" if driving_down else "oben"
		var expected_regions: Array = CAR_FACING_REGIONS[driving_down]
		var regions: Array[Rect2i] = UrbanTiles.CAR_REGIONS_DOWN if driving_down else UrbanTiles.CAR_REGIONS_UP
		_check(regions == expected_regions,
			"Beide Autofarben nach %s nutzen die passende Ansicht" % direction_name)

		var car: Car = scene.instantiate()
		car.driving_down = driving_down
		car.travel_min = 0.0
		car.travel_max = 100.0
		car.position = Vector2(42.0, 40.0)
		add_child(car)
		car.set_physics_process(false)
		car.speed = 60.0

		var sprite: Sprite2D = car.get_node("Sprite")
		var atlas := sprite.texture as AtlasTexture
		_check(atlas != null, "Das Auto nach %s hat eine Atlastextur" % direction_name)
		if atlas != null:
			_check(expected_regions.has(Rect2i(atlas.region)),
				"Das Auto nach %s zeigt in seine Fahrtrichtung" % direction_name)
		_check(not sprite.flip_h and not sprite.flip_v and is_zero_approx(sprite.rotation),
			"Das Auto nach %s bleibt aufrecht und ungespiegelt" % direction_name)

		var start := car.position
		var direction := 1.0 if driving_down else -1.0
		car._physics_process(0.25)
		_check(car.position.is_equal_approx(start + Vector2(0.0, direction * 15.0)),
			"Das Auto nach %s bewegt sich mit unveraendertem Tempo in seiner Spur" % direction_name)

		car.position.y = car.travel_max if driving_down else car.travel_min
		car._physics_process(0.25)
		var wrapped_y := car.travel_min if driving_down else car.travel_max
		_check(car.position.is_equal_approx(Vector2(start.x, wrapped_y)),
			"Das Auto nach %s erscheint am anderen Strassenende wieder" % direction_name)
		_check(sprite.texture == atlas,
			"Beim Wiedereinsetzen nach %s bleibt die Ansicht erhalten" % direction_name)
		car.queue_free()


func _test_cat_data() -> void:
	print("--- Katzendaten ---")
	var cat := CatData.create_random()
	_check(not cat.id.is_empty(), "Katze bekommt eine Kennung")
	_check(not cat.cat_name.is_empty(), "Katze bekommt einen Namen")
	_check(cat.fur_variant >= 0 and cat.fur_variant < CatData.FUR_VARIANTS, "Fellvariante liegt im gueltigen Bereich")
	_check(not cat.all_needs_met(), "Ein frischer Streuner ist noch nicht genesen")

	cat.hunger = 100.0
	cat.thirst = 100.0
	cat.cleanliness = 100.0
	cat.health = 100.0
	_check(cat.all_needs_met(), "Voll versorgte Katze gilt als genesen")
	_check(is_equal_approx(cat.wellbeing(), 100.0), "Gesamtwert stimmt")


func _test_carrying() -> void:
	print("--- Tragen ---")
	GameState.reset()
	_check(GameState.carry_capacity() == GameState.BASE_CARRY_CAPACITY, "Grundkapazitaet stimmt")

	var capacity := GameState.carry_capacity()
	for i in capacity:
		_check(GameState.pick_up_cat(CatData.create_random()), "Katze %d passt noch in den Korb" % (i + 1))

	_check(not GameState.can_carry_more(), "Korb ist danach voll")
	_check(not GameState.pick_up_cat(CatData.create_random()), "Ueber die Kapazitaet hinaus geht nichts")

	var lost := GameState.lose_carried_cat()
	_check(lost != null, "Eine Katze kann entwischen")
	_check(lost.state == CatData.State.WILD, "Entwischte Katze streunt wieder")
	_check(GameState.can_carry_more(), "Danach ist wieder Platz")

	var delivered := GameState.deliver_carried_cats()
	_check(delivered == capacity - 1, "Alle uebrigen Katzen kommen zu Hause an")
	_check(GameState.carried_cats.is_empty(), "Der Korb ist danach leer")
	_check(GameState.home_cats.size() == capacity - 1, "Die Katzen liegen jetzt zu Hause")


func _test_care_and_adoption() -> void:
	print("--- Pflege und Vermittlung ---")
	GameState.reset()

	var cat := CatData.create_random()
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()

	var adopted_cats: Array[CatData] = []
	GameState.cat_adopted.connect(func(adopted: CatData, _reward: int) -> void:
		adopted_cats.append(adopted))

	# Alle Beduerfnisse erfuellen und die Zeit vorspulen.
	cat.hunger = 100.0
	cat.thirst = 100.0
	cat.cleanliness = 100.0
	cat.health = 100.0

	var elapsed := 0.0
	while elapsed < CatData.RECOVERY_SECONDS + 5.0 and adopted_cats.is_empty():
		GameState._tick_needs(0.5)
		elapsed += 0.5
		# Pflege aufrechterhalten, sonst sinken die Werte wieder.
		cat.hunger = 100.0
		cat.thirst = 100.0
		cat.cleanliness = 100.0
		cat.health = 100.0

	_check(adopted_cats.size() == 1, "Gesunde Katze wird nach der Genesungszeit vermittelt")
	_check(GameState.home_cats.is_empty(), "Vermittelte Katze ist nicht mehr zu Hause")
	_check(GameState.coins == GameState.ADOPTION_REWARD, "Vermittlung bringt Muenzen")
	_check(GameState.adopted_total == 1, "Zaehler fuer Vermittlungen stimmt")

	# Vernachlaessigung: Werte sinken, aber nichts geht unter null.
	GameState.reset()
	var neglected := CatData.create_random()
	neglected.hunger = 1.0
	neglected.thirst = 1.0
	GameState.pick_up_cat(neglected)
	GameState.deliver_carried_cats()
	for i in 200:
		GameState._tick_needs(1.0)
	_check(neglected.hunger >= 0.0 and neglected.health >= 0.0, "Beduerfnisse fallen nie unter null")
	_check(GameState.home_cats.size() == 1, "Vernachlaessigte Katze bleibt am Leben")


func _test_upgrades() -> void:
	print("--- Ausbauten ---")
	GameState.reset()

	_check(not GameState.can_afford_upgrade("carry_capacity"), "Ohne Muenzen laesst sich nichts ausbauen")

	GameState.add_coins(10000)
	var before := GameState.carry_capacity()
	_check(GameState.purchase_upgrade("carry_capacity"), "Tragekorb laesst sich ausbauen")
	_check(GameState.carry_capacity() == before + 1, "Kapazitaet steigt um eins")

	var max_level := GameState.upgrade_max_level("carry_capacity")
	while GameState.upgrade_level("carry_capacity") < max_level:
		GameState.purchase_upgrade("carry_capacity")
	_check(GameState.upgrade_cost("carry_capacity") == -1, "Voll ausgebaut kostet nichts mehr")
	_check(not GameState.purchase_upgrade("carry_capacity"), "Ueber die Hoechststufe hinaus geht nichts")

	GameState.purchase_upgrade("comfort")
	_check(GameState.decay_multiplier() < 1.0, "Komfort bremst den Beduerfnis-Abbau")
	GameState.purchase_upgrade("vet")
	_check(GameState.recovery_multiplier() < 1.0, "Tierarzt verkuerzt die Genesung")
	GameState.purchase_upgrade("treats")
	_check(GameState.shyness_multiplier() < 1.0, "Leckerlis machen Katzen zutraulicher")


func _test_save_roundtrip() -> void:
	print("--- Speichern und Laden ---")
	GameState.reset()

	var cat := CatData.create_random()
	cat.cat_name = "Testkatze"
	cat.fur_variant = 2
	cat.hunger = 77.0
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	GameState.add_coins(250)
	GameState.purchase_upgrade("treats")

	_check(SaveManager.save_game(), "Spielstand laesst sich schreiben")
	_check(SaveManager.has_save(), "Spielstand ist danach vorhanden")

	var coins_before := GameState.coins
	var treats_before := GameState.upgrade_level("treats")

	GameState.reset()
	_check(GameState.home_cats.is_empty(), "Nach dem Zuruecksetzen ist alles leer")

	_check(SaveManager.load_game(), "Spielstand laesst sich lesen")
	_check(GameState.coins == coins_before, "Muenzen werden wiederhergestellt")
	_check(GameState.upgrade_level("treats") == treats_before, "Ausbaustufen werden wiederhergestellt")
	_check(GameState.home_cats.size() == 1, "Die Katze ist wieder da")
	if GameState.home_cats.size() == 1:
		var restored: CatData = GameState.home_cats[0]
		_check(restored.cat_name == "Testkatze", "Name bleibt erhalten")
		_check(restored.fur_variant == 2, "Fellvariante bleibt erhalten")
		_check(is_equal_approx(restored.hunger, 77.0), "Beduerfniswerte bleiben erhalten")

	# Beschaedigter Spielstand darf nicht zum Absturz fuehren.
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ kaputt ohne Ende")
	file.close()
	_check(not SaveManager.load_game(), "Beschaedigter Spielstand wird abgelehnt")

	SaveManager.delete_save()
	_check(not SaveManager.has_save(), "Spielstand laesst sich loeschen")


func _test_level_generation() -> void:
	print("--- Levelaufbau ---")
	var ground := TileMapLayer.new()
	var objects := TileMapLayer.new()
	var tileset: TileSet = load("res://resources/urban_tileset.tres")
	ground.tile_set = tileset
	objects.tile_set = tileset
	add_child(ground)
	add_child(objects)

	var generator := LevelGenerator.new(60, 44)
	generator.generate(ground, objects)

	_check(generator.road_centers.size() >= 2, "Es entstehen mehrere Strassen")
	_check(generator.road_tiles.size() > 100, "Die Fahrbahnen sind gefuellt")
	_check(generator.walkable.size() > 500, "Es gibt genug begehbare Flaeche")

	# Rund um das Zuhause darf nichts stehen.
	var home := generator.home_cell
	var blocked_near_home := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if objects.get_cell_atlas_coords(home + Vector2i(dx, dy)) != Vector2i(-1, -1):
				blocked_near_home += 1
	_check(blocked_near_home == 0, "Die Heimzone bleibt frei von Gebaeuden")

	# Es muss wirklich gebaut worden sein.
	var building_tiles := 0
	for y in 44:
		for x in 60:
			if objects.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(-1, -1):
				building_tiles += 1
	_check(building_tiles > 100, "Es stehen Haeuser und Baeume auf der Karte")

	var cell := generator.random_walkable()
	_check(generator.walkable.has(cell), "Zufaellige Freiflaeche ist tatsaechlich begehbar")

	ground.queue_free()
	objects.queue_free()
