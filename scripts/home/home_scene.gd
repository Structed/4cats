## Begehbares Zuhause; die Simulation gehoert weiterhin dem GameState.
extends Node2D

const REACH := 24.0
const CAMERA_BOTTOM_MARGIN := 64
const RELEASE_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down", "interact", "sprint",
	"home_furnish", "home_rotate", "home_store",
]

@onready var player: Player = $Player
@onready var _entities: Node2D = $Entities
@onready var _touch: CanvasLayer = $TouchControls

var hud: HomeHUD
var simulation: HomeSimulation
var _cat_actors: Dictionary = {}
var _item_actors: Dictionary = {}
var _held_sprite := Sprite2D.new()
var _held_atlas := AtlasTexture.new()
var _room := HomeRoom.new()
var _facing := Vector2.DOWN
var _focus_id: String = ""
var _focus_kind: String = ""
var _preview: HomeItemActor
var _preview_error: String = ""
var _input_delay: float = 0.0
var _context: InteractionContext

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.deliver_carried_cats()
	simulation = GameState.home_simulation
	simulation.sync_cats()
	GameState.simulation_active = true
	_context = InteractionContext.new(simulation, _toast, _finish_supply_action, _save)
	player.position = GameState.home.player_position
	var camera: Camera2D = player.get_node("Camera")
	camera.zoom = Vector2(1.5, 1.5)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = HomeCatalog.ROOM_SIZE.x * HomeCatalog.TILE
	# Platz fuer die Kontextanzeige lassen, damit die Paketablage sichtbar bleibt.
	camera.limit_bottom = HomeCatalog.ROOM_SIZE.y * HomeCatalog.TILE + CAMERA_BOTTOM_MARGIN
	camera.reset_smoothing()
	_room.build(self, $Floor)
	_held_atlas.atlas = load("res://assets/sprites/cats.png")
	_held_sprite.texture = _held_atlas
	player.add_child(_held_sprite)
	var cargo := SupplyCargoActor.new()
	cargo.name = "SupplyCargo"
	player.add_child(cargo)
	hud = HomeHUD.new()
	hud.name = "HomeHUD"
	$UI.add_child(hud)
	hud.action_requested.connect(_on_hud_action)
	GameState.home_cats_changed.connect(_sync_cats)
	GameState.home_layout_changed.connect(_rebuild_items)
	GameState.coins_changed.connect(func(_amount: int) -> void: hud.refresh())
	GameState.cat_adopted.connect(_on_cat_adopted)
	GameState.cat_died.connect(_on_cat_died)
	GameState.supplies_changed.connect(_on_supplies_changed)
	SaveManager.save_failed.connect(hud.show_toast)
	simulation.care_finished.connect(_on_care_finished)
	_touch.call("configure_home")
	_rebuild_items()
	_sync_cats()
	var fixture_hint := hud.fixture_hint()
	hud.show_toast(fixture_hint if not fixture_hint.is_empty() \
		else "Willkommen! Futter am Schrank und Wasser am Hahn holen, dann zu den Näpfen tragen.")

func _sync_cats() -> void:
	_bind_simulation()
	simulation.sync_cats()
	for id: String in _cat_actors.keys():
		if simulation.cat_by_id(id) == null:
			var actor: HomeCatActor = _cat_actors[id]
			actor.hide()
			actor.queue_free()
			_cat_actors.erase(id)
	for cat in GameState.home_cats:
		if not _cat_actors.has(cat.id):
			var actor := HomeCatActor.new()
			actor.data = cat
			actor.simulation = simulation
			_entities.add_child(actor)
			_cat_actors[cat.id] = actor
	_update_held_visual()
	if not get_tree().paused and _preview == null and not simulation.is_caring():
		_resolve_focus()
	hud.refresh()

func _rebuild_items() -> void:
	_bind_simulation()
	for actor: HomeItemActor in _item_actors.values():
		actor.queue_free()
	_item_actors.clear()
	for item in GameState.home.items:
		if item.placed:
			var actor := HomeItemActor.new()
			actor.data = item
			actor.simulation = simulation
			_entities.add_child(actor)
			_item_actors[item.id] = actor
	hud.refresh()

