extends RefCounted

const ManagerScript := preload("res://scripts/autoload/analytics_manager.gd")
const UTC_BASE := 1800000000000

class FakeTime:
	extends RefCounted
	var ticks: int = 0
	var utc: int = UTC_BASE

	func now_ms() -> int:
		return ticks

	func utc_ms() -> int:
		return utc

class RecordingClient:
	extends PostHogClient
	var requests: Array[Dictionary] = []
	var generations: Array[int] = []
	var submit_error: Error = OK

	func _submit(body: String, generation: int) -> Error:
		var parsed: Dictionary = JSON.parse_string(body)
		requests.append(parsed)
		generations.append(generation)
		return submit_error

	func respond(code: int, result: int = HTTPRequest.RESULT_SUCCESS, generation: int = -1) -> void:
		var current: int = generations.back() if generation < 0 else generation
		_complete(result, code, PackedStringArray(), PackedByteArray(), current)

class FailingStore:
	extends AnalyticsStore

	func write_state(_state: Dictionary) -> bool:
		last_error = "Simulierter Speicherfehler."
		return false

var _failures: PackedStringArray = []
var _paths: Array[String] = []


func run(_tree: SceneTree) -> PackedStringArray:
	print("--- Freiwillige Analytics ---")
	_test_runtime_flags()
	_test_clock()
	_test_storage()
	_test_transport()
	_test_consent_and_gameplay()
	_test_first_paused_purchase()
	_test_delayed_lifecycle()
	_test_manager_failures()
	for path in _paths:
		for candidate in [path, path + ".tmp"]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(candidate)
	return _failures


static func make_ui_service(path: String) -> Node:
	var manager := ManagerScript.new()
	var client := RecordingClient.new()
	client.project_token = "test-project-token"
	manager._platform = "Windows"
	manager._initialize(path, "Testkontakt (keine echte Erfassung)", client)
	return manager


func _test_runtime_flags() -> void:
	for flag: String in [
		"--test", "--playtest", "--smoketest", "--demo", "--touch-preview",
		"--start=home", "--screenshot=shot.png", "--home-preview=cat", "--menu-preview=analytics",
	]:
		_check(ManagerScript.is_development_run(PackedStringArray([flag])),
			"Entwicklungsparameter %s sperrt Produktionsdaten" % flag)
	_check(not ManagerScript.is_development_run(PackedStringArray()),
		"Normaler Start wird nicht mit einem Entwicklungslauf verwechselt")


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["[ok]   " if condition else "[FEHLER]", description])
	if not condition:
		_failures.append(description)


func _time(events: Array[Dictionary]) -> int:
	var total := 0
	for event in events:
		if event["event"] == "playtime":
			var properties: Dictionary = event["properties"]
			total += roundi(float(properties["duration_seconds"]) * 1000)
	return total


