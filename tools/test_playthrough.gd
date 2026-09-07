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

	var caught := await _walk_to_and_catch(player, target)

	_check(caught, "Der Spieler kann eine Katze einfangen")
	_check(GameState.carried_cats.size() == 1, "Die Katze liegt danach im Tragekorb")

	# Einen Frame verstreichen lassen, damit die aufgehobene Katze wirklich
	# aus dem Baum verschwunden ist.
	await get_tree().process_frame

	await _test_sprint_scares(level, player)

	_finish(level)


## Geht auf die Katze zu, wartet auf Vertrauen und hebt sie auf.
func _walk_to_and_catch(player: Player, target: Cat) -> bool:
	var elapsed := 0.0
	var max_trust := 0.0
	var closest := INF
	var reported := false
	var stuck_since := 0.0
	var last_position := player.global_position

	while elapsed < TIMEOUT:
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			return true

		var to_cat := target.global_position - player.global_position
		var distance := to_cat.length()
		closest = minf(closest, distance)

		# Gemuetlich hingehen; im Nahbereich stehen bleiben und warten.
		if distance > Cat.TRUST_RADIUS * 0.55:
			_press_towards(to_cat)
		else:
			_release_movement()

		await get_tree().physics_frame
		elapsed += 1.0 / TICKS_PER_SECOND

		# Haengt der Spieler an einer Hauswand fest? Dann seitlich ausweichen.
		if player.global_position.distance_to(last_position) < 0.3 and distance > Cat.TRUST_RADIUS:
			stuck_since += 1.0 / TICKS_PER_SECOND
			if stuck_since > 0.4:
				_press_towards(to_cat.orthogonal())
				await _wait_seconds(0.5)
				stuck_since = 0.0
		else:
			stuck_since = 0.0
		last_position = player.global_position

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

	# Direkt neben die Katze setzen und lossprinten.
	player.global_position = target.global_position + Vector2(Cat.TRUST_RADIUS * 0.5, 0.0)
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
	level.queue_free()
	print("")
	if _failures.is_empty():
		print("Spieltest bestanden.")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FEHLGESCHLAGEN: %s" % failure)
		printerr("%d Pruefung(en) fehlgeschlagen." % _failures.size())
		get_tree().quit(1)