func _bind_simulation() -> void:
	if simulation == GameState.home_simulation:
		return
	if simulation.care_finished.is_connected(_on_care_finished):
		simulation.care_finished.disconnect(_on_care_finished)
	_cancel_placement()
	for actor: HomeCatActor in _cat_actors.values():
		actor.queue_free()
	_cat_actors.clear()
	simulation = GameState.home_simulation
	simulation.care_finished.connect(_on_care_finished)
	_context.simulation = simulation
	player.position = GameState.home.player_position

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_input_delay = maxf(0.0, _input_delay - delta)
	_update_held_visual()
	player.set_physics_process(not simulation.is_caring())
	if simulation.is_caring():
		player.velocity = Vector2.ZERO
		hud.set_cat_status(simulation.cat_by_id(simulation.held_cat_id))
		hud.set_hint("Pflege …\nAktion / Esc: abbrechen")
		_touch.call("set_action_label", "Abbrechen")
	elif _preview == null:
		_resolve_focus()
	else:
		_update_preview()

func _physics_process(_delta: float) -> void:
	if get_tree().paused or _input_delay > 0.0 or bool(SceneRouter.get("_busy")):
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		_facing = Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) \
			else Vector2(0, signf(direction.y))
	GameState.home.player_position = player.position
	if Input.is_action_just_pressed("home_furnish"):
		_toggle_furnishing()
		return
	if simulation.is_caring():
		if Input.is_action_just_pressed("interact"):
			_pause_or_cancel()
		return
	if _preview != null:
		if Input.is_action_just_pressed("home_rotate"):
			_preview.data.turns = posmod(_preview.data.turns + 1, 4)
		if Input.is_action_just_pressed("home_store"):
			_store_preview()
		elif Input.is_action_just_pressed("interact"):
			_place_preview()
	elif Input.is_action_just_pressed("interact"):
		_resolve_focus()
		interact()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		_pause_or_cancel()
		get_viewport().set_input_as_handled()

func _clear_line(to: Vector2) -> bool:
	var distance := player.position.distance_to(to)
	for step in range(1, ceili(distance / 4.0) + 1):
		var point := player.position.lerp(to, minf(1.0, step * 4.0 / maxf(distance, 1.0)))
		if simulation.layout.blocked(HomeCatalog.cell(point)):
			return false
	return true