func _test_clock() -> void:
	var clock := PlaytimeTracker.new()
	var first := clock.update(0, UTC_BASE, true, true, "home")
	var original := clock.session_id
	_check(first.size() == 1 and first[0]["event"] == "play_session_started",
		"Erste Spielaktivitaet beginnt eine eigene Sitzung")
	var total := _time(clock.update(119000, UTC_BASE + 119000, true, false, "home"))
	total += _time(clock.checkpoint(119000, UTC_BASE + 119000))
	_check(total == 119000, "119 Sekunden Warten zaehlen voll")
	total += _time(clock.update(120000, UTC_BASE + 120000, true, false, "home"))
	total += _time(clock.checkpoint(120000, UTC_BASE + 120000))
	_check(total == 120000, "Genau 120 Sekunden zaehlen vor AFK")
	total += _time(clock.update(121000, UTC_BASE + 121000, true, false, "home"))
	total += _time(clock.checkpoint(121000, UTC_BASE + 121000))
	_check(total == 120000, "Die 121. Sekunde ohne Eingabe zaehlt nicht")
	_check(_time(clock.update(130000, UTC_BASE + 130000, true, true, "home")) == 0
		and clock.session_id == original, "Eingabe nach kurzer AFK-Luecke zaehlt nichts nach")
	clock.update(135000, UTC_BASE + 135000, true, false, "home")
	_check(_time(clock.checkpoint(135000, UTC_BASE + 135000)) == 5000,
		"Nach der neuen Eingabe laeuft die Spielzeit weiter")

	clock.reset()
	clock.update(0, UTC_BASE, true, true, "rescue")
	total = 0
	for second in range(1, 241):
		total += _time(clock.update(second * 1000, UTC_BASE + second * 1000, true, true, "rescue"))
	total += _time(clock.checkpoint(240000, UTC_BASE + 240000))
	_check(total == 240000, "Gehaltene Bewegung erneuert Aktivitaet ohne Tastenwiederholung")

	clock.reset()
	clock.update(0, UTC_BASE, true, true, "home")
	var home := clock.update(5000, UTC_BASE + 5000, false, false, "home")
	_check(_time(home) == 5000 and home[0]["properties"]["scene"] == "home",
		"Pause sichert das letzte Teilintervall im richtigen Kontext")
	_check(_time(clock.update(20000, UTC_BASE + 20000, false, false, "")) == 0,
		"Pause, Katalog, Menue oder Blende zaehlen keine Zeit")
	clock.update(20000, UTC_BASE + 20000, true, true, "rescue")
	var rescue := clock.update(23000, UTC_BASE + 23000, false, false, "rescue")
	_check(_time(rescue) == 3000 and rescue[0]["properties"]["scene"] == "rescue",
		"Rettungszeit wird nicht dem Zuhause zugerechnet")
	_check(_time(clock.checkpoint(23000, UTC_BASE + 23000)) == 0,
		"Wiederholte Checkpoints verdoppeln keine Zeit")

	clock.reset()
	clock.update(0, UTC_BASE, true, true, "home")
	original = clock.session_id
	clock.update(1799999, UTC_BASE + 1799999, true, false, "home")
	_check(clock.session_id == original, "Automatische Zeit-Updates erzeugen keine neue Sitzung")
	var expired := clock.update(1800000, UTC_BASE + 1800000, true, true, "home")
	_check(clock.session_id != original and expired.back()["event"] == "play_session_started",
		"Erneute Aktivitaet nach genau 30 Minuten startet eine Sitzung")
	var before_limit := PlaytimeTracker.new()
	before_limit.update(0, UTC_BASE, true, true, "home")
	original = before_limit.session_id
	before_limit.update(1799999, UTC_BASE + 1799999, true, true, "home")
	_check(before_limit.session_id == original, "Vor 30 Minuten bleibt die Sitzung erhalten")

	clock.reset()
	clock.update(0, UTC_BASE, true, true, "home")
	original = clock.session_id
	_check(_time(clock.suspend(5000, UTC_BASE + 5000)) == 5000, "Suspend sichert nur bisherige Spielzeit")
	clock.resume(5000, UTC_BASE + 185000)
	clock.update(6000, UTC_BASE + 186000, true, false, "home")
	_check(_time(clock.checkpoint(7000, UTC_BASE + 187000)) == 0,
		"Eingefrorene Android-Uhr zaehlt nach Hintergrund keine AFK-Zeit nach")
	clock.suspend(7000, UTC_BASE + 187000)
	clock.resume(7000, UTC_BASE + 2000000)
	clock.update(8000, UTC_BASE + 2001000, true, true, "home")
	_check(clock.session_id != original, "Langer Suspend erzeugt auch bei stehender Uhr eine neue Sitzung")

	clock.reset()
	clock.update(0, UTC_BASE, true, true, "home")
	clock.update(2500, UTC_BASE - 100000, true, false, "home")
	_check(_time(clock.checkpoint(2500, UTC_BASE - 100000)) == 2500,
		"Systemuhr-Aenderungen beeinflussen die monotone Spielzeit nicht")
	clock.reset()
	clock.update(0, UTC_BASE, true, true, "home")
	clock.update(1000, UTC_BASE + 1000, false, false, "home")
	_check(clock.checkpoint(9000, UTC_BASE + 9000).is_empty(), "Beendete Intervalle bleiben beendet")


func _path(name: String) -> String:
	var result := SaveManager.save_path.get_base_dir().path_join("analytics_" + name + ".json")
	_paths.append(result)
	return result


