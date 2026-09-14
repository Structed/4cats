## Durchlauf durch alle Szenen und Interaktionen.
##
## Aufruf:
##   godot --headless --path . -- --smoketest
##   godot --headless --path . -- --smoketest --suite=home
##
## Zweck ist nicht, Spielregeln zu pruefen -- das machen test_gameplay.gd und
## test_playthrough.gd. Hier geht es darum, jede Szene und jeden Knopf einmal
## anzufassen, damit Skriptfehler auffallen, die nur bei Interaktion auftreten:
## fehlende Knoten, Zugriffe auf bereits freigegebene Objekte, kaputte Signale.
##
## Alle Fehler und Warnungen der Engine landen dabei in der Ausgabe und werden
## am Ende gezaehlt.
##
## Die Pruefungen selbst liegen in tools/smoke/. Diese Datei startet sie nur --
## ein neuer Durchlauf ist eine neue Datei dort und eine Zeile hier.
extends Node

## Reihenfolge ist bedeutsam: die Suiten bauen aufeinander auf und
## hinterlassen Spielstaende, mit denen die spaeteren weiterarbeiten.
const SUITES := {
	"menu": preload("res://tools/smoke/smoke_menu.gd"),
	"analytics": preload("res://tools/smoke/smoke_analytics.gd"),
	"home": preload("res://tools/smoke/smoke_home.gd"),
	"rescue": preload("res://tools/smoke/smoke_rescue.gd"),
	"flow": preload("res://tools/smoke/smoke_flow.gd"),
}

var _failures: PackedStringArray = []


func _ready() -> void:
	# An die Wurzel haengen, nicht an die Startszene. Sonst nimmt uns der erste
	# Szenenwechsel mit ins Grab, und danach ist get_tree() null.
	call_deferred("_reparent_to_root")


func _reparent_to_root() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _run() -> void:
	var selection := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			selection = argument.trim_prefix("--suite=")
	var names: PackedStringArray = []
	if selection == "all":
		for name: String in SUITES:
			names.append(name)
	else:
		# Mehrere Namen sind erlaubt: --suite=menu,analytics
		for wanted in selection.split(",", false):
			if not SUITES.has(wanted):
				_failures.append("Unbekannte Oberflaechensuite: %s" % wanted)
				printerr("  [FEHLER] Unbekannte Oberflaechensuite: %s" % wanted)
				_finish()
				return
			names.append(wanted)
	for name in names:
		await _run_suite(name)
	_finish()


func _run_suite(name: String) -> void:
	var suite_script: GDScript = SUITES[name]
	var suite: SmokeSuite = suite_script.new()
	suite.name = "Smoke_" + name
	get_tree().root.add_child(suite)
	await suite.run()
	_failures.append_array(suite.failures)
	suite.queue_free()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("Durchlauf bestanden.")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FEHLGESCHLAGEN: %s" % failure)
		printerr("%d Pruefung(en) fehlgeschlagen." % _failures.size())
		get_tree().quit(1)
