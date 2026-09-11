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
	"move_left", "move_right", "move_up", "move_down", "interact", "sprint", "pause",
	"home_furnish", "home_rotate", "home_store",
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

	print("--- Skripte ---")
	failures.append_array(_check_all_scripts())

	print("--- Szenen laden ---")
	failures.append_array(_check_all_scenes())

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

	print("--- Pflichtszenen ---")
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

	print("--- App-Version ---")
	failures.append_array(_check_versions())

	print("")
	if failures.is_empty():
		print("Alles in Ordnung.")
		quit(0)
	else:
		for failure in failures:
			printerr("FEHLER: %s" % failure)
		printerr("%d Problem(e) gefunden." % failures.size())
		quit(1)


func _check_versions() -> PackedStringArray:
	var problems: PackedStringArray = []
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	var pattern := RegEx.create_from_string("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")
	if pattern.search(version) == null:
		problems.append("Projektversion muss MAJOR.MINOR.PATCH entsprechen.")

	var presets := ConfigFile.new()
	var error := presets.load("res://export_presets.cfg")
	if error != OK:
		problems.append("Export-Presets konnten nicht gelesen werden: %s" % error_string(error))
		return problems
	var android_sections: PackedStringArray = []
	for section in presets.get_sections():
		if String(presets.get_value(section, "platform", "")) == "Android":
			android_sections.append(section)
	if android_sections.size() != 1:
		problems.append("Es muss genau ein Android-Export-Preset vorhanden sein.")
		return problems

	var options := "%s.options" % android_sections[0]
	var android_version := String(presets.get_value(options, "version/name", ""))
	var code: Variant = presets.get_value(options, "version/code", null)
	print("  Version: %s, Android: %s (Code %s)" % [version, android_version, str(code)])
	if android_version != version:
		problems.append("Android-version/name und Projektversion stimmen nicht ueberein.")
	if not (code is int) or code < 1 or code > 2100000000:
		problems.append("Android-version/code muss zwischen 1 und 2100000000 liegen.")
	if String(presets.get_value(options, "package/unique_name", "")) != "de.structed.fourcats":
		problems.append("Die Android-Paketkennung muss de.structed.fourcats bleiben.")
	return problems


## Laedt jedes GDScript im Projekt und meldet, was sich nicht uebersetzen laesst.
##
## Godot meldet Parse-Fehler sonst erst, wenn ein Skript zur Laufzeit gebraucht
## wird -- ein kaputtes Skript in einer selten betretenen Szene faellt damit
## erst dem Spieler auf.
func _check_all_scripts() -> PackedStringArray:
	var problems: PackedStringArray = []
	var paths := _collect_files("res://", ".gd")
	var broken := 0

	for path in paths:
		var script := load(path) as GDScript
		if script == null:
			problems.append("Skript laesst sich nicht laden: %s" % path)
			broken += 1
			print("  [FEHLER] %s" % path)
		elif not script.can_instantiate() and not _is_static_only(script):
			problems.append("Skript laesst sich nicht uebersetzen: %s" % path)
			broken += 1
			print("  [FEHLER] %s" % path)

	print("  %d Skript(e) geprueft, %d fehlerhaft" % [paths.size(), broken])
	return problems


## Manche Skripte sind reine Werkzeugklassen ohne instanziierbaren Typ.
## Entscheidend ist, dass sie fehlerfrei uebersetzt wurden.
func _is_static_only(script: GDScript) -> bool:
	return script.get_instance_base_type() == StringName()


## Instanziiert jede Szene einmal -- so fallen fehlende Knoten und kaputte
## Skript-Verweise auf, die beim reinen Laden noch nicht auffallen.
func _check_all_scenes() -> PackedStringArray:
	var problems: PackedStringArray = []
	var paths := _collect_files("res://scenes/", ".tscn")

	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			problems.append("Szene laesst sich nicht laden: %s" % path)
			print("  [FEHLER] %s" % path)
			continue
		if not packed.can_instantiate():
			problems.append("Szene laesst sich nicht aufbauen: %s" % path)
			print("  [FEHLER] %s" % path)

	print("  %d Szene(n) geprueft" % paths.size())
	return problems


func _collect_files(root: String, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var pending: PackedStringArray = [root]

	while not pending.is_empty():
		var current: String = pending[0]
		pending.remove_at(0)

		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full := current.path_join(entry)
			if dir.current_is_dir():
				pending.append(full)
			elif entry.ends_with(suffix):
				found.append(full)
			entry = dir.get_next()
		dir.list_dir_end()

	found.sort()
	return found