func _entry(id: String, time: int = UTC_BASE) -> Dictionary:
	return {
		"utc_ms": time,
		"payload": {
			"event": "cat_rescued", "timestamp": AnalyticsEvents.timestamp(time),
			"properties": {
				"distinct_id": id, "event_id": AnalyticsEvents.uuid(), "game_session_id": AnalyticsEvents.uuid(),
				"schema_version": 1, "app_version": "0.1.0", "platform": "Windows",
				"$process_person_profile": false,
			},
		},
	}


func _test_storage() -> void:
	var path := _path("store")
	var store := AnalyticsStore.new(path)
	_check(store.read_state() == AnalyticsStore.empty_state(), "Fehlende Datei bedeutet keine Einwilligung")
	var state := AnalyticsStore.empty_state("granted")
	var id := AnalyticsEvents.uuid()
	state["distinct_id"] = id
	state["scope"] = "0".repeat(64)
	state["queue"] = [_entry(id)]
	_check(store.write_state(state), "Analytics werden atomar gespeichert")
	var loaded := store.read_state()
	_check(loaded["consent"] == "granted" and loaded["distinct_id"] == id
		and loaded["queue"].size() == 1
		and loaded["queue"][0]["utc_ms"] == UTC_BASE
		and loaded["queue"][0]["payload"]["timestamp"] == state["queue"][0]["payload"]["timestamp"]
		and loaded["queue"][0]["payload"]["properties"]["event_id"] == state["queue"][0]["payload"]["properties"]["event_id"],
		"Einwilligung, Kennung, Ereigniszeit und unveraenderte Ereignis-ID ueberstehen Neustart")
	_check(store.write_state(AnalyticsStore.empty_state("denied"))
		and store.read_state()["distinct_id"] == "", "Widerruf ueberschreibt die bestehende Datei ohne Kennung")
	var bad := state.duplicate(true)
	bad["queue"][0]["payload"]["properties"]["cat_name"] = "Nicht erlaubt"
	_check(not AnalyticsStore.valid_state(bad), "Unbekannte persoenliche Eigenschaften werden abgelehnt")
	bad = state.duplicate(true)
	bad["queue"][0]["payload"]["properties"]["$process_person_profile"] = true
	_check(not AnalyticsStore.valid_state(bad), "Geladene Ereignisse duerfen keine Personenprofile aktivieren")
	bad = state.duplicate(true)
	bad["consent"] = "denied"
	_check(not AnalyticsStore.valid_state(bad), "Ohne Einwilligung sind Kennung und Queue ungueltig")
	bad = state.duplicate(true)
	bad["queue"][0]["utc_ms"] = UTC_BASE + 1
	_check(not AnalyticsStore.valid_state(bad), "Ereigniszeit und Queue-Alter muessen zusammenpassen")
	var queue: Array = [_entry(id, UTC_BASE - AnalyticsStore.MAX_AGE_MS), _entry(id)]
	_check(AnalyticsStore.prune(queue, UTC_BASE) == 1 and queue.size() == 1,
		"Offline-Ereignisse verfallen nach sieben Tagen")
	queue.clear()
	for index in AnalyticsStore.MAX_EVENTS + 1:
		queue.append(_entry(id, UTC_BASE + index))
	_check(AnalyticsStore.prune(queue, UTC_BASE) == 1 and queue.size() == AnalyticsStore.MAX_EVENTS
		and queue[0]["utc_ms"] == UTC_BASE + 1, "Queue behält hoechstens 1000 neueste Ereignisse")
	queue = [{"utc_ms": UTC_BASE, "payload": {"oversize": "x".repeat(AnalyticsStore.MAX_BYTES)}}]
	_check(AnalyticsStore.prune(queue, UTC_BASE) == 1 and queue.is_empty(), "Queue ist auch nach Bytes begrenzt")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	_check(store.read_state()["consent"] == "unknown" and not store.last_error.is_empty(),
		"Beschaedigte Dateien bleiben geschlossen statt Einwilligung zu erraten")
	var impossible := AnalyticsStore.new(path.path_join("missing.json"))
	_check(not impossible.write_state(state) and not impossible.last_error.is_empty(),
		"Schreibfehler werden nicht als Erfolg ausgegeben")
	_check(not AnalyticsEvents.valid_properties("cat_picked_up", {})
		and not AnalyticsEvents.valid_properties("cat_picked_up", {"pickup_location": "unknown"}),
		"Pickup-Ort ist verpflichtend und auf indoor/outdoor beschraenkt")


