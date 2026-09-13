## Echter Einkaufsweg mit InputMap, Spielerform und den normalen Thekenknoepfen.
extends Node

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]
const FOCUS_ACTIONS: Array[StringName] = [
	&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right",
]
const RESCUE_SCENE := "res://scenes/rescue/rescue_level.tscn"
const HOME_SCENE := "res://scenes/home/home_scene.tscn"

var _failures: PackedStringArray = []
var _saved_state: Dictionary = {}
var _saved_settings: Dictionary = {}
var _saved_file: PackedByteArray = []
var _had_save: bool = false
var _saved_active: bool = false
var _saved_paused: bool = false
var _scene: Node2D


func run() -> PackedStringArray:
	print("--- Spieltest: Futterladen und Heimweg ---")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_failures.clear()
	_saved_state = GameState.to_dict().duplicate(true)
	_saved_settings = SaveManager.load_settings().duplicate(true)
	_had_save = SaveManager.has_save()
	if _had_save:
		_saved_file = FileAccess.get_file_as_bytes(SaveManager.save_path)
	_saved_active = GameState.simulation_active
	_saved_paused = get_tree().paused
	get_tree().paused = false
	_release()
	GameState.reset("challenging")
	GameState.add_coins(80)
	var home_cat := CatData.create_random()
	home_cat.cat_name = "Versorgungstest"
	home_cat.hunger = 15
	home_cat.thirst = 15
	home_cat.health = 100
	GameState.pick_up_cat(home_cat)
	GameState.deliver_carried_cats()
	_check(GameState.order_food().is_empty(), "Eine bestehende Lieferung läuft während des Einkaufs weiter.")
	var order: SupplyOrder = GameState.supplies.orders[0]
	var before_walk: float = order.remaining
	_scene = await _load_scene(RESCUE_SCENE)
	var level: Node2D = _scene
	var generator: LevelGenerator = level.get("_generator")
	var player: Player = level.get_node("Player")
	var hud: Control = level.get_node("UI/HUD")
	var touch: CanvasLayer = level.get_node("TouchControls")
	var objects: TileMapLayer = level.get_node("Objects")
	var level_id: int = level.get_instance_id()
	var generator_id: int = generator.get_instance_id()
	var map_cells: Array[Vector2i] = objects.get_used_cells()
	var entity_ids: Array[int] = []
	for actor in level.get_node("Entities").get_children():
		entity_ids.append(actor.get_instance_id())
		# Die Teststrecke bleibt echte Physik; nur zufaellige Tiere/Autos wandern nicht.
		actor.set_physics_process(false)
	touch.call("set_forced", true)
	_check(not bool(hud.call("open_shop")), "Vom Spielerstart aus ist kein Fernkauf möglich.")
	await _tap(&"interact")
	_check(not bool(hud.call("is_shop_open")), "Eine Aktion fern der Theke öffnet keinen Laden.")
	if not await _walk_rescue(level, generator.shop_entry + Vector2i.DOWN):
		_check(false, "Der Spieler erreicht den Laden über den reservierten Heimweg.")
		return await _finish()
	_check(order.remaining < before_walk, "Aktive Laufzeit draußen treibt die Lieferung voran.")
	_check_world_collisions(level, generator)
	await _tap(&"interact")
	_check(not bool(hud.call("is_shop_open")), "Am Eingang muss man erst tatsächlich bis zur Theke gehen.")
	if not await _walk_rescue(level, generator.shop_cell):
		_check(false, "Der Spieler durchquert den Eingang und erreicht die Theke mit seiner echten Kollisionsform.")
		return await _finish()
	_check(true, "Der Spieler betritt den Laden ohne Szenenwechsel.")
	Input.action_press("move_up")
	await _frames(45)
	Input.action_release("move_up")
	await _frames(2)
	_check(not generator.is_blocked(LevelGenerator.world_to_cell(player.position))
		and player.position.y >= generator.shop_counter.end.y * LevelGenerator.TILE_SIZE,
		"Die sichtbare Theke hält die echte Spielerphysik auf.")
	if not await _walk_rescue(level, generator.shop_cell):
		_check(false, "Vor der Theke kann man weiterhin frei gehen.")
		return await _finish()

	var basket_cat := CatData.create_random()
	basket_cat.cat_name = "Korbtest"
	GameState.pick_up_cat(basket_cat)
	var nearby: Cat = _counter_cat(level, generator.shop_cell)
	await _frames(2)
	_check(nearby != null and player.cats_in_reach().has(nearby),
		"Die Gegenprobe enthält eine aufhebbare Katze direkt neben der Theke.")
	var coins_before: int = GameState.coins
	var stock_before: int = GameState.supplies.food_stock
	var orders_before: int = GameState.supplies.orders.size()
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _tap(&"interact")
	_check(bool(hud.call("is_shop_open")) and get_tree().paused,
		"Die normale Tastaturaktion öffnet an der Theke den pausierten Kaufdialog.")
	if not bool(hud.call("is_shop_open")):
		return await _finish()
	await _check_modal(level, home_cat, order)
	_check(GameState.carried_cats.size() == 1 and GameState.carried_cats[0] == basket_cat
		and is_instance_valid(nearby) and not nearby.is_queued_for_deletion(),
		"Thekeninteraktion nimmt nicht gleichzeitig eine Katze auf.")
	var buy: Button = hud.get_node("ShopPanel/Box/Scroll/SupplyPanel/BuyFoodButton")
	buy.grab_focus()
	await _tap(&"ui_accept")
	_check(GameState.supplies.cargo_kind == "package"
		and GameState.supplies.cargo_amount == SupplyCatalog.PACKAGE_UNITS,
		"Der echte Thekenknopf legt ein Futterpaket auf den Haushaltsarm.")
	_check(GameState.coins == coins_before - GameState.food_price()
		and GameState.supplies.food_stock == stock_before,
		"Der Kauf bucht genau den sichtbaren Preis, aber noch keinen Schrankvorrat.")
	await _click(buy)
	_check(GameState.coins == coins_before - GameState.food_price()
		and GameState.supplies.orders.size() == orders_before,
		"Ein weiterer Klick mit vollem Arm erzeugt weder Doppelbuchung noch Bestellung.")
	_check(GameState.carried_cats.size() == 1 and GameState.carried_cats[0] == basket_cat,
		"Der Einkaufsarm bleibt vom Rettungskorb getrennt.")
	await _tap(&"pause")
	_check(not get_tree().paused and not bool(hud.call("is_shop_open"))
		and player.is_physics_processing() and bool(touch.call("is_touch_visible")),
		"Esc schließt den Laden und gibt Bewegung und Touch wieder frei.")
	_check(_released(), "Beim Schließen bleiben keine Bewegungs-, Sprint- oder Interaktionsaktionen hängen.")
	await _screen_tap(touch.get_node("Root/ActionButton"))
	_check(bool(hud.call("is_shop_open")) and get_tree().paused,
		"Der echte Touch-Kontextknopf öffnet denselben Thekendialog.")
	if not bool(hud.call("is_shop_open")):
		return await _finish()
	await _click(hud.get_node("ShopPanel/Box/CloseShopButton"))
	_check(not get_tree().paused and not bool(hud.call("is_shop_open")),
		"Der sichtbare Schließen-Knopf beendet auch den Touch-Einkauf.")
	_check(level.get_instance_id() == level_id and generator.get_instance_id() == generator_id
		and objects.get_used_cells() == map_cells and _same_entities(level, entity_ids),
		"Tastatur- und Touch-Einkauf erzeugen weder Viertel noch Rettungstiere neu.")
	var cargo: Node2D = player.get_node("SupplyCargo")
	_check(cargo.is_visible_in_tree(), "Das getragene Paket hat eine sichtbare Ladungsanzeige.")

	if not await _walk_rescue(level, generator.home_cell + Vector2i(0, -3)):
		_check(false, "Mit Paket und Rettungskorb ist der Heimweg begehbar.")
		return await _finish()
	_check(GameState.carried_cats.size() == 1 and GameState.supplies.cargo_kind == "package",
		"Bis vor die Heimzone bleiben Paket und Rettungskorb erhalten.")
	if not await _walk_rescue(level, generator.home_cell):
		_check(false, "Der Spieler erreicht die unveränderte Heimzone.")
		return await _finish()
	_check(GameState.carried_cats.is_empty() and GameState.home_cats.has(basket_cat),
		"Die Heimzone liefert die Rettungskatze wie bisher ab.")
	_check(GameState.supplies.cargo_kind == "package"
		and GameState.supplies.food_stock == stock_before,
		"Das Betreten der Heimzone räumt das Futterpaket nicht automatisch ein.")
	_check(level.get_instance_id() == level_id and level.get("_generator") == generator,
		"Auch beim Verlassen des Ladens und beim Heimweg bleibt dieselbe Viertelinstanz erhalten.")

	level.call("prepare_to_leave")
	level.queue_free()
	await get_tree().process_frame
	_scene = await _load_scene(HOME_SCENE)
	_check(GameState.supplies.cargo_kind == "package"
		and GameState.supplies.food_stock == stock_before,
		"Der Eintritt ins Katzenhaus erhält das Paket ohne automatische Vorratsgutschrift.")
	var pantry: HomeItemData
	for item in GameState.home.items:
		if item.kind == "pantry" and item.placed:
			pantry = item
			break
	_check(pantry != null, "Das Haus besitzt einen erreichbaren Vorratsschrank.")
	if pantry != null:
		var simulation: HomeSimulation = _scene.get("simulation")
		var home_player: Player = _scene.get_node("Player")
		var route: PackedVector2Array = simulation.layout.path(home_player.position, pantry.port())
		if await _walk_route(home_player, route, HomeCatalog.world(pantry.port())):
			await _tap(&"interact")
			_check(GameState.supplies.cargo_kind.is_empty()
				and GameState.supplies.food_stock == stock_before + SupplyCatalog.PACKAGE_UNITS,
				"Erst die echte Schrankinteraktion lagert das heimgebrachte Paket ein.")
		else:
			_check(false, "Der Spieler kann mit dem gekauften Paket zum Vorratsschrank gehen.")
	await _test_modal_teardown()
	return await _finish()