func _resolve_focus() -> void:
	_focus_id = ""
	_focus_kind = ""
	var closest := REACH
	var held: CatData = simulation.cat_by_id(simulation.held_cat_id)
	var holding := held != null
	var carrying := not GameState.supplies.cargo_kind.is_empty()
	var hint := ""
	if holding:
		_focus_kind = "drop"
		hint = "%s absetzen\nZum Waschen oder Behandeln tragen." % held.cat_name
	elif carrying:
		hint = "%s\n%s" % [GameState.supplies.cargo_text(), SupplyCatalog.cargo_destination(GameState.supplies.cargo_kind)]
	for actor: HomeCatActor in _cat_actors.values():
		actor.selected = false
		if holding or carrying:
			continue
		var state: HomeCatState = GameState.home.cats.get(actor.data.id)
		if state == null:
			continue
		var distance := player.position.distance_to(state.position)
		if distance < closest and _clear_line(state.position):
			closest = distance
			_focus_kind = "cat"
			_focus_id = actor.data.id
			hint = "%s aufheben" % actor.data.cat_name
			if state.toilet_elapsed >= HomeSimulation.TOILET_OVERDUE:
				hint += "\nSauberes, erreichbares Katzenklo nötig."
	for item in GameState.home.items:
		if not item.placed:
			continue
		var actor: HomeItemActor = _item_actors.get(item.id)
		if actor != null:
			actor.selected = false
		if not InteractionRegistry.has(item.kind):
			continue
		if _focus_kind == "cat" and item.kind in ["food", "water"] \
				and item.stock == HomeCatalog.capacity(item.kind):
			continue
		var point := HomeCatalog.world(item.port())
		var distance := player.position.distance_to(point)
		if distance <= closest and _clear_line(point):
			closest = distance
			_focus_kind = item.kind
			_focus_id = item.id
			hint = _item_hint(item, holding)
	var parcel_point := HomeCatalog.world(SupplyCatalog.PARCEL_CELL)
	var ready := GameState.supplies.ready_count()
	if ready > 0 and player.position.distance_to(parcel_point) <= closest and _clear_line(parcel_point):
		closest = player.position.distance_to(parcel_point)
		_focus_kind = "parcel"
		_focus_id = ""
		hint = "Paket abholen\n%d bereit · Ein Paket zum Vorratsschrank tragen." % ready
		if holding:
			hint = "Paket abholen\nSetze zuerst die Katze ab."
		elif carrying:
			hint = "Paket abholen\n" + SupplyCatalog.cargo_return_hint(GameState.supplies.cargo_kind)
	var exit_point := HomeCatalog.world(HomeCatalog.ENTRY)
	# Die Tuer gewinnt bei gleicher Entfernung; Pakete blockieren den Ausgang nie.
	if not holding and player.position.distance_to(exit_point) <= closest and _clear_line(exit_point):
		_focus_kind = "exit"
		_focus_id = ""
		hint = "Rausgehen\nKatzen retten oder Futter im Laden holen."
	if _focus_kind == "cat":
		(_cat_actors[_focus_id] as HomeCatActor).selected = true
	elif InteractionRegistry.has(_focus_kind) and _item_actors.has(_focus_id):
		(_item_actors[_focus_id] as HomeItemActor).selected = true
	_room.update_parcels(_focus_kind == "parcel")
	var observed: CatData
	if holding:
		observed = simulation.cat_by_id(simulation.held_cat_id)
	elif _focus_kind == "cat":
		observed = simulation.cat_by_id(_focus_id)
	hud.set_cat_status(observed)
	var shortcut := "E: " if not _focus_kind.is_empty() and not bool(_touch.call("is_touch_visible")) else ""
	hud.set_hint(shortcut + hint)
	_touch.call("set_action_label", hint.get_slice("\n", 0) if not _focus_kind.is_empty() else "Interaktion")

## Hinweistext des anvisierten Gegenstands; der Text gehoert der Interaktion.
func _item_hint(item: HomeItemData, holding: bool) -> String:
	var handler := InteractionRegistry.handler(item.kind)
	if handler == null:
		return ""
	_context.item = item
	_context.holding = holding
	return handler.hint(_context)


func interact() -> void:
	if get_tree().paused or simulation.is_caring():
		return
	if InteractionRegistry.has(_focus_kind):
		_interact_item()
		return
	match _focus_kind:
		"cat":
			if not GameState.supplies.cargo_kind.is_empty():
				hud.show_toast(SupplyCatalog.cargo_return_hint(GameState.supplies.cargo_kind))
			elif simulation.pick_up(_focus_id):
				AudioManager.play_sfx("pickup")
			else:
				hud.show_toast("Diese Katze lässt sich gerade nicht aufnehmen.")
		"drop":
			var target := player.position + _facing * 18.0
			if not simulation.drop(target):
				hud.show_toast("Hier ist kein freier Platz zum Absetzen.")
			else:
				_save()
		"parcel":
			var error := GameState.collect_delivery()
			_finish_supply_action(error,
				"Paket aufgenommen. Am Vorratsschrank einräumen. Noch %d bereit." % GameState.supplies.ready_count(),
				"pickup")
		"exit":
			SceneRouter.goto_rescue()
		_:
			hud.show_toast(SupplyCatalog.cargo_destination(GameState.supplies.cargo_kind) \
				if not GameState.supplies.cargo_kind.is_empty() \
				else "Geh näher an eine Katze oder an die Bedienseite eines Gegenstands.")

## Reicht die Bedienung an die Interaktion der Gegenstandsart weiter.
func _interact_item() -> void:
	var item := GameState.home.item_by_id(_focus_id)
	if item == null or not item.placed:
		hud.show_toast("Dieser Gegenstand ist nicht mehr aufgestellt.")
		return
	var handler := InteractionRegistry.handler(item.kind)
	if handler == null:
		return
	_context.item = item
	_context.holding = not simulation.held_cat_id.is_empty()
	handler.perform(_context)


