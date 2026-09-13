## Echter Hausdurchlauf mit Spielerphysik und der gemeinsamen InputMap.
extends Node

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]
var _failures: PackedStringArray = []

func run() -> PackedStringArray:
	print("--- Spieltest: Katzenhaus ---")
	_failures.clear()
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
	for kind: String in ["food", "water"]:
		if not await _refill_from_source(home, kind):
			return await _finish(home)
	var supplied := await _until(func() -> bool:
		return cat.hunger > 80 and cat.thirst > 80 and cat.enrichment > 80, 65.0)
	_check(supplied, "Die Katze laeuft selbst zum Fressen, Trinken und Spielen")
	if not supplied:
		printerr("Hausbeduerfnisse: ", cat.needs())
		return await _finish(home)
	_check(GameState.home.item_by_id("starter_food").stock < HomeCatalog.capacity("food"),
		"Das sichtbare Fressen verbraucht Futter")
	for kind: String in ["food", "water"]:
		if not await _refill_from_source(home, kind):
			return await _finish(home)
	if not await _return_cargo(home):
		return await _finish(home)
	_check(GameState.supplies.cargo_kind.is_empty(),
		"Vor der Hauskatzenaufnahme sind alle Restportionen an ihrer Quelle zurueckgegeben")
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
	if not adopted and cat.all_needs_met() and cat.recovery_timer > 0.0:
		# Vorratswege verschieben den Beginn der Genesung. Nur ihre gemessene Restzeit abwarten.
		var remaining := GameState.recovery_seconds_remaining(cat) + 2.0 / Engine.physics_ticks_per_second
		adopted = await _until(func() -> bool: return cat.state == CatData.State.ADOPTED, remaining)
	_check(adopted, "Raeumliche Pflege aller fuenf Beduerfnisse fuehrt zur Adoption")
	if not adopted:
		printerr("Hausbeduerfnisse vor Zeitlimit: ", cat.needs(), " Genesung: ", cat.recovery_timer)
	_check(GameState.adopted_total == 1 and GameState.coins == GameState.ADOPTION_REWARD,
		"Der echte Hausdurchlauf belohnt die Adoption genau einmal")
	await _test_deliveries(home)
	return await _finish(home)

func _refill_from_source(home: Node2D, kind: String) -> bool:
	if not await _return_cargo(home):
		return false
	var fixture_kind := "pantry" if kind == "food" else "faucet"
	var source := GameState.home.item_by_id("starter_" + fixture_kind)
	var item := GameState.home.item_by_id("starter_" + kind)
	if source == null or item == null:
		_check(false, "Quelle und Napf fuer %s sind vorhanden" % kind)
		return false
	if not await _walk(home, HomeCatalog.world(source.port())):
		_check(false, "Der Spieler erreicht die Quelle fuer %s" % kind)
		return false
	await _tap("interact")
	var acquired := GameState.supplies.cargo_amount
	var has_cargo := GameState.supplies.cargo_kind == kind and acquired > 0
	_check(has_cargo, "%s wird mit der InputMap-Aktion an der Quelle aufgenommen" % kind)
	if not has_cargo:
		return false
	var pantry_after_pickup := GameState.supplies.food_stock
	if not await _walk(home, HomeCatalog.world(item.port())):
		_check(false, "Der Spieler traegt %s von der Quelle zum Napf" % kind)
		return false
	await _tap("interact")
	var remaining := GameState.supplies.cargo_amount
	var filled := item.stock > 0
	_check(filled, "%s wird erst vor Ort aus der getragenen Ladung eingefuellt" % kind)
	_check(remaining <= acquired and (GameState.supplies.cargo_kind == kind \
			or GameState.supplies.cargo_kind.is_empty()),
		"Beim Nachfuellen von %s bleibt die passende Restladung erhalten" % kind)
	if not await _return_cargo(home):
		return false
	if kind == "food":
		_check(GameState.supplies.food_stock == pantry_after_pickup + remaining,
			"Zurueckgetragenes Futter landet exakt einmal wieder im globalen Vorrat")
	return filled

func _return_cargo(home: Node2D) -> bool:
	var kind := GameState.supplies.cargo_kind
	if kind.is_empty():
		return true
	var fixture_kind := "faucet" if kind == "water" else "pantry"
	var source := GameState.home.item_by_id("starter_" + fixture_kind)
	if source == null or not await _walk(home, HomeCatalog.world(source.port())):
		_check(false, "Restladung erreicht ihre Quelle %s" % fixture_kind)
		return false
	await _tap("interact")
	var returned := GameState.supplies.cargo_kind.is_empty() and GameState.supplies.cargo_amount == 0
	_check(returned, "%s wird durch Hinlaufen und Interaktion eingeraeumt oder zurueckgegeben" % kind)
	return returned

