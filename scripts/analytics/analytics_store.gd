class_name AnalyticsStore
extends RefCounted

const VERSION := 1
const NOTICE_VERSION := 1
const MAX_EVENTS := 1000
const MAX_BYTES := 1024 * 1024
const MAX_AGE_MS := 7 * 24 * 60 * 60 * 1000

static var _scope_pattern := RegEx.create_from_string("^[0-9a-f]{64}$")

var path: String
var last_error: String = ""


func _init(file_path: String) -> void:
	path = file_path


static func empty_state(consent: String = "unknown") -> Dictionary:
	return {
		"version": VERSION, "notice_version": NOTICE_VERSION, "consent": consent,
		"distinct_id": "", "scope": "", "queue": [],
	}


func read_state() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		return empty_state()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Die Analyse-Einstellung konnte nicht gelesen werden."
		return empty_state()
	if file.get_length() > MAX_BYTES + 4096:
		file.close()
		last_error = "Die Analyse-Datei ist zu groß. Die Nutzungsanalyse bleibt aus."
		return empty_state()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or json.data is not Dictionary:
		last_error = "Die Analyse-Datei ist beschädigt. Die Nutzungsanalyse bleibt aus."
		return empty_state()
	var state: Dictionary = json.data
	if not valid_state(state):
		last_error = "Die Analyse-Datei ist ungültig. Die Nutzungsanalyse bleibt aus."
		return empty_state()
	return state


static func valid_state(state: Dictionary) -> bool:
	if state.size() != 6 or state.get("version") != VERSION \
			or state.get("notice_version") != NOTICE_VERSION \
			or state.get("consent") not in ["unknown", "granted", "denied"] \
			or state.get("distinct_id") is not String or state.get("scope") is not String \
			or state.get("queue") is not Array:
		return false
	var queue: Array = state["queue"]
	var distinct_id: String = state["distinct_id"]
	if state["consent"] != "granted":
		return distinct_id.is_empty() and queue.is_empty() and String(state["scope"]).is_empty()
	if not AnalyticsEvents.valid_uuid(distinct_id) or queue.size() > MAX_EVENTS \
			or _scope_pattern.search(state["scope"]) == null:
		return false
	for entry: Variant in queue:
		if entry is not Dictionary or entry.size() != 2 \
				or entry.get("utc_ms") is not float and entry.get("utc_ms") is not int \
				or entry.get("payload") is not Dictionary:
			return false
		var utc_ms: float = float(entry["utc_ms"])
		if not is_finite(utc_ms) or utc_ms < 0 or utc_ms > 253402300799999 \
				or utc_ms != floor(utc_ms) \
				or not AnalyticsEvents.valid_payload(entry["payload"], distinct_id):
			return false
		var payload: Dictionary = entry["payload"]
		if payload["timestamp"] != AnalyticsEvents.timestamp(int(utc_ms)):
			return false
	return JSON.stringify(queue).to_utf8_buffer().size() <= MAX_BYTES


func write_state(state: Dictionary) -> bool:
	last_error = ""
	if not valid_state(state):
		last_error = "Ungültige Analysedaten wurden nicht gespeichert."
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Die Analyse-Einstellung konnte nicht gespeichert werden."
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		last_error = "Die Analyse-Einstellung konnte nicht sicher gespeichert werden."
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		return false
	return true


static func prune(queue: Array, utc_ms: int) -> int:
	var removed := 0
	for index in range(queue.size() - 1, -1, -1):
		var entry: Dictionary = queue[index]
		if utc_ms - int(entry["utc_ms"]) >= MAX_AGE_MS:
			queue.remove_at(index)
			removed += 1
	while queue.size() > MAX_EVENTS:
		queue.pop_front()
		removed += 1
	while not queue.is_empty() and JSON.stringify(queue).to_utf8_buffer().size() > MAX_BYTES:
		queue.pop_front()
		removed += 1
	return removed