func _test_transport() -> void:
	var time := FakeTime.new()
	var client := RecordingClient.new()
	client.project_token = "test-project-token"
	client._now = time.now_ms
	var queue: Array = []
	var id := AnalyticsEvents.uuid()
	for index in 22:
		queue.append(_entry(id))
	client.tick(queue, 0)
	client.tick(queue, 0, true)
	_check(client.requests.size() == 1 and client.requests[0]["batch"].size() == 20,
		"Maximal ein Request mit hoechstens 20 Ereignissen")
	var first: Dictionary = client.requests[0]["batch"][0]
	client.respond(429)
	client.tick(queue, 4999, true)
	_check(client.requests.size() == 1, "Auch erzwungener Flush umgeht Backoff nicht")
	time.ticks = 5000
	client.tick(queue, time.ticks)
	_check(client.requests.size() == 2 and client.requests[1]["batch"][0] == first,
		"Retry behaelt Originalzeit und Ereignis-ID")
	var old_generation: int = client.generations.back()
	client.cancel()
	client.tick(queue, time.ticks)
	var in_flight := client._in_flight.duplicate()
	client.respond(200, HTTPRequest.RESULT_SUCCESS, old_generation)
	_check(client._in_flight == in_flight, "Verspaetete Antwort nach Widerruf bestaetigt keine neuen Ereignisse")
	client.respond(403)
	client.tick(queue, 999999, true)
	_check(client.requests.size() == 3 and client._permanent_failure, "Permanente Fehler verursachen keine Endlosschleife")
	client.cancel()
	client.submit_error = ERR_CANT_CONNECT
	client.tick(queue, time.ticks)
	_check(client._in_flight.is_empty() and client._failures == 1,
		"Auch sofortige Verbindungsfehler raeumen den laufenden Request auf")
	client.cancel()
	client.submit_error = OK
	for code in [408, 500, 503]:
		client.tick(queue, time.ticks)
		client.respond(code)
		_check(client._failures == 1 and not client._permanent_failure,
			"HTTP %d wird als wiederholbarer Fehler behandelt" % code)
		client.cancel()
	client.tick(queue, time.ticks)
	client.respond(0, HTTPRequest.RESULT_TIMEOUT)
	_check(client._failures == 1, "Timeout bleibt wiederholbar")
	client.cancel()
	client.tick(queue, time.ticks)
	client.respond(200)
	_check(client._in_flight.is_empty() and client._failures == 0,
		"Bestaetigte Batches geben den Transport wieder frei")
	client.free()


func _events(manager: Node, name: String, location: String = "") -> int:
	var state: Dictionary = manager.get("_state")
	var queue: Array = state["queue"]
	var count := 0
	for entry: Dictionary in queue:
		var payload: Dictionary = entry["payload"]
		var properties: Dictionary = payload["properties"]
		if payload["event"] == name and (location.is_empty() or properties.get("pickup_location") == location):
			count += 1
	return count