func _test_deliveries(home: Node2D) -> bool:
	print("--- Spieltest: Zwei Hauslieferungen ---")
	if not await _return_cargo(home):
		return false
	var hud: HomeHUD = home.get("hud")
	var supply_button: Button = hud.get_node("%SupplyButton")
	await _click_control(supply_button)
	var opened := hud.modal_kind == "supplies" and get_tree().paused
	_check(opened, "Ein echter Mausklick oeffnet den pausierenden Versorgungsdialog")
	if not opened:
		return false
	var panel: SupplyPanel = hud.get_node("%SupplyPanel")
	var order_button: Button = panel.get_node("OrderFoodButton")
	var button_id := order_button.get_instance_id()
	var coins_before := GameState.coins
	var price := GameState.food_price() + GameState.delivery_fee()
	await _click_control(order_button)
	_check(GameState.supplies.orders.size() == 1, "Der erste Buttonklick bestellt ein Paket")
	if GameState.supplies.orders.size() != 1:
		return false
	var first: SupplyOrder = GameState.supplies.orders[0]
	_check(is_instance_valid(order_button), "Der erste Einkauf erhaelt den vorhandenen Bestellbutton")
	if not is_instance_valid(order_button):
		return false
	order_button.grab_focus()
	await _send_ui_action(&"ui_accept")
	var two_orders := GameState.supplies.orders.size() == 2
	_check(two_orders, "Die Tastatur bestellt trotz laufender Lieferung ein zweites Paket")
	if not two_orders:
		return false
	var second: SupplyOrder = GameState.supplies.orders[1]
	_check(first.id != second.id and GameState.coins == coins_before - 2 * price,
		"Zwei bewusste Bestellungen haben eigene IDs und je genau eine Kostenbuchung")
	var first_remaining := first.remaining
	var second_remaining := second.remaining
	await _wait_physics(0.3)
	_check(first.remaining == first_remaining and second.remaining == second_remaining,
		"Beide Lieferzeiten stehen im geoeffneten Dialog still")
	_check(is_instance_valid(order_button) and order_button.get_instance_id() == button_id \
			and get_viewport().gui_get_focus_owner() == order_button,
		"Transaktionen und normale Refreshs erhalten den Bestellbutton samt Tastaturfokus")
	var modal_message: Label = hud.get("_modal_notice")
	_check(modal_message.is_visible_in_tree() and not modal_message.text.is_empty(),
		"Die Bestellbestaetigung ist innerhalb des Modals sichtbar")
	await _click_control(hud.get_node("%ModalCloseButton"))
	await _wait_physics(0.2)
	_check(hud.modal_kind.is_empty() and not get_tree().paused \
			and GameState.supplies.cargo_kind.is_empty() and GameState.supplies.orders.size() == 2,
		"Schliessen setzt das Spiel ohne Durchklicken oder automatische Paketabholung fort")
	var arrived := await _until(func() -> bool:
		return GameState.supplies.ready_count() == 2, maxf(first_remaining, second_remaining) + 2.0)
	_check(arrived, "Zwei parallele Lieferungen kommen waehrend aktiver Spielzeit an")
	_check(GameState.home_cats.is_empty(), "Auch das inzwischen leere Haus erhaelt beide Lieferungen")
	if not arrived:
		return false
	var count: Label = home.get_node("ParcelSpot/ParcelCount")
	_check(count.text == "Pakete\n2", "Die sichtbare Paketablage zeigt beide abholbereiten Pakete")
	if not await _walk(home, HomeCatalog.world(HomeCatalog.ENTRY)):
		_check(false, "Der Ausgang bleibt neben zwei Paketen physisch erreichbar")
		return false
	_check(String(home.get("_focus_kind")) == "exit",
		"Direkt an der Tuer gewinnt der Ausgang statt der Paketablage den Fokus")
	var pantry_before := GameState.supplies.food_stock
	for remaining: int in [1, 0]:
		if not await _walk(home, HomeCatalog.world(SupplyCatalog.PARCEL_CELL)):
			_check(false, "Der Spieler erreicht die Paketablage")
			return false
		var spot: Node2D = home.get_node("ParcelSpot")
		var parcel_screen := spot.get_global_transform_with_canvas().origin
		var hint: Control = hud.get("_hint_panel")
		_check(hud.get_viewport_rect().has_point(parcel_screen)
			and not hint.get_global_rect().has_point(parcel_screen),
			"Die Paketablage bleibt beim Abholen sichtbar statt hinter dem Kontexthinweis zu liegen")
		await _tap("interact")
		var collected := GameState.supplies.cargo_kind == "package" \
			and GameState.supplies.cargo_amount == SupplyCatalog.PACKAGE_UNITS \
			and GameState.supplies.ready_count() == remaining
		_check(collected, "Eine echte Interaktion nimmt genau ein Paket; %d bleiben liegen" % remaining)
		if not collected:
			return false
		if remaining == 1:
			await _tap("interact")
			_check(GameState.supplies.ready_count() == 1 \
					and GameState.supplies.cargo_amount == SupplyCatalog.PACKAGE_UNITS,
				"Mit vollem Arm wird das weitere Paket nicht doppelt abgeholt")
			await _tap("home_furnish")
			_check(hud.modal_kind.is_empty() and home.get("_preview") == null \
					and GameState.supplies.cargo_kind == "package",
				"Einrichten wird mit Ladung abgelehnt, ohne das Paket zu verlieren")
		if not await _return_cargo(home):
			return false
		_check(GameState.supplies.food_stock == pantry_before + (2 - remaining) * SupplyCatalog.PACKAGE_UNITS,
			"Das Paket wird am Schrank genau einmal in den gemeinsamen Vorrat eingeraeumt")
	_check(GameState.supplies.orders.is_empty() and GameState.supplies.cargo_kind.is_empty(),
		"Nach zwei getrennten Abholwegen sind beide Bestellungen abgeschlossen und die Haende frei")
	return true

func _click_control(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().physics_frame
		await get_tree().process_frame

func _send_ui_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().physics_frame
		await get_tree().process_frame

func _wait_physics(seconds: float) -> void:
	var deadline := _physics_deadline(seconds)
	while Engine.get_physics_frames() < deadline:
		await get_tree().physics_frame

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
		await get_tree().process_frame
	# Der Zustands-Takt folgt dem process_frame-Signal, nicht dem Physik-Signal.
	await get_tree().process_frame
	return bool(condition.call())

func _check(ok: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FEHLER", description])
	if not ok:
		_failures.append(description)

func _release() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	Input.action_release("interact")
	Input.action_release("home_furnish")
	Input.action_release("ui_accept")

func _finish(home: Node2D) -> PackedStringArray:
	_release()
	get_tree().paused = false
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
