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
