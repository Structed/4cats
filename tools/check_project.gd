## Kleiner Selbsttest fuer die Projektkonfiguration.
##
## Aufruf:
##   godot --headless --path . --script res://tools/check_project.gd
##
## Prueft, dass alle erwarteten Eingabe-Aktionen, Autoloads und Szenen
## vorhanden sind. Gibt bei einem Fehler den Exit-Code 1 zurueck, damit
## sich das Skript auch in einer CI-Pipeline verwenden laesst.
extends SceneTree

const REQUIRED_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down", "interact", "pause",
]

const REQUIRED_AUTOLOADS: PackedStringArray = [
	"GameState", "SaveManager", "AudioManager", "SceneRouter",
]

const REQUIRED_SCENES: PackedStringArray = [
	"res://scenes/main/main.tscn",
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/home/home_scene.tscn",
	"res://scenes/rescue/rescue_level.tscn",
]


func _initialize() -> void:
	var failures: PackedStringArray = []

	print("--- Eingabe-Aktionen ---")
	for action in REQUIRED_ACTIONS:
		var ok := InputMap.has_action(action)
		var events: Array = InputMap.action_get_events(action) if ok else []
		print("  %s %s (%d Ereignisse)" % ["[ok]  " if ok else "[FEHLT]", action, events.size()])
		if not ok:
			failures.append("Eingabe-Aktion fehlt: %s" % action)
		elif events.is_empty():
			failures.append("Eingabe-Aktion ohne Tastenbelegung: %s" % action)

	print("--- Autoloads ---")
	for autoload_name in REQUIRED_AUTOLOADS:
		var key := "autoload/%s" % autoload_name
		var ok := ProjectSettings.has_setting(key)
		print("  %s %s" % ["[ok]  " if ok else "[FEHLT]", autoload_name])
		if not ok:
			failures.append("Autoload fehlt: %s" % autoload_name)

	print("--- Szenen ---")
	for scene_path in REQUIRED_SCENES:
		var ok := ResourceLoader.exists(scene_path)
		print("  %s %s" % ["[ok]  " if ok else "[FEHLT]", scene_path])
		if not ok:
			failures.append("Szene fehlt: %s" % scene_path)

	print("--- Rendering ---")
	var method := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	print("  Methode: %s" % method)
	if method != "gl_compatibility":
		failures.append("Renderer sollte gl_compatibility sein, ist aber '%s'." % method)

	print("")
	if failures.is_empty():
		print("Alles in Ordnung.")
		quit(0)
	else:
		for failure in failures:
			printerr("FEHLER: %s" % failure)
		printerr("%d Problem(e) gefunden." % failures.size())
		quit(1)
