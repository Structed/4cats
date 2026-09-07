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
const DEMO_DATA_PATH := "res://scripts/dev/demo_data.gd"


func _ready() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()
	# Einen Frame warten, damit alle Autoloads sicher initialisiert sind.
	await get_tree().process_frame

	# Der Testlauf ersetzt den normalen Start.
	if _has_argument("--test") and _spawn_dev_node(GAMEPLAY_TESTS_PATH) != null:
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
	return load(path) as GDScript


## Erzeugt einen Knoten aus einem Entwicklungsskript und haengt ihn ein.
func _spawn_dev_node(path: String) -> Node:
	var script := _load_dev_script(path)
	if script == null:
		return null
	var node: Node = script.new()
	add_child(node)
	return node


func _argument_value(prefix: String, lowercase: bool = true) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			var value := argument.trim_prefix(prefix).strip_edges()
			return value.to_lower() if lowercase else value
	return ""


func _has_argument(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()
