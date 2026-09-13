extends Node

signal changed()
signal failed(message: String)

const PLAYER_ACTIONS := ["interact", "sprint", "home_furnish", "home_rotate", "home_store"]
const DEV_FLAGS := ["--test", "--playtest", "--smoketest", "--demo", "--touch-preview"]
const DEV_PREFIXES := ["--start=", "--screenshot=", "--home-preview=", "--menu-preview="]
const MAX_FRAME_GAP_MS := 5000

var last_error: String = ""
var _available: bool = false
var _storage_failed: bool = false
var _store: AnalyticsStore
var _state: Dictionary = AnalyticsStore.empty_state()
var _clock := PlaytimeTracker.new()
var _client: PostHogClient
var _focused: bool = true
var _app_paused: bool = false
var _foreground: bool = true
var _last_checkpoint: int = 0
var _privacy_contact: String = ""
var _scope: String = ""
var _queue_warning: bool = false
var _previous_tick_ms: int = 0
var _platform: String = OS.get_name()
var _now: Callable = Time.get_ticks_msec
var _utc: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not runtime_allowed() or not bool(ProjectSettings.get_setting("analytics/enabled", false)):
		return
	var token := String(ProjectSettings.get_setting("analytics/project_token", ""))
	var contact := String(ProjectSettings.get_setting("analytics/privacy_contact", ""))
	if token.is_empty() or contact.strip_edges().is_empty():
		_report("Die Nutzungsanalyse ist nicht vollständig konfiguriert und bleibt aus.")
		return
	var client := PostHogClient.new()
	client.project_token = token
	_initialize(SaveManager.save_path.get_base_dir().path_join("analytics.json"), contact, client)
	_focused = DisplayServer.window_is_focused()
	_foreground = _focused
	_connect_game()


static func runtime_allowed() -> bool:
	if OS.has_feature("editor") or OS.has_feature("debug") \
			or DisplayServer.get_name() == "headless" or OS.get_name() not in ["Windows", "Android"]:
		return false
	return not is_development_run(OS.get_cmdline_user_args())


static func is_development_run(arguments: PackedStringArray) -> bool:
	for argument in arguments:
		if argument in DEV_FLAGS:
			return true
		for prefix: String in DEV_PREFIXES:
			if argument.begins_with(prefix):
				return true
	return false


func _initialize(path: String, contact: String, client: PostHogClient) -> void:
	_store = AnalyticsStore.new(path)
	_state = _store.read_state()
	_privacy_contact = contact
	_scope = JSON.stringify([client.project_token, contact, AnalyticsStore.NOTICE_VERSION]).sha256_text()
	_client = client
	add_child(_client)
	_client.accepted.connect(_on_accepted)
	_client.diagnostic.connect(_report)
	_available = true
	_last_checkpoint = _now.call()
	_previous_tick_ms = _last_checkpoint
	if not _store.last_error.is_empty():
		_report(_store.last_error)
	if _state["consent"] == "granted" and _state["scope"] != _scope:
		_state = AnalyticsStore.empty_state()
		_persist()
	if has_consent():
		_prune()
		_persist()


func _connect_game() -> void:
	GameState.cat_picked_up.connect(_on_cat_picked_up)
	GameState.cat_rescued.connect(_on_cat_rescued)
	GameState.cat_adopted.connect(_on_cat_adopted)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.home_item_purchased.connect(_on_home_item_purchased)
	SceneRouter.scene_changed.connect(_on_scene_changed)


func is_available() -> bool:
	return _available


func has_consent() -> bool:
	return _available and not _storage_failed and _state["consent"] == "granted"


func needs_consent() -> bool:
	return _available and _state["consent"] == "unknown"


func set_consent(granted: bool) -> bool:
	if not _available:
		_report("Dieser Build unterstützt keine Nutzungsanalyse.")
		return false
	_client.cancel()
	_clock.reset()
	_storage_failed = false
	last_error = ""
	_queue_warning = false
	var candidate := AnalyticsStore.empty_state("granted" if granted else "denied")
	if granted:
		candidate["distinct_id"] = AnalyticsEvents.uuid()
		candidate["scope"] = _scope
	# Revocation takes effect even when its persistence fails.
	_state = AnalyticsStore.empty_state("denied")
	if not _store.write_state(candidate):
		_storage_failed = true
		_report(_store.last_error + " Sie bleibt jetzt aus; die Änderung ist nicht gespeichert.")
		changed.emit()
		return false
	_state = candidate
	_last_checkpoint = _now.call()
	_previous_tick_ms = _last_checkpoint
	changed.emit()
	return true


