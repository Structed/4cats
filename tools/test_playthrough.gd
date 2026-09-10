## Spieltest: laesst den Spieler wirklich eine Katze einfangen.
##
## Aufruf:
##   godot --headless --path . -- --playtest
##
## Die Konstanten-Tests in test_gameplay.gd pruefen nur Verhaeltnisse. Hier
## laeuft die echte Szene mit echter Physik: Der Spieler geht auf eine Katze zu,
## das Vertrauen muss wachsen und die Katze am Ende im Korb landen. Genau das
## war vorher unmoeglich, ohne dass ein einziger Test angeschlagen haette.
extends Node

## Nach so vielen Sekunden gilt ein Versuch als gescheitert.
const TIMEOUT := 25.0

## Physikschritte pro Sekunde -- entspricht der Projekteinstellung.
const TICKS_PER_SECOND := 60.0

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [ok]    %s" % description)
	else:
		print("  [FEHLER] %s" % description)
		_failures.append(description)


func _run() -> void:
	print("--- Spieltest: Katze einfangen ---")

	var scene: PackedScene = load("res://scenes/rescue/rescue_level.tscn")
	var level: Node2D = scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player: Player = level.get_node("Player")
	var cats := _find_cats(level)
	_check(not cats.is_empty(), "Im Level sind Katzen vorhanden (%d)" % cats.size())

	if cats.is_empty():
		_finish(level)
		return

	var target := _nearest_cat(level, player)
	var start_distance := player.global_position.distance_to(target.global_position)
	print("  Ziel: %s, Entfernung %.0f px, Scheu %.2f"
		% [target.data.cat_name, start_distance, target.data.shyness])

	var caught := await _walk_to_and_catch(level, player, target)

	_check(caught, "Der Spieler kann eine Katze einfangen")
	_check(GameState.carried_cats.size() == 1, "Die Katze liegt danach im Tragekorb")

	# Einen Frame verstreichen lassen, damit die aufgehobene Katze wirklich
	# aus dem Baum verschwunden ist.
	await get_tree().process_frame

	await _test_sprint_scares(level, player)

	level.queue_free()
	await get_tree().process_frame
	var home_test_script: GDScript = load("res://tools/test_home_playthrough.gd")
	var home_test: Node = home_test_script.new()
	add_child(home_test)
	var home_failures: PackedStringArray = await home_test.run()
	_failures.append_array(home_failures)
	home_test.queue_free()
	await get_tree().process_frame
	_finish(null)


## Baut ein Gitter fuer die Wegfindung: jede Kachel mit einem Haus oder Baum
## darauf gilt als versperrt. Ohne echte Wegfindung bleibt der Spieler an
## Haeuserbloecken haengen und erreicht die Katze nie -- genau das liess den
## Spieltest in der CI sporadisch scheitern.
func _build_pathfinder(level: Node2D) -> AStarGrid2D:
	var generator: LevelGenerator = level.get("_generator")
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, generator.width, generator.height)
	astar.cell_size = Vector2(LevelGenerator.TILE_SIZE, LevelGenerator.TILE_SIZE)
	# Keine Diagonalen durch Hausecken -- sonst bleibt der Spieler an der
	# Ecke haengen, obwohl die Wegfindung dort einen Weg sieht.
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for y in generator.height:
		for x in generator.width:
			var cell := Vector2i(x, y)
			if generator.is_blocked(cell):
				astar.set_point_solid(cell)
	return astar


## Liefert die Wegpunkte von `from` nach `to` als Weltkoordinaten, oder ein
## leeres Array, wenn keine Kachel dort begehbar ist.
func _find_path(astar: AStarGrid2D, from: Vector2, to: Vector2) -> PackedVector2Array:
	var from_cell := LevelGenerator.world_to_cell(from)
	var to_cell := LevelGenerator.world_to_cell(to)
	if astar.is_point_solid(from_cell) or astar.is_point_solid(to_cell):
		return PackedVector2Array()
	var path := astar.get_id_path(from_cell, to_cell)
	var points := PackedVector2Array()
	for cell in path:
		points.append(LevelGenerator.cell_to_world(cell))
	return points


## Geht auf die Katze zu, wartet auf Vertrauen und hebt sie auf. Die
## Wegfindung umgeht dabei Haeuser und Baeume, statt blind auf die Katze
## zuzulaufen.
func _walk_to_and_catch(level: Node2D, player: Player, target: Cat) -> bool:
	var astar := _build_pathfinder(level)
	var elapsed := 0.0
	var max_trust := 0.0
	var closest := INF
	var reported := false
	var path: PackedVector2Array = []
	var path_age := 0.0

	while elapsed < TIMEOUT:
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			return true

		var to_cat := target.global_position - player.global_position
		var distance := to_cat.length()
		closest = minf(closest, distance)

		if distance <= Cat.TRUST_RADIUS * 0.55:
			# Nah genug -- stehen bleiben und Vertrauen aufbauen lassen.
			_release_movement()
			path.clear()
		else:
			# Weg regelmaessig neu berechnen, weil die Katze selbst wandert.
			path_age += 1.0 / TICKS_PER_SECOND
			if path.is_empty() or path_age > 0.5:
				path = _find_path(astar, player.global_position, target.global_position)
				path_age = 0.0

			while path.size() > 1 and player.global_position.distance_to(path[0]) < 6.0:
				path.remove_at(0)

			if path.is_empty():
				# Keine Wegfindung moeglich (z. B. direkt am Rand) -- direkt zusteuern.
				_press_towards(to_cat)
			else:
				_press_towards(path[0] - player.global_position)

		await get_tree().physics_frame
		elapsed += 1.0 / TICKS_PER_SECOND

		max_trust = maxf(max_trust, target.trust)
		if target.is_catchable():
			if not reported:
				print("  Vertrauen voll nach %.1f s" % elapsed)
				reported = true
			_release_movement()
			if target.pick_up():
				return true

	_release_movement()
	printerr("  Zeitueberschreitung nach %.0f s" % TIMEOUT)
	printerr("  naechste Annaeherung %.0f px (noetig: %.0f), hoechstes Vertrauen %.2f, Zustand %d"
		% [closest, Cat.TRUST_RADIUS, max_trust, target.state])
	printerr("  Hunde in der Naehe: %d" % _dogs_near(target, Dog.SCARE_RADIUS * 1.5))
	return false


