## Begehbares Zuhause; die Simulation gehoert weiterhin dem GameState.
extends Node2D

const REACH := 24.0
const NEED_TEXT := {
	"hunger": "hat Hunger", "thirst": "hat Durst", "cleanliness": "möchte gewaschen werden",
	"health": "braucht Behandlung", "enrichment": "möchte spielen",
}
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
var _facing := Vector2.DOWN
var _focus_id: String = ""
var _focus_kind: String = ""
var _preview: HomeItemActor
var _preview_error: String = ""
var _input_delay: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.deliver_carried_cats()
	simulation = GameState.home_simulation
	simulation.sync_cats()
	GameState.simulation_active = true
	player.position = GameState.home.player_position
	var camera: Camera2D = player.get_node("Camera")
	camera.zoom = Vector2(1.5, 1.5)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = HomeCatalog.ROOM_SIZE.x * HomeCatalog.TILE
	camera.limit_bottom = HomeCatalog.ROOM_SIZE.y * HomeCatalog.TILE
	camera.reset_smoothing()
	_build_room()
	_held_atlas.atlas = load("res://assets/sprites/cats.png")
	_held_sprite.texture = _held_atlas
	player.add_child(_held_sprite)
	hud = HomeHUD.new()
	hud.name = "HomeHUD"
	$UI.add_child(hud)
	hud.furnish_requested.connect(_toggle_furnishing)
	hud.shop_requested.connect(func() -> void: _open_modal("shop"))
	hud.pause_requested.connect(_pause_or_cancel)
	hud.close_requested.connect(_close_modal)
	hud.menu_requested.connect(func() -> void: SceneRouter.goto_main_menu())
	hud.item_selected.connect(start_placement)
	hud.item_purchased.connect(_buy_item)
	hud.upgrade_requested.connect(_buy_upgrade)
	GameState.home_cats_changed.connect(_sync_cats)
	GameState.home_layout_changed.connect(_rebuild_items)
	GameState.coins_changed.connect(func(_amount: int) -> void: hud.refresh())
	GameState.cat_adopted.connect(_on_cat_adopted)
	SaveManager.save_failed.connect(hud.show_toast)
	simulation.care_finished.connect(_on_care_finished)
	_touch.call("configure_home")
	_rebuild_items()
	_sync_cats()
	hud.show_toast("Willkommen! Fülle die Näpfe. Mit B richtest du dein Katzenhaus ein.")

func _build_room() -> void:
	var floor_tiles: TileMapLayer = $Floor
	for y in HomeCatalog.ROOM_SIZE.y:
		for x in HomeCatalog.ROOM_SIZE.x:
			var cell := Vector2i(x, y)
			var tile := (x + y) % 2 if HomeCatalog.inside(cell) else 2
			if cell == HomeCatalog.ENTRY + Vector2i.DOWN:
				tile = 3
			floor_tiles.set_cell(cell, 0, Vector2i(tile, 0))
	var width := float(HomeCatalog.ROOM_SIZE.x * HomeCatalog.TILE)
	var height := float(HomeCatalog.ROOM_SIZE.y * HomeCatalog.TILE)
	_wall(Vector2(width / 2, 8), Vector2(width, 16))
	_wall(Vector2(width / 2, height - 8), Vector2(width, 16))
	_wall(Vector2(8, height / 2), Vector2(16, height))
	_wall(Vector2(width - 8, height / 2), Vector2(16, height))
	var exit_label := Label.new()
	exit_label.text = "Rausgehen"
	exit_label.add_theme_font_size_override("font_size", 10)
	exit_label.add_theme_color_override("font_color", Color("#382c31"))
	exit_label.position = HomeCatalog.world(HomeCatalog.ENTRY) + Vector2(-27, -3)
	exit_label.z_index = -1
	add_child(exit_label)

func _wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	add_child(wall)

