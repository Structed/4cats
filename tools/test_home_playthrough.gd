## Echter Hausdurchlauf mit Spielerphysik und der gemeinsamen InputMap.
extends Node

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]
var _failures: PackedStringArray = []

func run() -> PackedStringArray:
	print("--- Spieltest: Katzenhaus ---")
	_release()
	Input.action_release("sprint")
	GameState.reset()
	var cat := CatData.create_random()
	cat.cat_name = "Haus-Testkatze"
	cat.hunger = 20.0
	cat.thirst = 15.0
	cat.cleanliness = 20.0
	cat.health = 35.0
	cat.enrichment = 20.0
	GameState.pick_up_cat(cat)
	var scene: PackedScene = load("res://scenes/home/home_scene.tscn")
	var home: Node2D = scene.instantiate()
	get_tree().root.add_child(home)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = home.get_node("Player")
	var simulation: HomeSimulation = home.get("simulation")
	_check(GameState.carried_cats.is_empty() and GameState.home_cats.size() == 1,
		"Beim Betreten kommt die Katze genau einmal ins Haus")
	for kind in ["food", "water"]:
		var item := GameState.home.item_by_id("starter_" + kind)
		if not await _walk(home, HomeCatalog.world(item.port())):
			_check(false, "Der Spieler erreicht den %s" % kind)
			return await _finish(home)
		await _tap("interact")
		_check(item.stock > 0, "%s wird ueber die Kontextaktion befuellt" % kind)
	var supplied := await _until(func() -> bool:
		return cat.hunger > 80 and cat.thirst > 80 and cat.enrichment > 80, 65.0)
	_check(supplied, "Die Katze laeuft selbst zum Fressen, Trinken und Spielen")
	if not supplied:
		printerr("Hausbeduerfnisse: ", cat.needs())
		return await _finish(home)
	_check(GameState.home.item_by_id("starter_food").stock < HomeCatalog.capacity("food"),
		"Das sichtbare Fressen verbraucht Futter")
	if not await _catch_cat(home, cat.id):
		_check(false, "Die Hauskatze laesst sich mit E aufnehmen")
		return await _finish(home)
	_check(GameState.rescued_total == 1 and GameState.carried_cats.is_empty(),
		"Haus-Tragen benutzt nicht den Rettungskorb")
	for kind in ["wash", "vet"]:
		var item := GameState.home.item_by_id("starter_" + kind)
		if not await _walk(home, HomeCatalog.world(item.port())):
			_check(false, "Die getragene Katze erreicht %s" % kind)
			return await _finish(home)
		await _tap("interact")
		_check(simulation.is_caring(), "%s beginnt durch eine echte Interaktion" % kind)
		await _until(func() -> bool: return not simulation.is_caring(), 5.0)
		var value := cat.cleanliness if kind == "wash" else cat.health
		_check(value > 95.0, "%s versorgt die getragene Katze" % kind)
	await _walk(home, player.position + Vector2(0, 48))
	await _tap("interact")
	_check(simulation.held_cat_id.is_empty(), "Die Katze kann wieder abgesetzt werden")
	var litter := GameState.home.item_by_id("starter_litter")
	var toilet_used := await _until(func() -> bool: return litter.dirt > 0, 50.0)
	_check(toilet_used, "Die Katze benutzt selbst das Katzenklo")
	if toilet_used:
		await _walk(home, HomeCatalog.world(litter.port()))
		await _tap("interact")
		_check(litter.dirt == 0, "Das Katzenklo wird vor Ort gereinigt")
	var adopted := await _until(func() -> bool: return cat.state == CatData.State.ADOPTED, 90.0)
	_check(adopted, "Raeumliche Pflege aller fuenf Beduerfnisse fuehrt zur Adoption")
	if not adopted:
		printerr("Hausbeduerfnisse vor Zeitlimit: ", cat.needs(), " Genesung: ", cat.recovery_timer)
	_check(GameState.adopted_total == 1 and GameState.coins == GameState.ADOPTION_REWARD,
		"Der echte Hausdurchlauf belohnt die Adoption genau einmal")
	return await _finish(home)

func _physics_deadline(seconds: float) -> int:
	# Wie im Rettungstest nur ausgefuehrte Physikschritte zaehlen.
	# Systempausen oder eine stockende Maschine verbrauchen keine Spielzeit.
	return Engine.get_physics_frames() + ceili(seconds * Engine.physics_ticks_per_second)

func _catch_cat(home: Node2D, id: String) -> bool:
	var player: Player = home.get_node("Player")
	var simulation: HomeSimulation = home.get("simulation")
	var deadline := _physics_deadline(35.0)
	while Engine.get_physics_frames() < deadline:
		if simulation.held_cat_id == id:
			_release()
			return true
		var state: HomeCatState = GameState.home.cats[id]
		if player.position.distance_to(state.position) < 20.0 \
				and bool(home.call("_clear_line", state.position)):
			_release()
			await _tap("interact")
		else:
			var route := simulation.layout.path(player.position, HomeCatalog.cell(state.position))
			if route.size() > 1:
				route.remove_at(0)
			_follow_route(player, route)
			await get_tree().physics_frame
	_release()
	return false

func _walk(home: Node2D, target: Vector2) -> bool:
	var player: Player = home.get_node("Player")
	var simulation: HomeSimulation = home.get("simulation")
	var route := simulation.layout.path(player.position, HomeCatalog.cell(target))
	var deadline := _physics_deadline(30.0)
	if route.is_empty():
		printerr("Kein Hausweg von ", player.position, " nach ", target)
		return false
	while Engine.get_physics_frames() < deadline and not route.is_empty():
		route = _follow_route(player, route)
		await get_tree().physics_frame
	_release()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var arrived := player.position.distance_to(HomeCatalog.world(HomeCatalog.cell(target))) < 6.0
	if not arrived:
		printerr("Hausweg nicht erreicht: Position ", player.position, ", Ziel ", target,
			", Restweg ", route, ", Physik aktiv ", player.is_physics_processing(),
			", Pflege aktiv ", simulation.is_caring())
	return arrived

func _follow_route(player: Player, route: PackedVector2Array) -> PackedVector2Array:
	while not route.is_empty() and player.position.distance_to(route[0]) < 3.0:
		route.remove_at(0)
	if route.is_empty():
		_release()
		return route
	var direction := route[0] - player.position
	var action: String
	if absf(direction.x) > absf(direction.y):
		action = "move_right" if direction.x > 0 else "move_left"
	else:
		action = "move_down" if direction.y > 0 else "move_up"
	for candidate in MOVE_ACTIONS:
		if candidate == action:
			Input.action_press(candidate)
		else:
			Input.action_release(candidate)
	return route

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame
	await get_tree().physics_frame

func _until(condition: Callable, seconds: float) -> bool:
	var deadline := _physics_deadline(seconds)
	while Engine.get_physics_frames() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	return bool(condition.call())

func _check(ok: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FEHLER", description])
	if not ok:
		_failures.append(description)

func _release() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	Input.action_release("interact")

func _finish(home: Node2D) -> PackedStringArray:
	_release()
	home.queue_free()
	await get_tree().process_frame
	# Der letzte Spielschritt startet den Adoptionsklang. Den Audiomixer vor
	# dem sofortigen Testende freigeben, statt eine laufende Ogg-Stimme abzubrechen.
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await get_tree().create_timer(0.1).timeout
	return _failures
