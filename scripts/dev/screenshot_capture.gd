## Entwicklungshilfe: nimmt nach kurzer Wartezeit ein Bild des Spiels auf.
##
## Wird nur eingehaengt, wenn beim Start `--screenshot=<pfad>` uebergeben wird.
## Der Umweg ueber den Viewport ist zuverlaessiger als ein Bildschirmfoto von
## aussen, weil dafuer kein Fensterfokus noetig ist.
extends Node

## Pfad, unter dem das Bild abgelegt wird.
var output_path: String = ""

## So viele Sekunden wird gewartet, bis die Szene vollstaendig steht.
var delay_seconds: float = 2.5

## Soll das Spiel nach der Aufnahme beendet werden?
var quit_after: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_after_delay()


func _capture_after_delay() -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_apply_preview()

	# Zwei Frames abwarten, damit das Bild wirklich fertig gezeichnet ist.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error == OK:
		print("Screenshot gespeichert: %s" % output_path)
	else:
		printerr("Screenshot fehlgeschlagen (%s): %s" % [output_path, error_string(error)])

	if quit_after:
		get_tree().quit(0 if error == OK else 1)


func _apply_preview() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if "--touch-preview" in OS.get_cmdline_user_args():
		var touch := scene.get_node_or_null("TouchControls")
		if touch != null:
			# Nur diese Instanz umstellen, keine Benutzereinstellung speichern.
			touch.set("_forced", true)
			touch.call("_apply_visibility")
	for argument in OS.get_cmdline_user_args():
		if argument == "--menu-preview=options" and scene.has_method("_on_options_pressed"):
			scene.call("_on_options_pressed")
		elif argument == "--menu-preview=analytics" and scene.has_method("_show_analytics"):
			scene.call("_show_analytics")
		elif argument == "--menu-preview=difficulty" and scene.has_method("_on_new_game_pressed"):
			scene.call("_on_new_game_pressed")
			var choice: OptionButton = scene.get_node("%DifficultyChoice")
			var index := DifficultyRules.IDS.find(GameState.difficulty_id)
			choice.select(index)
			choice.item_selected.emit(index)
		elif argument == "--rescue-preview=shop" and scene.has_method("_try_pick_up"):
			var generator: LevelGenerator = scene.get("_generator")
			var player: Player = scene.get_node("Player")
			player.position = LevelGenerator.cell_to_world(generator.shop_cell)
			_reset_camera(player)
			scene.call("_try_pick_up")
		elif argument == "--home-preview=supplies" and scene.has_method("_open_modal"):
			scene.call("_open_modal", "supplies")
		elif argument in ["--home-preview=parcel", "--home-preview=critical"]:
			if "--demo" not in OS.get_cmdline_user_args() or not scene.has_method("_resolve_focus"):
				push_error("Diese Hausvorschau braucht --demo und die Hausszene.")
				get_tree().quit(1)
				return
			GameState.simulation_active = false
			var player: Player = scene.get_node("Player")
			if argument == "--home-preview=parcel":
				GameState.order_food()
				GameState.order_food()
				GameState.supplies.step(DifficultyRules.value(GameState.difficulty_id, "delivery_seconds"))
				GameState.supplies_changed.emit()
				player.position = HomeCatalog.world(SupplyCatalog.PARCEL_CELL + Vector2i.UP)
			else:
				var cat: CatData = GameState.home_cats[0]
				cat.hunger = 0.0
				cat.thirst = 0.0
				cat.health = 0.0
				cat.critical_elapsed = DifficultyRules.value(GameState.difficulty_id, "grace") / 2.0
				var state: HomeCatState = GameState.home.cats[cat.id]
				player.position = state.position + Vector2(0, 12)
				GameState.home_cats_changed.emit()
			_reset_camera(player)
			scene.call("_resolve_focus")
		elif argument == "--home-preview=furnish" and scene.has_method("_open_modal"):
			scene.call("_open_modal", "furnish")
		elif argument == "--home-preview=placement" and scene.has_method("start_placement"):
			scene.call("start_placement", "starter_toy")
		elif argument == "--home-preview=cat" and scene.has_method("_resolve_focus"):
			if GameState.home_cats.is_empty():
				push_error("Keine Katze fuer die Vorschau vorhanden. Mit --demo starten.")
				get_tree().quit(1)
				return
			var cat: CatData = GameState.home_cats[0]
			var state: HomeCatState = GameState.home.cats[cat.id]
			var simulation: HomeSimulation = scene.get("simulation")
			if not simulation.pick_up(cat.id):
				push_error("Die Katze konnte fuer die Vorschau nicht aufgenommen werden.")
				get_tree().quit(1)
				return
			var player: Player = scene.get_node("Player")
			player.position = state.position
			var camera: Camera2D = player.get_node("Camera")
			camera.reset_smoothing()
			camera.force_update_scroll()
			scene.call("_resolve_focus")


func _reset_camera(player: Player) -> void:
	var camera: Camera2D = player.get_node("Camera")
	camera.reset_smoothing()
	camera.force_update_scroll()
