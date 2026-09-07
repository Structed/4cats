## Laedt und speichert den Spielstand als versioniertes JSON.
##
## Autoload -- ueberall als `SaveManager` erreichbar.
extends Node

signal game_saved()
signal game_loaded()

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1

var _has_save: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_has_save = FileAccess.file_exists(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"state": GameState.to_dict(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Spielstand konnte nicht geschrieben werden: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_has_save = true
	game_saved.emit()
	return true


## Laedt den Spielstand. Bei fehlender oder kaputter Datei bleibt der
## aktuelle Zustand unveraendert und es wird false zurueckgegeben.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Spielstand nicht lesbar, starte neu.")
		return false
	var text := file.get_as_text()
	file.close()

	# JSON-Instanz statt JSON.parse_string: so bleibt ein beschaedigter
	# Spielstand eine normale Fehlermeldung und keine Engine-Fehlerausgabe.
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Spielstand ist beschaedigt (Zeile %d: %s), starte neu." % [
			json.get_error_line(), json.get_error_message()
		])
		return false

	var parsed: Variant = json.data
	if parsed is not Dictionary:
		push_warning("Spielstand hat ein unerwartetes Format, starte neu.")
		return false

	var payload: Dictionary = parsed
	var version := int(payload.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("Spielstand stammt aus einer neueren Version, wird ignoriert.")
		return false

	var state: Variant = payload.get("state", {})
	if state is not Dictionary:
		return false

	GameState.from_dict(_migrate(state, version))
	game_loaded.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_has_save = false


## Hebt aeltere Spielstaende auf das aktuelle Format an.
func _migrate(state: Dictionary, from_version: int) -> Dictionary:
	# Version 0 hatte noch kein Upgrade-Dictionary.
	if from_version < 1 and not state.has("upgrade_levels"):
		state["upgrade_levels"] = {}
	return state


# --- Einstellungen ----------------------------------------------------------

func save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}
