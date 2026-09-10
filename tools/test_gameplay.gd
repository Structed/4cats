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

const INDICATOR_VIEWPORTS: Array[Vector2] = [Vector2(640, 360), Vector2(880, 360)]
const INDICATOR_DIRECTIONS: Array[Vector2] = [
	Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
	Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
]

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
	_test_home_indicator()
	_test_car_directions()
	_test_carrying()
	_test_recovery_timing()
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

func _test_home_indicator() -> void:
	print("--- Wegweiser zum Zuhause ---")
	var drawn_radius := 0.0
	for point in HomeIndicator.ARROW_POINTS:
		drawn_radius = maxf(drawn_radius, point.length())
	_check(drawn_radius + HomeIndicator.OUTLINE_WIDTH * 0.5 <= HomeIndicator.MARKER_RADIUS,
		"Der Sicherheitsradius umfasst den gesamten Pfeil samt Kontur")

	for viewport_size in INDICATOR_VIEWPORTS:
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var bounds := viewport_rect.grow(-HomeIndicator.MARKER_RADIUS - HomeIndicator.EDGE_GAP)
		var center := viewport_rect.get_center()
		for direction in INDICATOR_DIRECTIONS:
			var target := center + direction * 2000.0
			var position := HomeIndicator.calculate_position(center, target, viewport_rect)
			var to_marker := position - center
			_check(position.is_finite() and _indicator_fits(position, viewport_rect),
				"Pfeil %s bleibt bei %s vollstaendig im Bild" % [direction, viewport_size])
			_check(_indicator_on_edge(position, bounds)
				and to_marker.dot(direction) > 0.0
				and absf(to_marker.normalized().cross(direction.normalized())) < 0.001,
				"Pfeil %s liegt auf dem richtigen Richtungsstrahl am Rand" % direction)

		var visible_position := HomeIndicator.calculate_position(center + Vector2(50, 20),
			center, viewport_rect)
		_check(visible_position.is_equal_approx(center + HomeIndicator.HOME_OFFSET),
			"Sichtbares Zuhause wird direkt darueber markiert")
		var arrived_position := HomeIndicator.calculate_position(center, center, viewport_rect)
		_check(arrived_position.is_finite() and arrived_position.is_equal_approx(visible_position),
			"Auch direkt in der Heimzone bleibt die Markierung stabil")

		for corner in [Vector2.ZERO, viewport_size - Vector2.ONE]:
			var position := HomeIndicator.calculate_position(center, corner, viewport_rect)
			_check(position.is_finite() and _indicator_fits(position, viewport_rect),
				"Sichtbares Zuhause am Bildrand schneidet den Pfeil nicht ab")

		var player_position := Vector2(80, 260)
		var offscreen_target := Vector2(1800, -900)
		var edge_position := HomeIndicator.calculate_position(player_position, offscreen_target,
			viewport_rect)
		_check(_indicator_on_edge(edge_position, bounds)
			and absf((edge_position - player_position).normalized().cross(
				(offscreen_target - player_position).normalized())) < 0.001,
			"Eine nicht zentrierte Spielfigur liefert den richtigen Richtungsstrahl")

		var obstacles: Array[Rect2] = [
			Rect2(0, center.y - 45, 100, 90),
			Rect2(0, center.y + 25, 140, 95),
		]
		var target := center + Vector2.LEFT * 2000.0
		var avoided := HomeIndicator.calculate_position(center, target, viewport_rect, obstacles)
		_check(_indicator_fits(avoided, viewport_rect) and _indicator_on_edge(avoided, bounds),
			"Ausweichen vor ueberlappender Touch-UI behaelt die Randposition")
		for obstacle in obstacles:
			_check(not _indicator_rect(avoided).intersects(obstacle.grow(HomeIndicator.UI_GAP - 0.01)),
				"Zwischen Pfeil und Bedienelement bleibt Platz")

		var near_home_obstacles: Array[Rect2] = [
			Rect2(center - Vector2(50, 60), Vector2(100, 50)),
			Rect2(center - Vector2(10, 50), Vector2(90, 80)),
		]
		var near_home := HomeIndicator.calculate_position(center + Vector2(50, 0),
			center, viewport_rect, near_home_obstacles)
		_check(_indicator_fits(near_home, viewport_rect) and near_home.distance_to(center) < 100.0,
			"Bei sichtbarem Zuhause weicht der Pfeil nur in dessen Naehe aus")
		for obstacle in near_home_obstacles:
			_check(not _indicator_rect(near_home).intersects(obstacle.grow(HomeIndicator.UI_GAP - 0.01)),
				"Auch nahe am Zuhause bleiben Beschriftungen frei")


func _indicator_rect(position: Vector2) -> Rect2:
	var radius := Vector2.ONE * HomeIndicator.MARKER_RADIUS
	return Rect2(position - radius, radius * 2.0)


func _indicator_fits(position: Vector2, viewport_rect: Rect2) -> bool:
	return viewport_rect.encloses(_indicator_rect(position))