## Meldung an den Spieler; als Callable an die Interaktionen gereicht.
func _toast(text: String) -> void:
	hud.show_toast(text)


func _finish_supply_action(error: String, message: String, sound: String = "care") -> void:
	if not error.is_empty():
		hud.show_toast(error)
		return
	AudioManager.play_sfx_varied(sound)
	hud.show_toast(message)
	_save()

func _update_held_visual() -> void:
	var cat := simulation.cat_by_id(simulation.held_cat_id)
	_held_sprite.visible = cat != null
	if cat == null:
		return
	_held_atlas.region = Rect2(0, cat.fur_variant * 16, 16, 16)
	_held_sprite.position = Vector2(0, -18)
	if simulation.is_caring():
		var state: HomeCatState = GameState.home.cats.get(cat.id)
		if state == null:
			return
		var item := GameState.home.item_by_id(state.target_id)
		if item != null:
			_held_sprite.global_position = item.center() + Vector2(0, -5)

func _pause_or_cancel() -> void:
	if not hud.modal_kind.is_empty():
		_close_modal()
	elif _preview != null:
		_cancel_placement()
	elif simulation.is_caring():
		simulation.cancel_care()
		hud.show_toast("Pflege abgebrochen. Du kannst die Katze weitertragen.")
	else:
		_open_modal("pause")

## Einziger Verteiler fuer alles, was das HUD meldet.
##
## Ein neues Fenster braucht hier einen Zweig -- und sonst nichts an dieser
## Datei.
func _on_hud_action(action: StringName, payload: Variant) -> void:
	match action:
		&"furnish":
			_toggle_furnishing()
		&"shop":
			_open_modal("shop")
		&"supplies":
			_open_modal("supplies")
		&"pause":
			_pause_or_cancel()
		&"close":
			_close_modal()
		&"menu":
			SceneRouter.goto_main_menu()
		&"select_item":
			start_placement(String(payload))
		&"buy_item":
			_buy_item(String(payload))
		&"upgrade":
			_buy_upgrade(String(payload))
		_:
			push_warning("Unbekannte HUD-Aktion: %s" % action)

func _open_modal(kind: String) -> void:
	_release_inputs()
	hud.open_modal(kind)
	get_tree().paused = true
	AnalyticsManager.player_activity()
	_touch.call("set_enabled", false)
	_save()

func _close_modal() -> void:
	hud.close_modal()
	get_tree().paused = false
	AnalyticsManager.player_activity()
	_touch.call("set_enabled", true)
	_release_inputs()
	_input_delay = 0.15

func _toggle_furnishing() -> void:
	if _preview != null:
		_cancel_placement()
	elif not simulation.held_cat_id.is_empty():
		hud.show_toast("Setze die Katze erst ab, bevor du das Haus einrichtest.")
	elif not GameState.supplies.cargo_kind.is_empty():
		hud.show_toast(SupplyCatalog.cargo_return_hint(GameState.supplies.cargo_kind) + " Danach kannst du einrichten.")
	else:
		_open_modal("furnish")

func start_placement(id: String) -> void:
	if not GameState.supplies.cargo_kind.is_empty():
		hud.show_toast(SupplyCatalog.cargo_return_hint(GameState.supplies.cargo_kind) + " Danach kannst du einrichten.")
		return
	if not simulation.held_cat_id.is_empty():
		hud.show_toast("Setze die Katze erst ab, bevor du das Haus einrichtest.")
		return
	var item := GameState.home.item_by_id(id)
	if item == null or simulation.item_in_use(id):
		hud.show_toast("Dieser Gegenstand kann gerade nicht versetzt werden.")
		return
	_close_modal()
	_cancel_placement()
	_preview = HomeItemActor.new()
	_preview.data = HomeItemData.from_dict(item.to_dict())
	_preview.ghost = true
	_preview.z_index = 20
	_entities.add_child(_preview)
	hud.set_building(true)
	_touch.call("set_building", true)
	_update_preview()

