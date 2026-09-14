## Prueft, dass jeder benutzte Textschluessel in `locale/de.csv` steht.
##
## Ein Schluessel ohne Eintrag faellt sonst nirgends auf: Godot liefert
## einfach den Schluessel zurueck, und im Spiel steht dann "menu.new_game"
## statt "Neues Spiel". Genau das passiert, wenn zwei Zweige denselben
## Knopf hinzufuegen und nur einer die Zeile in der CSV mitbringt.
##
## Die Suite liest die Dateien vom Datentraeger, nicht aus einer gepflegten
## Liste -- eine neue Szene ist damit automatisch mit abgesichert.
extends RefCounted

const CSV_PATH := "res://locale/de.csv"
const SCENE_DIRS: PackedStringArray = ["res://scenes"]
const SCRIPT_DIRS: PackedStringArray = ["res://scripts"]

## Schluessel, die erst zur Laufzeit zusammengesetzt werden und deshalb in
## keiner Datei woertlich vorkommen.
const DYNAMIC_KEYS: PackedStringArray = []

var _failures: PackedStringArray = []


func run(_tree: SceneTree) -> PackedStringArray:
	print("--- Texte: Uebersetzungsschluessel ---")
	var known := _read_csv_keys()
	_check(not known.is_empty(), "Die Uebersetzungsdatei enthaelt Schluessel")

	var used := _collect_used_keys()
	_check(not used.is_empty(), "Die Szenen benutzen Textschluessel")

	var missing: PackedStringArray = []
	for key: String in used:
		if not known.has(key):
			missing.append("%s (%s)" % [key, String(used[key])])
	_check(missing.is_empty(),
		"Jeder benutzte Schluessel steht in locale/de.csv")
	for entry: String in missing:
		printerr("    ohne deutschen Text: %s" % entry)

	var unused: PackedStringArray = []
	for key: String in known:
		if not used.has(key) and not DYNAMIC_KEYS.has(key):
			unused.append(key)
	if not unused.is_empty():
		# Kein Fehler: eine ungenutzte Zeile stoert niemanden. Sie zu kennen
		# hilft aber beim Aufraeumen.
		print("  [hinweis] ungenutzte Zeilen: %s" % ", ".join(unused))

	_check(_resolves("menu.new_game", "Neues Spiel"),
		"Der Uebersetzungsdienst liefert den deutschen Text")
	_check(_resolves("menu.credits_text", "Idee, Game Design & Testing:\nRomy Maria Ebner"),
		"Auch mehrzeilige Texte kommen vollstaendig an")
	_check(UiKit.text("Münzen: 7") == "Münzen: 7",
		"Fertiger Text wird nicht als Schluessel missdeutet")
	_check(not UiKit.is_key("Nach Hause") and UiKit.is_key("hud.home"),
		"Schluessel und sichtbarer Text sind unterscheidbar")
	return _failures


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FEHLER", description])
	if not condition:
		_failures.append(description)


func _resolves(key: String, expected_start: String) -> bool:
	var value := UiKit.text(key)
	return value != key and value.begins_with(expected_start)


func _read_csv_keys() -> Dictionary:
	var keys: Dictionary = {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		_check(false, "locale/de.csv laesst sich lesen")
		return keys
	var first := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or String(row[0]).is_empty():
			continue
		if first:
			# Kopfzeile: keys,de
			first = false
			continue
		keys[String(row[0])] = String(row[1])
	file.close()
	return keys


## Schluessel -> Datei, in der er zuerst auftaucht.
func _collect_used_keys() -> Dictionary:
	var used: Dictionary = {}
	var scene_pattern := RegEx.new()
	scene_pattern.compile("^text = \"([^\"]*)\"")
	var script_pattern := RegEx.new()
	script_pattern.compile("\"([a-z][a-z0-9_]*(?:\\.[a-z0-9_]+)+)\"")

	for path: String in _files_under(SCENE_DIRS, ".tscn"):
		for line: String in _lines(path):
			var hit := scene_pattern.search(line)
			if hit == null:
				continue
			var value := hit.get_string(1)
			if UiKit.is_key(value) and not used.has(value):
				used[value] = path

	for path: String in _files_under(SCRIPT_DIRS, ".gd"):
		for line: String in _lines(path):
			# Nur Zeilen, die durch die Fabrik gehen. Sonst wuerden hier
			# Dateinamen wie "godot.log" als Schluessel gelten.
			if not line.contains("UiKit."):
				continue
			for hit: RegExMatch in script_pattern.search_all(line):
				var value := hit.get_string(1)
				if not used.has(value):
					used[value] = path
	return used


func _lines(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	return text.split("\n")


func _files_under(roots: PackedStringArray, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var pending: PackedStringArray = roots.duplicate()
	while not pending.is_empty():
		var current := pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
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
	return found