func _test_consent_and_gameplay() -> void:
	var path := _path("manager")
	var time := FakeTime.new()
	var manager := ManagerScript.new()
	var client := RecordingClient.new()
	client.project_token = "test-project-token"
	client._now = time.now_ms
	manager._now = time.now_ms
	manager._utc = time.utc_ms
	manager._platform = "Windows"
	manager._initialize(path, "Testkontakt", client)
	manager._connect_game()
	_check(not AnalyticsManager.is_available() and not AnalyticsManager.has_consent(),
		"Die echte Instanz bleibt im Test auch bei aktivierter Testinstanz gesperrt")
	manager.game_started("new")
	manager.capture("cat_rescued")
	_check(manager._state["distinct_id"] == "" and manager._state["queue"].is_empty()
		and client.requests.is_empty() and not FileAccess.file_exists(path),
		"Vor Zustimmung keine Kennung, Messhistorie, Datei oder Requests")
	_check(manager.set_consent(false) and not manager.needs_consent(), "Ablehnung wird gespeichert")
	_check(manager.set_consent(true), "Ausdrueckliche Zustimmung aktiviert die Testinstanz")
	var original_id: String = manager._state["distinct_id"]
	GameState.reset()
	manager.game_started("new")
	var cat := CatData.create_random()
	_check(GameState.pick_up_cat(cat), "Outdoor-Pickup gelingt")
	_check(_events(manager, "cat_rescued") == 0, "Aufheben allein ist keine Rettung")
	GameState.lose_carried_cat()
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	for index in 2:
		_check(GameState.home_simulation.pick_up(cat.id), "Indoor-Pickup gelingt")
		_check(not GameState.home_simulation.pick_up(cat.id), "Fehlgeschlagener Pickup wird nicht erfasst")
		GameState.home_simulation.drop(GameState.home_simulation.layout.free_position())
	_check(_events(manager, "cat_picked_up", "outdoor") == 2
		and _events(manager, "cat_picked_up", "indoor") == 2
		and _events(manager, "cat_rescued") == 1,
		"Zwei Outdoor- und zwei Indoor-Pickups ergeben genau eine wirkliche Rettung")
	GameState.deliver_carried_cats()
	SaveManager.save_game()
	SaveManager.load_game()
	_check(_events(manager, "cat_rescued") == 1, "Leere Abgabe und Laden retten keine Katze erneut")
	GameState.home_simulation.pick_up(cat.id)
	GameState.home_simulation.drop(GameState.home_simulation.layout.free_position())
	_check(_events(manager, "cat_picked_up", "indoor") == 3,
		"Nach Laden ist genau eine Indoor-Signalverbindung aktiv")
	var previous_simulation := GameState.home_simulation
	GameState.reset()
	previous_simulation.pick_up(cat.id)
	_check(_events(manager, "cat_picked_up", "indoor") == 3
		and manager._state["distinct_id"] == original_id,
		"Alte Simulationen sind abgekoppelt; neues Spiel behaelt die Installationskennung")
	for index in 2:
		GameState.pick_up_cat(CatData.create_random())
	GameState.deliver_carried_cats()
	_check(_events(manager, "cat_rescued") == 3, "Gemeinsame Abgabe zaehlt eine Rettung je Katze")
	GameState.add_coins(1000)
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = true
	GameState.purchase_upgrade("carry_capacity")
	GameState.buy_home_item("food")
	tree.paused = false
	_check(_events(manager, "upgrade_purchased") == 1 and _events(manager, "home_item_purchased") == 1,
		"Erfolgreiche Kaeufe im pausierten Katalog gehen nicht verloren")
	var queue: Array = manager._state["queue"]
	client.tick(queue, 0)
	var sent_ids := client._in_flight.duplicate()
	client.respond(200)
	_check(queue.size() > 0 or not sent_ids.is_empty(), "Erfolgreicher Versand verarbeitet den Testbatch")
	for entry: Dictionary in queue:
		var props: Dictionary = entry["payload"]["properties"]
		_check(String(props["event_id"]) not in sent_ids, "Bestaetigte Ereignisse sind dauerhaft aus der Queue entfernt")
	var late: int = client.generations[0]
	_check(manager.set_consent(false) and manager._state["distinct_id"] == ""
		and manager._state["queue"].is_empty(), "Widerruf entfernt Kennung und ausstehende Ereignisse")
	client.respond(200, HTTPRequest.RESULT_SUCCESS, late)
	manager.capture("cat_rescued")
	_check(manager._state["queue"].is_empty(), "Widerruf und spaete Callbacks erzeugen keine neuen Daten")
	_check(manager.set_consent(true) and manager._state["distinct_id"] != original_id,
		"Erneute Zustimmung beginnt mit einer neuen Kennung")
	manager.set_consent(false)
	manager.free()