func _load_scene(path: String) -> Node2D:
	var packed: PackedScene = load(path)
	var scene: Node2D = packed.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await _frames(2)
	return scene


func _check_world_collisions(level: Node2D, generator: LevelGenerator) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.collide_with_areas = false
	var mismatches := 0
	for y in range(generator.shop_area.position.y, generator.shop_area.end.y):
		for x in range(generator.shop_area.position.x, generator.shop_area.end.x):
			var cell := Vector2i(x, y)
			query.position = LevelGenerator.cell_to_world(cell)
			var hits: Array[Dictionary] = level.get_world_2d().direct_space_state.intersect_point(query)
			if (not hits.is_empty()) != generator.is_blocked(cell):
				mismatches += 1
	_check(mismatches == 0, "Die echten Physikkörper entsprechen an allen Ladenkacheln der Generator-Wegfindung.")


func _counter_cat(level: Node2D, cell: Vector2i) -> Cat:
	for actor in level.get_node("Entities").get_children():
		if actor is Cat:
			var cat := actor as Cat
			cat.position = LevelGenerator.cell_to_world(cell) + Vector2(12, 0)
			cat.velocity = Vector2.ZERO
			cat.trust = Cat.TRUST_THRESHOLD
			return cat
	return null


func _check_modal(level: Node2D, cat: CatData, order: SupplyOrder) -> void:
	var hud: Control = level.get_node("UI/HUD")
	var player: Player = level.get_node("Player")
	var touch: CanvasLayer = level.get_node("TouchControls")
	var panel: Control = hud.get_node("ShopPanel")
	var home_button: Button = hud.get_node("%HomeButton")
	_check(not bool(touch.call("is_touch_visible")) and not player.is_physics_processing()
		and _released(), "Der Kaufdialog verriegelt Touch, Spielerphysik und gehaltene Aktionen.")
	var alerts: CareAlerts = hud.get_node("CareAlerts")
	var warning: Label = alerts.get("_warning")
	_check(alerts.is_visible_in_tree() and warning.visible and not warning.text.is_empty()
		and not alerts.get_global_rect().intersects(panel.get_global_rect()),
		"Dauerhafte Pflegewarnungen bleiben neben dem Einkauf sichtbar.")
	var position_before := player.position
	var hunger_before: float = cat.hunger
	var delivery_before: float = order.remaining
	Input.action_press("move_left")
	Input.action_press("sprint")
	await _frames(30)
	_check(player.position.is_equal_approx(position_before) and cat.hunger == hunger_before
		and order.remaining == delivery_before, "Einkaufen pausiert Bewegung, Hauspflege und Lieferzeit gemeinsam.")
	_release()
	await _click(home_button)
	_check(not bool(SceneRouter.get("_busy")) and bool(hud.call("is_shop_open"))
		and home_button.disabled and home_button.focus_mode == Control.FOCUS_NONE,
		"Abdunklung und Fokusverriegelung verhindern Hintergrundklicks und Szenenwechsel.")
	var focus_inside := true
	for action in FOCUS_ACTIONS:
		await _tap(action)
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus == null or not panel.is_ancestor_of(focus):
			focus_inside = false
	_check(focus_inside, "Tab und alle Fokus-Richtungen bleiben im Kaufdialog.")