func privacy_text() -> String:
	var text := "Nur mit deiner Einwilligung senden wir Spielzeit, Spielversion, Plattform und "
	text += "Spielaktionen an PostHog Cloud EU (Frankfurt). Dazu gehören Aufheben drinnen/draußen, "
	text += "tatsächliche Rettungen, Vermittlungen und Käufe mit Spielmünzen.\n\n"
	text += "Eine zufällige Kennung verbindet die Daten dieser Installation. Es werden keine "
	text += "Namen, Werbe-IDs, Bewegungsverläufe, Eingaben oder Bildschirmaufnahmen gesendet. "
	text += "Die Daten sind pseudonym, nicht vollständig anonym. PostHog sieht technisch deine "
	text += "IP-Adresse; deren Speicherung und die Standortanreicherung müssen deaktiviert sein.\n\n"
	text += "Spielzeit zählt ohne Pause, Menüs und Hintergrund und stoppt nach zwei Minuten "
	text += "ohne Spielaktion. Du kannst die Einwilligung hier jederzeit widerrufen. "
	text += "Dann stoppen neue Übertragungen und die lokale Kennung und Warteschlange werden gelöscht. "
	text += "Bereits empfangene Serverdaten werden dadurch nicht automatisch gelöscht. "
	text += "Die Aufbewahrung im vorgesehenen kostenlosen Tarif beträgt ein Jahr.\n\n"
	if not _privacy_contact.is_empty():
		text += "Verantwortlich / Kontakt für Datenschutz und Löschanfragen:\n" + _privacy_contact
	else:
		text += "Dieser Entwicklungs- oder unkonfigurierte Build sendet keine Nutzungsdaten."
	if has_consent():
		text += "\n\nDeine Kennung für eine Löschanfrage (vor dem Widerruf notieren):\n"
		text += String(_state["distinct_id"])
	return text


func _process(_delta: float) -> void:
	if not has_consent():
		return
	var activity := false
	if _eligible():
		activity = not Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx()
		for action: String in PLAYER_ACTIONS:
			activity = activity or Input.is_action_just_pressed(action)
	_sample(activity)
	var now_ms := _previous_tick_ms
	if now_ms - _last_checkpoint >= PlaytimeTracker.CHECKPOINT_MS:
		_enqueue_clock(_clock.checkpoint(now_ms, _utc.call()))
		_last_checkpoint = now_ms
		_prune()
		_persist()
	if has_consent():
		var queue: Array = _state["queue"]
		_client.tick(queue, now_ms, queue.size() >= PostHogClient.BATCH_SIZE)


func _context() -> String:
	var current := get_tree().current_scene if is_inside_tree() else null
	if current == null:
		return ""
	match current.scene_file_path:
		SceneRouter.HOME: return "home"
		SceneRouter.RESCUE: return "rescue"
	return ""


func _eligible() -> bool:
	return _foreground and not _context().is_empty() and GameState.simulation_active \
		and not get_tree().paused and not SceneRouter.is_transitioning()


func _sample(activity: bool) -> void:
	if not has_consent():
		return
	var context := _context()
	var eligible := _eligible()
	var now_ms: int = _now.call()
	var utc_ms: int = _utc.call()
	_prepare_tick(now_ms, utc_ms)
	if not has_consent():
		return
	# Entering actual gameplay starts the first interval; menu-only visits do not.
	activity = activity or eligible and _clock.session_id.is_empty()
	_enqueue_clock(_clock.update(now_ms, utc_ms, eligible, activity, context))


func _prepare_tick(now_ms: int, utc_ms: int) -> void:
	var gap := now_ms - _previous_tick_ms
	if gap > MAX_FRAME_GAP_MS:
		# A suspended or stalled process did not simulate the missing frames.
		_enqueue_clock(_clock.suspend(_previous_tick_ms, utc_ms - gap))
		_clock.resume(now_ms, utc_ms)
	_previous_tick_ms = now_ms


func player_activity(first_gameplay_action: bool = false) -> void:
	if has_consent() and _foreground and (first_gameplay_action or not _clock.session_id.is_empty()):
		_sample(true)


func game_started(kind: String) -> void:
	if not has_consent():
		return
	_sample(true)
	capture("game_started", {"kind": kind})