func _test_manager_failures() -> void:
	var path := _path("failures")
	var manager := ManagerScript.new()
	var time := FakeTime.new()
	var client := RecordingClient.new()
	client.project_token = "test-project-token"
	client._now = time.now_ms
	manager._now = time.now_ms
	manager._utc = time.utc_ms
	manager._platform = "Windows"
	manager._initialize(path, "Testkontakt", client)
	manager._store = FailingStore.new(path)
	_check(not manager.set_consent(true) and not manager.has_consent()
		and manager._state["distinct_id"] == "" and not manager.last_error.is_empty(),
		"Fehlgeschlagenes Opt-in wird nicht aktiv und legt keine Kennung ab")
	manager._store = AnalyticsStore.new(path)
	manager.set_consent(true)
	manager.game_started("new")
	for index in 45:
		manager.capture("cat_rescued")
	manager._process(0.0)
	client.respond(200)
	manager._process(0.0)
	_check(client.requests.size() == 2,
		"Online-Rueckstau wird in weiteren Batches geleert statt auf 20 Ereignisse pro Minute begrenzt")
	var old_generation: int = client.generations.back()
	manager._store = FailingStore.new(path)
	_check(not manager.set_consent(false) and not manager.has_consent()
		and manager._state["distinct_id"] == "" and manager._state["queue"].is_empty()
		and client._in_flight.is_empty(), "Auch nicht speicherbarer Widerruf stoppt sofort alle laufenden Daten")
	client.respond(200, HTTPRequest.RESULT_SUCCESS, old_generation)
	manager.capture("cat_rescued")
	_check(manager._state["queue"].is_empty(), "Nach fehlgeschlagenem Speichern bleibt der Widerruf im Prozess wirksam")
	manager._store = AnalyticsStore.new(path)
	manager.set_consent(false)
	manager.free()

	var restored := ManagerScript.new()
	var restored_client := RecordingClient.new()
	restored._initialize(path, "Testkontakt", restored_client)
	_check(not restored.needs_consent() and not restored.has_consent(),
		"Ablehnung bleibt nach Neustart erhalten")
	restored.free()

	var scope_service: Node = make_ui_service(path)
	scope_service.call("set_consent", true)
	scope_service.free()
	var changed_scope := ManagerScript.new()
	changed_scope._initialize(path, "Anderer Empfaenger", RecordingClient.new())
	_check(not changed_scope.has_consent() and changed_scope.needs_consent()
		and changed_scope._state["distinct_id"] == "",
		"Neues Projekt oder neuer Datenschutzkontakt erbt keine alte Einwilligung")
	changed_scope.free()


func _test_first_paused_purchase() -> void:
	var manager: Node = make_ui_service(_path("first_purchase"))
	manager.call("_connect_game")
	manager.call("set_consent", true)
	GameState.reset()
	GameState.add_coins(1000)
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = true
	GameState.purchase_upgrade("carry_capacity")
	GameState.buy_home_item("food")
	tree.paused = false
	_check(_events(manager, "play_session_started") == 1
		and _events(manager, "upgrade_purchased") == 1
		and _events(manager, "home_item_purchased") == 1
		and _events(manager, "playtime") == 0,
		"Auch die erste Spielaktion kann ein pausierter Kauf sein, ohne Pausenzeit zu zaehlen")
	manager.call("set_consent", false)
	manager.free()


func _test_delayed_lifecycle() -> void:
	for ending in ["pause", "finish"]:
		var time := FakeTime.new()
		var manager := ManagerScript.new()
		var client := RecordingClient.new()
		client.project_token = "test-project-token"
		manager._now = time.now_ms
		manager._utc = time.utc_ms
		manager._platform = "Windows"
		manager._initialize(_path(ending), "Testkontakt", client)
		manager.set_consent(true)
		manager._enqueue_clock(manager._clock.update(0, UTC_BASE, true, true, "home"))
		manager._clock.update(4000, UTC_BASE + 4000, true, false, "home")
		manager._previous_tick_ms = 4000
		time.ticks = 604000
		time.utc = UTC_BASE + time.ticks
		if ending == "pause":
			manager._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		else:
			manager._finish_interval()
		var seconds := 0.0
		var queue: Array = manager._state["queue"]
		for entry: Dictionary in queue:
			var payload: Dictionary = entry["payload"]
			if payload["event"] == "playtime":
				seconds += float(payload["properties"]["duration_seconds"])
		_check(is_equal_approx(seconds, 4.0),
			"Verspaetetes %s sichert vier echte Sekunden, nicht die verlorenen Frames" % ending)
		manager.set_consent(false)
		manager.free()