func _same_entities(level: Node2D, ids: Array[int]) -> bool:
	var actors: Array[Node] = level.get_node("Entities").get_children()
	if actors.size() != ids.size():
		return false
	for actor in actors:
		if not ids.has(actor.get_instance_id()):
			return false
	return true


func _walk_rescue(level: Node2D, target: Vector2i) -> bool:
	var generator: LevelGenerator = level.get("_generator")
	var player: Player = level.get_node("Player")
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, generator.width, generator.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in generator.height:
		for x in generator.width:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, generator.is_blocked(cell))
	var cells: Array[Vector2i] = astar.get_id_path(LevelGenerator.world_to_cell(player.position), target)
	var route: PackedVector2Array = []
	for cell in cells:
		route.append(LevelGenerator.cell_to_world(cell))
	return await _walk_route(player, route, LevelGenerator.cell_to_world(target))


func _walk_route(player: Player, route: PackedVector2Array, target: Vector2) -> bool:
	var deadline := Engine.get_physics_frames() + ceili(30.0 * Engine.physics_ticks_per_second)
	if route.is_empty():
		return false
	while Engine.get_physics_frames() < deadline and not route.is_empty():
		while not route.is_empty() and player.position.distance_to(route[0]) < 2.0:
			route.remove_at(0)
		if route.is_empty():
			break
		var direction: Vector2 = route[0] - player.position
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
		await get_tree().physics_frame
	_release()
	await _frames(2)
	var arrived: bool = player.position.distance_to(target) < 5.0
	if not arrived:
		printerr("Einkaufsweg: Position ", player.position, ", Ziel ", target, ", Restweg ", route)
	return arrived


