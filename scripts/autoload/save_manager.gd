## Laedt und speichert den Spielstand als versioniertes JSON.
##
## Autoload -- ueberall als `SaveManager` erreichbar.
extends Node

signal game_saved()
signal game_loaded()
signal save_failed(message: String)

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 2

var save_path: String = SAVE_PATH
var settings_path: String = SETTINGS_PATH
var _test_directory: String = ""
var _application_paused: bool = false
var _in_background: bool = false

var _has_save: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for flag in ["--test", "--playtest", "--smoketest", "--demo"]:
		if flag in OS.get_cmdline_user_args():
			_test_directory = "user://test_runs/%s_%d" % [flag.trim_prefix("--"), OS.get_process_id()]
			var error := DirAccess.make_dir_recursive_absolute(_test_directory)
			if error != OK:
				push_error("Testverzeichnis konnte nicht angelegt werden.")
				get_tree().quit(1)
				return
			save_path = _test_directory.path_join("savegame.json")
			settings_path = _test_directory.path_join("settings.json")
			break
	_has_save = FileAccess.file_exists(save_path)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"state": GameState.to_dict(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var message := "Spielstand konnte nicht gespeichert werden: %s" % error_string(FileAccess.get_open_error())
		push_error(message)
		save_failed.emit(message)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		var message := "Spielstand konnte nicht gespeichert werden: %s" % error_string(write_error)
		push_error(message)
		save_failed.emit(message)
		return false
	_has_save = true
	game_saved.emit()
	return true


## Laedt den Spielstand. Bei fehlender oder kaputter Datei bleibt der
## aktuelle Zustand unveraendert und es wird false zurueckgegeben.
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
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

	if not GameState.from_dict(_migrate(state, version)):
		return false
	game_loaded.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_has_save = false


## Hebt aeltere Spielstaende auf das aktuelle Format an.
func _migrate(state: Dictionary, from_version: int) -> Dictionary:
	# Version 0 hatte noch kein Upgrade-Dictionary.
	if from_version < 1 and not state.has("upgrade_levels"):
		state["upgrade_levels"] = {}
	if from_version < 2 and not state.has("home"):
		state["home"] = HomeData.starter().to_dict()
	return state


# --- Einstellungen ----------------------------------------------------------

func save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(settings_path):
		return {}
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}


func _notification(what: int) -> void:
	if not is_node_ready() or not _test_directory.is_empty():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if not _in_background:
			if GameState.simulation_active:
				save_game()
			_application_paused = not get_tree().paused
			_in_background = true
			get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if _application_paused:
			get_tree().paused = false
		_application_paused = false
		_in_background = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _exit_tree() -> void:
	if not _test_directory.is_empty():
		for path in [save_path, settings_path]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(_test_directory)