## Zaehlt Hunde im Umkreis -- ein danebenstehender Hund haelt eine Katze
## dauerhaft in Panik und macht sie damit unfangbar.
func _dogs_near(cat: Cat, radius: float) -> int:
	var count := 0
	for node in cat.get_tree().get_nodes_in_group("dogs"):
		var dog := node as Node2D
		if dog != null and dog.global_position.distance_to(cat.global_position) < radius:
			count += 1
	return count


func _wait_seconds(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().physics_frame
		waited += 1.0 / TICKS_PER_SECOND


## Gegenprobe: Sprinten muss eine Katze tatsaechlich verscheuchen.
func _test_sprint_scares(level: Node2D, player: Player) -> void:
	print("--- Gegenprobe: Rennen verschreckt ---")
	var target := _nearest_cat(level, player)
	if target == null:
		_check(false, "Fuer die Gegenprobe ist noch eine Katze da")
		return

	# Hunde raus aus dem Spiel: sie sollen hier nicht querschiessen und die
	# Katze zufaellig ein zweites Mal aufschrecken, waehrend wir auf die
	# Beruhigung warten.
	for node in level.get_tree().get_nodes_in_group("dogs"):
		node.queue_free()
	await get_tree().process_frame

	# Direkt neben die Katze setzen und lossprinten -- auf einer begehbaren
	# Kachel, sonst kommt der Spieler nie auf Sprinttempo.
	var generator: LevelGenerator = level.get("_generator")
	player.global_position = _clear_spot_near(generator, target.global_position)
	target.trust = 0.9
	await get_tree().physics_frame

	Input.action_press("sprint")
	var elapsed := 0.0
	var fled := false
	while elapsed < 2.0:
		_press_towards(target.global_position - player.global_position)
		await get_tree().physics_frame
		elapsed += 1.0 / TICKS_PER_SECOND
		if target.state == Cat.State.FLEE:
			fled = true
			break
	_release_movement()
	Input.action_release("sprint")

	_check(fled, "Sprinten schreckt eine Katze auf")
	_check(target.trust > 0.0,
		"Dabei geht nicht alles Vertrauen verloren (%.2f uebrig)" % target.trust)

	# Und sie muss sich danach wieder beruhigen.
	var calm_after := 0.0
	while calm_after < 3.0 and target.state == Cat.State.FLEE:
		await get_tree().physics_frame
		calm_after += 1.0 / TICKS_PER_SECOND
	_check(target.state != Cat.State.FLEE,
		"Die Katze beruhigt sich nach %.1f s wieder" % calm_after)


## Sucht rund um `origin` eine unversperrte Stelle im Abstand `TRUST_RADIUS * 0.5`
## -- die direkte Position kann auf einer Hauskachel liegen, dann kommt der
## Spieler dort nie auf Sprinttempo.
func _clear_spot_near(generator: LevelGenerator, origin: Vector2) -> Vector2:
	var offset := Cat.TRUST_RADIUS * 0.5
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var candidate := origin + Vector2(offset, 0.0).rotated(angle)
		if generator == null or not generator.is_blocked(LevelGenerator.world_to_cell(candidate)):
			return candidate
	return origin + Vector2(offset, 0.0)


func _press_towards(direction: Vector2) -> void:
	if direction.is_zero_approx():
		_release_movement()
		return
	var d := direction.normalized()
	_set_axis("move_right", maxf(d.x, 0.0))
	_set_axis("move_left", maxf(-d.x, 0.0))
	_set_axis("move_down", maxf(d.y, 0.0))
	_set_axis("move_up", maxf(-d.y, 0.0))


func _set_axis(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _find_cats(level: Node) -> Array[Cat]:
	var found: Array[Cat] = []
	for node in level.get_tree().get_nodes_in_group("cats"):
		var cat := node as Cat
		# queue_free() entfernt den Knoten erst am Frame-Ende -- bis dahin ist
		# er noch gueltig und steht weiter in der Gruppe.
		if cat != null and is_instance_valid(cat) and not cat.is_queued_for_deletion():
			found.append(cat)
	return found


## Naechstgelegene Katze zum Spieler, oder null.
func _nearest_cat(level: Node, player: Player) -> Cat:
	var cats := _find_cats(level)
	if cats.is_empty():
		return null
	var nearest: Cat = cats[0]
	for cat in cats:
		if player.global_position.distance_to(cat.global_position) \
				< player.global_position.distance_to(nearest.global_position):
			nearest = cat
	return nearest


func _finish(level: Node) -> void:
	if is_instance_valid(level):
		level.queue_free()
	print("")
	if _failures.is_empty():
		print("Spieltest bestanden.")
		get_tree().quit.call_deferred(0)
	else:
		for failure in _failures:
			printerr("FEHLGESCHLAGEN: %s" % failure)
		printerr("%d Pruefung(en) fehlgeschlagen." % _failures.size())
		get_tree().quit.call_deferred(1)