func _tap(action: StringName) -> void:
	var key: InputEventKey
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			key = event as InputEventKey
			break
	if key == null:
		_check(false, "Die InputMap besitzt keine Tastaturbindung für %s." % action)
		return
	for pressed: bool in [true, false]:
		var event: InputEventKey = key.duplicate() as InputEventKey
		event.pressed = pressed
		event.echo = false
		Input.parse_input_event(event)
		await _frames(2)


func _click(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(2)


func _screen_tap(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _test_modal_teardown() -> void:
	_scene.queue_free()
	await get_tree().process_frame
	_scene = await _load_scene(RESCUE_SCENE)
	var generator: LevelGenerator = _scene.get("_generator")
	var player: Player = _scene.get_node("Player")
	var hud: Control = _scene.get_node("UI/HUD")
	# Nur die Aufraeum-Gegenprobe startet direkt an der Theke.
	player.position = LevelGenerator.cell_to_world(generator.shop_cell)
	player.velocity = Vector2.ZERO
	await _frames(2)
	await _tap(&"interact")
	_check(bool(hud.call("is_shop_open")), "Die Aufräumprobe startet mit offenem Kaufdialog.")
	_scene.call("prepare_to_leave")
	_check(not get_tree().paused and not bool(hud.call("is_shop_open")) and _released(),
		"Ein Szenenwechsel beendet Kaufmodal, globale Pause und gehaltene Aktionen.")
	_scene.queue_free()
	await get_tree().process_frame
	_scene = null
	_check(not get_tree().paused, "Auch nach dem Entfernen der Rettungsszene bleibt keine Pause zurück.")


func _release() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	for action: String in ["interact", "sprint", "pause", "ui_accept"]:
		Input.action_release(action)


func _released() -> bool:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			return false
	return not Input.is_action_pressed("interact") and not Input.is_action_pressed("sprint")


func _check(ok: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FEHLER", description])
	if not ok:
		_failures.append(description)


func _finish() -> PackedStringArray:
	_release()
	get_tree().paused = false
	if is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame
	_scene = null
	SaveManager.save_settings(_saved_settings)
	if _had_save:
		var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
		_check(file != null, "Die ursprüngliche Test-Spielstandsdatei kann wiederhergestellt werden.")
		if file != null:
			file.store_buffer(_saved_file)
			file.close()
	else:
		SaveManager.delete_save()
	_check(GameState.from_dict(_saved_state), "Der Einkaufsdurchlauf gibt den vorherigen Test-Spielzustand zurück.")
	GameState.simulation_active = _saved_active
	get_tree().paused = _saved_paused
	return _failures
