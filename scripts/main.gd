## Startpunkt des Spiels.
##
## Laedt einen vorhandenen Spielstand und leitet dann ins Hauptmenue weiter.
##
## Fuer die Entwicklung gibt es zusaetzliche Startparameter. Die dazugehoerigen
## Skripte liegen unter `scripts/dev/` und `tools/` und werden beim Export
## bewusst weggelassen -- deshalb werden sie zur Laufzeit geladen und ihr
## Fehlen wird sauber abgefangen:
##   godot --path . -- --start=rescue
##   godot --path . -- --start=home --demo
##   godot --path . -- --start=home --screenshot=C:/temp/bild.png
##   godot --headless --path . -- --test
extends Node

const START_SCENES := {
	"menu": SceneRouter.MAIN_MENU,
	"home": SceneRouter.HOME,
	"rescue": SceneRouter.RESCUE,
}

const SCREENSHOT_CAPTURE_PATH := "res://scripts/dev/screenshot_capture.gd"
const GAMEPLAY_TESTS_PATH := "res://tools/test_gameplay.gd"
const PLAYTHROUGH_TEST_PATH := "res://tools/test_playthrough.gd"
const SMOKE_TEST_PATH := "res://tools/test_smoke.gd"
const DEMO_DATA_PATH := "res://scripts/dev/demo_data.gd"


func _ready() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()
	# Einen Frame warten, damit alle Autoloads sicher initialisiert sind.
	await get_tree().process_frame

	# Die Testlaeufe ersetzen den normalen Start.
	if _run_dev_entry_point("--test", GAMEPLAY_TESTS_PATH):
		return
	if _run_dev_entry_point("--playtest", PLAYTHROUGH_TEST_PATH):
		return
	if _run_dev_entry_point("--smoketest", SMOKE_TEST_PATH):
		return

	if _has_argument("--demo"):
		_spawn_dev_node(DEMO_DATA_PATH)

	_setup_screenshot()

	var target := _requested_start_scene()
	if target.is_empty():
		SceneRouter.goto_main_menu()
	else:
		SceneRouter.goto_scene(target)


## Wertet `--start=<szene>` aus den Kommandozeilenargumenten aus.
func _requested_start_scene() -> String:
	var key := _argument_value("--start=")
	if key.is_empty():
		return ""
	if START_SCENES.has(key):
		return String(START_SCENES[key])
	push_warning("Unbekannte Startszene: %s" % key)
	return ""


## Haengt bei `--screenshot=<pfad>` die Aufnahmehilfe ein.
func _setup_screenshot() -> void:
	var path := _argument_value("--screenshot=", false)
	if path.is_empty():
		return
	var capture := _load_dev_script(SCREENSHOT_CAPTURE_PATH)
	if capture == null:
		return
	var node: Node = capture.new()
	node.set("output_path", path)
	get_tree().root.add_child.call_deferred(node)


## Laedt ein Entwicklungsskript, sofern es im Build enthalten ist.
func _load_dev_script(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		push_warning("Entwicklungsskript ist in diesem Build nicht enthalten: %s" % path)
		return null
	var script := load(path) as GDScript
	# Bei einem Parse-Fehler liefert load() ein Skript, das sich nicht
	# instanziieren laesst. Ohne diese Pruefung liefe ein Testaufruf still ins
	# normale Spiel weiter -- headless haengt das dann endlos.
	if script == null or not script.can_instantiate():
		push_error("Entwicklungsskript laesst sich nicht laden (Parse-Fehler?): %s" % path)
		return null
	return script


## Erzeugt einen Knoten aus einem Entwicklungsskript und haengt ihn ein.
func _spawn_dev_node(path: String) -> Node:
	var script := _load_dev_script(path)
	if script == null:
		return null
	var node: Node = script.new()
	add_child(node)
	return node


## Bricht mit Fehlercode ab, wenn ein angefordertes Testskript nicht laeuft.
func _run_dev_entry_point(flag: String, path: String) -> bool:
	if not _has_argument(flag):
		return false
	if _spawn_dev_node(path) != null:
		return true
	printerr("Abbruch: %s konnte nicht gestartet werden." % flag)
	get_tree().quit(1)
	return true


func _argument_value(prefix: String, lowercase: bool = true) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			var value := argument.trim_prefix(prefix).strip_edges()
			return value.to_lower() if lowercase else value
	return ""


func _has_argument(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()