func _occupants() -> Array[Vector2]:
	var points: Array[Vector2] = [player.position]
	for state: HomeCatState in GameState.home.cats.values():
		points.append(state.position)
	return points

func _update_preview() -> void:
	var size := _preview.data.rect().size
	var target := HomeCatalog.cell(player.position + _facing * 40.0)
	_preview.data.cell = target - Vector2i(size.x / 2, size.y / 2)
	_preview_error = simulation.layout.placement_error(_preview.data.id,
		_preview.data.cell, _preview.data.turns, _occupants())
	if simulation.item_in_use(_preview.data.id):
		_preview_error = "Dieser Gegenstand wird gerade benutzt."
	_preview.allowed = _preview_error.is_empty()
	if bool(_touch.call("is_touch_visible")):
		hud.set_hint("%s platzieren\nJoystick: bewegen · rechts aufstellen%s" % [
			HomeCatalog.title(_preview.data.kind),
			"" if _preview.allowed else "\n" + _preview_error])
	else:
		hud.set_hint("%s · R drehen · X einlagern\n%s" % [
			HomeCatalog.title(_preview.data.kind),
			"E aufstellen · Esc abbrechen" if _preview.allowed else _preview_error])
	_touch.call("set_action_label", "Aufstellen")

func _place_preview() -> void:
	_update_preview()
	var error := GameState.place_home_item(_preview.data.id, _preview.data.cell,
		_preview.data.turns, _occupants())
	if not error.is_empty():
		hud.show_toast(error)
		return
	_cancel_placement()
	AudioManager.play_sfx("deliver")
	_save()

func _store_preview() -> void:
	var item := GameState.home.item_by_id(_preview.data.id)
	if not item.placed:
		_cancel_placement()
		return
	var error := GameState.store_home_item(item.id)
	if not error.is_empty():
		hud.show_toast(error)
		return
	_cancel_placement()
	hud.show_toast("Eingelagert. Vorrat und Zustand bleiben erhalten.")
	_save()

func _cancel_placement() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	hud.set_building(false)
	_touch.call("set_building", false)

func _buy_item(kind: String) -> void:
	if GameState.buy_home_item(kind) == null:
		hud.show_toast("Dafür reichen die Münzen nicht.")
	else:
		AudioManager.play_sfx("coins")
		_save()
	hud.refresh()

func _buy_upgrade(id: String) -> void:
	if GameState.purchase_upgrade(id):
		AudioManager.play_sfx("coins")
		_save()
	else:
		hud.show_toast("Dieser Ausbau ist gerade nicht verfügbar.")
	hud.refresh()

func _on_care_finished(_id: String, kind: String) -> void:
	AudioManager.play_sfx_varied("care")
	hud.show_toast("Frisch gewaschen!" if kind == "wash" else "Die Behandlung hat gutgetan!")
	_save()

func _on_cat_adopted(cat: CatData, reward: int) -> void:
	AudioManager.play_sfx("adopt")
	hud.show_toast("%s hat ein Zuhause gefunden! +%d Münzen" % [cat.cat_name, reward])
	_save()

func _on_cat_died(cat: CatData) -> void:
	hud.set_cat_status(null)
	_sync_cats()
	hud.show_toast("%s ist gestorben. Die übrigen Katzen brauchen weiter deine Fürsorge." % cat.cat_name)
	_save()

func _on_supplies_changed() -> void:
	_room.update_parcels(_focus_kind == "parcel")
	hud.refresh()

func _save() -> void:
	GameState.home.player_position = player.position
	SaveManager.save_game()

func _release_inputs() -> void:
	player.velocity = Vector2.ZERO
	for action in RELEASE_ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)

func prepare_to_leave() -> void:
	_cancel_placement()
	simulation.cancel_care()
	if not simulation.held_cat_id.is_empty():
		if not simulation.drop(player.position):
			simulation.drop(simulation.layout.free_position())
	GameState.home.player_position = player.position
	_release_inputs()
	get_tree().paused = false

func _exit_tree() -> void:
	if is_instance_valid(player) and is_instance_valid(hud):
		prepare_to_leave()
	GameState.simulation_active = false