func _indicator_on_edge(position: Vector2, bounds: Rect2) -> bool:
	return (is_equal_approx(position.x, bounds.position.x)
		or is_equal_approx(position.x, bounds.end.x)
		or is_equal_approx(position.y, bounds.position.y)
		or is_equal_approx(position.y, bounds.end.y))


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

	for need_key: String in cat.needs():
		cat.set(need_key, CatData.RECOVERY_THRESHOLD - 0.1)
		_check(not cat.all_needs_met(), "%s knapp unter der Schwelle verhindert Genesung" % need_key)
		_check(cat.wellbeing() > CatData.RECOVERY_THRESHOLD,
			"Ein hoher Durchschnitt ersetzt keinen ausreichenden Einzelwert")
		cat.set(need_key, CatData.RECOVERY_THRESHOLD)
		_check(cat.all_needs_met(), "%s genau auf der Schwelle reicht aus" % need_key)
		cat.set(need_key, CatData.RECOVERY_THRESHOLD + 0.1)
		_check(cat.all_needs_met(), "%s ueber der Schwelle reicht aus" % need_key)
		cat.set(need_key, CatData.NEED_MAX)

	cat.hunger = CatData.RECOVERY_THRESHOLD - 0.1
	cat.thirst = CatData.RECOVERY_THRESHOLD - 0.1
	_check(not cat.all_needs_met(), "Mehrere fehlende Beduerfnisse verhindern Genesung")
	for need_key: String in cat.needs():
		cat.set(need_key, CatData.RECOVERY_THRESHOLD)
	_check(cat.all_needs_met(), "Alle vier Werte genau auf der Schwelle reichen aus")


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


func _test_recovery_timing() -> void:
	print("--- Genesungsdauer und Rueckschritte ---")
	for level in GameState.upgrade_max_level("vet") + 1:
		GameState.reset()
		GameState.add_coins(10000)
		for i in level:
			GameState.purchase_upgrade("vet")

		var cat := CatData.create_random()
		for need_key: String in cat.needs():
			cat.set(need_key, CatData.NEED_MAX)
		GameState.pick_up_cat(cat)
		GameState.deliver_carried_cats()
		var coins_before := GameState.coins
		var duration := CatData.RECOVERY_SECONDS * pow(0.8, float(level))
		_check(is_equal_approx(GameState.recovery_seconds_remaining(cat), duration),
			"Restzeit entspricht der Genesungsdauer auf Tierarzt-Stufe %d" % level)

		GameState._tick_needs(2.0)
		_check(is_equal_approx(GameState.recovery_seconds_remaining(cat), duration - 2.0),
			"Zwei echte Sekunden verringern die Restzeit um zwei Sekunden auf Stufe %d" % level)
		var remaining := GameState.recovery_seconds_remaining(cat)
		GameState._tick_needs(remaining - 0.01)
		_check(cat.state == CatData.State.AT_HOME,
			"Die Katze bleibt bis zum Ende der Restzeit zu Hause auf Stufe %d" % level)
		_check(is_equal_approx(GameState.recovery_seconds_remaining(cat), 0.01),
			"Auch kurz vor Abschluss bleibt die Restzeit positiv auf Stufe %d" % level)

		GameState._tick_needs(0.02)
		_check(cat.state == CatData.State.ADOPTED and GameState.home_cats.is_empty(),
			"Vermittlung erfolgt automatisch nach der angezeigten Dauer auf Stufe %d" % level)
		_check(GameState.coins == coins_before + GameState.ADOPTION_REWARD,
			"Die unveraenderte Vermittlungsbelohnung wird ausgezahlt auf Stufe %d" % level)
		_check(is_zero_approx(GameState.recovery_seconds_remaining(cat)),
			"Ueberschrittener Genesungsfortschritt erzeugt keine negative Restzeit")

	GameState.reset()
	var cat := CatData.create_random()
	for need_key: String in cat.needs():
		cat.set(need_key, CatData.NEED_MAX)
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	GameState._tick_needs(5.0)
	cat.health = CatData.RECOVERY_THRESHOLD - 0.1
	GameState._tick_needs(1.0)
	_check(is_equal_approx(cat.recovery_timer, 3.0),
		"Fehlende Pflege baut pro Sekunde zwei Fortschrittssekunden ab")
	cat.health = CatData.NEED_MAX
	GameState._tick_needs(1.0)
	_check(is_equal_approx(cat.recovery_timer, 4.0),
		"Nach ausreichender Pflege geht es mit dem erhaltenen Fortschritt weiter")
	cat.health = CatData.RECOVERY_THRESHOLD - 0.1
	GameState._tick_needs(10.0)
	_check(is_zero_approx(cat.recovery_timer), "Rueckschritte sind bei null begrenzt")
	_check(cat.state == CatData.State.AT_HOME, "Ohne ausreichende Pflege erfolgt keine Vermittlung")


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