func capture(event: String, properties: Dictionary = {}) -> void:
	if not has_consent():
		return
	if not AnalyticsEvents.valid_properties(event, properties):
		_report("Ein ungültiges Analyseereignis wurde verworfen.")
		return
	if _clock.session_id.is_empty():
		return
	_enqueue(event, properties, _clock.session_id, _utc.call())


func _enqueue_clock(events: Array[Dictionary]) -> void:
	for event in events:
		_enqueue(event["event"], event["properties"], event["game_session_id"], int(event["utc_ms"]))


func _enqueue(event: String, specific: Dictionary, session_id: String, utc_ms: int) -> void:
	if not has_consent():
		return
	var properties := specific.duplicate()
	properties.merge({
		"event_id": AnalyticsEvents.uuid(), "distinct_id": _state["distinct_id"],
		"game_session_id": session_id, "schema_version": AnalyticsEvents.SCHEMA_VERSION,
		"app_version": String(ProjectSettings.get_setting("application/config/version")),
		"platform": _platform,
		"$process_person_profile": false,
	})
	var payload := {"event": event, "properties": properties, "timestamp": AnalyticsEvents.timestamp(utc_ms)}
	if not AnalyticsEvents.valid_payload(payload, String(_state["distinct_id"])):
		_report("Ein ungültiges Analyseereignis wurde nicht gespeichert.")
		return
	var queue: Array = _state["queue"]
	queue.append({"utc_ms": utc_ms, "payload": payload})
	_prune()
	_persist()


func _prune() -> void:
	var queue: Array = _state["queue"]
	if AnalyticsStore.prune(queue, _utc.call()) > 0 and not _queue_warning:
		_queue_warning = true
		_report("Nutzungsanalyse: Alte oder überzählige Offline-Ereignisse wurden verworfen.")


func _persist() -> bool:
	if _store.write_state(_state):
		return true
	_storage_failed = true
	_client.cancel()
	_clock.reset()
	_report(_store.last_error + " Die Nutzungsanalyse bleibt für diesen Lauf aus.")
	changed.emit()
	return false


func _on_accepted(ids: Array[String]) -> void:
	if not has_consent():
		return
	var queue: Array = _state["queue"]
	for index in range(queue.size() - 1, -1, -1):
		var entry: Dictionary = queue[index]
		var payload: Dictionary = entry["payload"]
		var properties: Dictionary = payload["properties"]
		if String(properties["event_id"]) in ids:
			queue.remove_at(index)
	_persist()


func _on_cat_picked_up(_cat: CatData, location: String) -> void:
	player_activity(true)
	capture("cat_picked_up", {"pickup_location": location})


func _on_cat_rescued(_cat: CatData) -> void:
	capture("cat_rescued")


func _on_cat_adopted(_cat: CatData, reward: int) -> void:
	capture("cat_adopted", {"reward": reward})


func _on_upgrade_purchased(upgrade_id: String, level: int) -> void:
	player_activity(true)
	var definition: Dictionary = GameState.UPGRADES[upgrade_id]
	var prices: Array = definition["costs"]
	capture("upgrade_purchased", {"upgrade_id": upgrade_id, "level": level, "price": int(prices[level - 1])})


func _on_home_item_purchased(kind: String, price: int) -> void:
	player_activity(true)
	capture("home_item_purchased", {"kind": kind, "price": price})


func _on_scene_changed(path: String) -> void:
	if path in [SceneRouter.HOME, SceneRouter.RESCUE] and has_consent():
		_sample(_foreground)
		capture("scene_entered", {"scene": "home" if path == SceneRouter.HOME else "rescue"})


func _notification(what: int) -> void:
	if _store == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_app_paused = true
		NOTIFICATION_APPLICATION_RESUMED:
			_app_paused = false
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_focused = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			_finish_interval()
	var foreground := _focused and not _app_paused
	if foreground != _foreground:
		_foreground = foreground
		if has_consent():
			if foreground:
				_clock.resume(_now.call(), _utc.call())
				_previous_tick_ms = _now.call()
			else:
				_suspend_interval()


func _suspend_interval() -> void:
	var now_ms: int = _now.call()
	var utc_ms: int = _utc.call()
	_prepare_tick(now_ms, utc_ms)
	if has_consent():
		_enqueue_clock(_clock.suspend(now_ms, utc_ms))


func _finish_interval() -> void:
	if has_consent():
		_suspend_interval()
		if has_consent():
			_persist()


func _exit_tree() -> void:
	_finish_interval()
	if _client != null and is_instance_valid(_client):
		_client.cancel()


func _report(message: String) -> void:
	last_error = message
	push_warning(message)
	failed.emit(message)