func _sync_cats() -> void:
	_bind_simulation()
	simulation.sync_cats()
	for id: String in _cat_actors.keys():
		if simulation.cat_by_id(id) == null:
			var actor: HomeCatActor = _cat_actors[id]
			actor.queue_free()
			_cat_actors.erase(id)
	for cat in GameState.home_cats:
		if not _cat_actors.has(cat.id):
			var actor := HomeCatActor.new()
			actor.data = cat
			actor.simulation = simulation
			_entities.add_child(actor)
			_cat_actors[cat.id] = actor
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
		hud.set_hint("Sanft versorgen …\nAktion / Esc: abbrechen")
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
	var holding := not simulation.held_cat_id.is_empty()
	var hint := "Geh zu einer Katze oder einem Napf.\nB: Einrichten · Esc: Pause"
	if holding:
		_focus_kind = "drop"
		var held := simulation.cat_by_id(simulation.held_cat_id)
		hint = "%s absetzen\nOder zum Waschplatz / zur Behandlung tragen." % held.cat_name
	for actor: HomeCatActor in _cat_actors.values():
		actor.selected = false
		if holding:
			continue
		var state: HomeCatState = GameState.home.cats[actor.data.id]
		var distance := player.position.distance_to(state.position)
		if distance < closest and _clear_line(state.position):
			closest = distance
			_focus_kind = "cat"
			_focus_id = actor.data.id
			hint = "%s aufheben\n%s" % [actor.data.cat_name, _cat_hint(actor.data)]
	for item in GameState.home.items:
		if not item.placed:
			continue
		var actor: HomeItemActor = _item_actors.get(item.id)
		if actor != null:
			actor.selected = false
		if holding and item.kind not in ["wash", "vet"]:
			continue
		if not holding and item.kind not in ["food", "water", "litter"]:
			continue
		if _focus_kind == "cat" and item.kind in ["food", "water"] \
				and item.stock == HomeCatalog.capacity(item.kind):
			continue
		var point := HomeCatalog.world(item.port())
		var distance := player.position.distance_to(point)
		if distance <= closest and _clear_line(point):
			closest = distance
			_focus_kind = "item"
			_focus_id = item.id
			match item.kind:
				"food": hint = "Futter nachfüllen\nKostenlos · Katzen bedienen sich selbst."
				"water": hint = "Wasser nachfüllen\nKostenlos · Katzen bedienen sich selbst."
				"litter": hint = "Katzenklo reinigen\n" + ("Die Streu ist sauber." if item.dirt == 0 else "Frische Streu wird gebraucht.")
				"wash": hint = "Katze waschen\nAm Waschplatz sanft säubern."
				"vet": hint = "Katze behandeln\nAn der Station gesund pflegen."
	if not holding and player.position.distance_to(HomeCatalog.world(HomeCatalog.ENTRY)) < closest \
			and _clear_line(HomeCatalog.world(HomeCatalog.ENTRY)):
		_focus_kind = "exit"
		hint = "Rausgehen und Katzen retten"
	if _focus_kind == "cat":
		(_cat_actors[_focus_id] as HomeCatActor).selected = true
	elif _focus_kind == "item":
		(_item_actors[_focus_id] as HomeItemActor).selected = true
	var observed: CatData
	if holding:
		observed = simulation.cat_by_id(simulation.held_cat_id)
	elif _focus_kind == "cat":
		observed = simulation.cat_by_id(_focus_id)
	hud.set_cat_status(observed)
	hud.set_hint(("E / Aktion: " if not _focus_kind.is_empty() else "") + hint)
	_touch.call("set_action_label", hint.get_slice("\n", 0) if not _focus_kind.is_empty() else "Interaktion")

func _cat_hint(cat: CatData) -> String:
	var lowest := CatData.RECOVERY_THRESHOLD
	var result := "Fühlt sich wohl."
	for need: String in NEED_TEXT:
		var value := float(cat.get(need))
		if value < lowest:
			lowest = value
			result = "%s %s." % [cat.cat_name, String(NEED_TEXT[need])]
	var state: HomeCatState = GameState.home.cats[cat.id]
	if state.toilet_elapsed >= HomeSimulation.TOILET_OVERDUE:
		result = "Braucht ein sauberes, erreichbares Katzenklo."
	return result

func interact() -> void:
	if get_tree().paused or simulation.is_caring():
		return
	match _focus_kind:
		"cat":
			if simulation.pick_up(_focus_id):
				AudioManager.play_sfx("pickup")
		"drop":
			var target := player.position + _facing * 18.0
			if not simulation.drop(target):
				hud.show_toast("Hier ist kein freier Platz zum Absetzen.")
			else:
				_save()
		"item":
			var item := GameState.home.item_by_id(_focus_id)
			if item.kind in ["food", "water"]:
				if item.stock == HomeCatalog.capacity(item.kind):
					hud.show_toast("Dieser Napf ist schon voll.")
					return
				item.stock = HomeCatalog.capacity(item.kind)
			elif item.kind == "litter":
				if simulation.item_in_use(item.id):
					hud.show_toast("Bitte warten, bis die Katze fertig ist.")
					return
				item.dirt = 0
			else:
				if not simulation.begin_care(item):
					hud.show_toast("Die Station ist gerade nicht frei.")
				return
			AudioManager.play_sfx_varied("care")
			hud.show_toast("%s ist bereit." % HomeCatalog.title(item.kind))
			_save()
		"exit":
			SceneRouter.goto_rescue()
		_:
			hud.show_toast("Geh näher an eine Katze oder an die Bedienseite eines Gegenstands.")

func _update_held_visual() -> void:
	_held_sprite.visible = not simulation.held_cat_id.is_empty()
	if not _held_sprite.visible:
		return
	var cat := simulation.cat_by_id(simulation.held_cat_id)
	_held_atlas.region = Rect2(0, cat.fur_variant * 16, 16, 16)
	_held_sprite.position = Vector2(0, -18)
	if simulation.is_caring():
		var state: HomeCatState = GameState.home.cats[cat.id]
		var item := GameState.home.item_by_id(state.target_id)
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

func _open_modal(kind: String) -> void:
	_release_inputs()
	hud.open_modal(kind)
	get_tree().paused = true
	_touch.call("set_enabled", false)
	_save()

func _close_modal() -> void:
	hud.close_modal()
	get_tree().paused = false
	_touch.call("set_enabled", true)
	_release_inputs()
	_input_delay = 0.15

func _toggle_furnishing() -> void:
	if _preview != null:
		_cancel_placement()
	elif not simulation.held_cat_id.is_empty():
		hud.show_toast("Setze die Katze erst ab, bevor du das Haus einrichtest.")
	else:
		_open_modal("furnish")

func start_placement(id: String) -> void:
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
		hud.set_hint("%s platzieren\nLinks mit dem Joystick bewegen.\n%s" % [
			HomeCatalog.title(_preview.data.kind),
			"Rechts aufstellen, drehen oder einlagern." if _preview.allowed else _preview_error])
	else:
		hud.set_hint("%s platzieren · R drehen · X einlagern\n%s" % [
			HomeCatalog.title(_preview.data.kind),
			"E bestätigen · Esc abbrechen" if _preview.allowed else _preview_error])
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
