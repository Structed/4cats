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
		if argument == "--home-preview=furnish" and scene.has_method("_open_modal"):
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
