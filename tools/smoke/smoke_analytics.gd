## Durchlauf durch die Einwilligung zur Nutzungsstatistik.
extends SmokeSuite


func run() -> void:
	await _test_analytics_menu()

func _test_analytics_menu() -> void:
	print("--- Einwilligung und Widerruf ---")
	var suite: GDScript = load("res://tools/test_analytics.gd")
	if suite == null or not suite.can_instantiate():
		_check(false, "Analytics-Testhilfe laesst sich laden")
		return
	await _test_analytics_first_start(suite)
	var menu := await _load_scene("res://scenes/ui/main_menu.tscn")
	if menu == null:
		return
	var path := SaveManager.save_path.get_base_dir().path_join("analytics_ui.json")
	var service: Node = suite.make_ui_service(path)
	var dialog: AnalyticsConsent = menu.get("_analytics_dialog")
	var accept: Button = dialog.get("_accept")
	var decline: Button = dialog.get("_decline")
	var panel: PanelContainer = dialog.get("_panel")
	var details: Button = dialog.get("_details")
	var message: RichTextLabel = dialog.get("_message")
	var credits_button: Button = _node(menu, "%CreditsButton")
	var options_panel: PanelContainer = _node(menu, "%OptionsPanel")
	var options_close: Button = _node(menu, "%OptionsCloseButton")
	var analytics_button: Button = menu.get("_analytics_button")
	_check(not dialog.visible, "Entwicklungslaeufe fragen nicht nach einer unmoeglichen Freigabe")
	credits_button.grab_focus()
	var original_size := get_tree().root.size
	for window_size in UI_WINDOW_SIZES:
		get_tree().root.size = window_size
		dialog.present(service)
		await _wait(0.1)
		var bounds := dialog.get_viewport_rect()
		_check(dialog.visible and bounds.encloses(panel.get_global_rect())
			and panel.get_global_rect().encloses(accept.get_global_rect())
			and panel.get_global_rect().encloses(decline.get_global_rect())
			and panel.get_global_rect().encloses(details.get_global_rect()),
			"Einwilligung und beide Knoepfe passen bei %s ins Bild" % window_size)
		_check(not accept.disabled and UiKit.button_text(accept) == "Ja, erlauben"
			and UiKit.button_text(decline) == "Nein danke"
			and is_equal_approx(accept.size.x, decline.size.x),
			"Zustimmung und Ablehnung sind gleichwertig erreichbar")
		_check(message.text == AnalyticsConsent.SUMMARY and message.get_content_height() <= message.size.y,
			"Die kurze Erklaerung ist bei %s ohne Scrollen lesbar" % window_size)
		_send_ui_action(&"ui_focus_next")
		_check(details.has_focus(), "Datenschutzdetails sind vor der Entscheidung per Tastatur erreichbar")
		_send_ui_action(&"ui_accept")
		await _wait(0.1)
		_check(message.text == String(service.call("privacy_text"))
			and UiKit.button_text(details) == "Zurück zur Kurzfassung"
			and bounds.encloses(panel.get_global_rect()),
			"Vollstaendige Datenschutzangaben bleiben vor der Freigabe zugaenglich")
		_check_focus_within(panel, "Datenschutzdetails bei %s" % window_size)
		_click_control(details)
		await _wait(0.1)
		_check(message.text == AnalyticsConsent.SUMMARY and not bool(service.call("has_consent")),
			"Zurueck zur Kurzfassung gibt keine versehentliche Freigabe")
		_check_focus_within(panel, "Einwilligung bei %s" % window_size)
		_click_control(credits_button)
		_check(not _node(menu, "%CreditsPanel").visible,
			"Die Einwilligung sperrt auch den neuen Credits-Knopf")
	get_tree().root.size = original_size
	_send_ui_action(&"pause")
	_check(not dialog.visible and not bool(service.call("needs_consent"))
		and not bool(service.call("has_consent")), "Escape bei Erstabfrage speichert eine Ablehnung")
	_check(credits_button.has_focus(), "Nach der Erstabfrage kehrt der Fokus zum Credits-Knopf zurueck")
	dialog.present(service)
	accept.pressed.emit()
	_check(not dialog.visible and bool(service.call("has_consent")), "Zustimmen aktiviert erst nach der Entscheidung")
	dialog.present(service)
	dialog.dismiss()
	_check(bool(service.call("has_consent")), "Schliessen einer bestehenden Info widerruft nicht versehentlich")
	_press(menu, "%OptionsButton")
	analytics_button.grab_focus()
	dialog.present(service)
	_check_focus_within(panel, "Nutzungsanalyse ueber den Optionen")
	_click_control(options_close)
	_check(options_panel.visible, "Der Analysedialog sperrt die darunterliegenden Optionen")
	_send_ui_action(&"pause")
	_check(not dialog.visible and options_panel.visible and analytics_button.has_focus(),
		"Escape schliesst nur die Analyseinfo und gibt den Optionen ihren Fokus zurueck")
	_press(menu, "%OptionsCloseButton")
	_check(_node(menu, "%OptionsButton").has_focus(),
		"Nach verschachtelten Dialogen ist das Hauptmenue wieder bedienbar")
	dialog.present(service)
	decline.pressed.emit()
	_check(not dialog.visible and not bool(service.call("has_consent")), "Expliziter Widerruf schaltet die Erfassung aus")
	_check(not AnalyticsManager.has_consent(), "Die echte Testlauf-Instanz bleibt dabei ausgeschaltet")
	menu.queue_free()
	await _wait(0.1)
	service.free()
	_remove_analytics_ui_files(path)


func _test_analytics_first_start(suite: GDScript) -> void:
	for allow: bool in [false, true]:
		var path := SaveManager.save_path.get_base_dir().path_join("analytics_first_start_%s.json" % allow)
		var service: Node = suite.make_ui_service(path)
		var menu := await _load_scene("res://scenes/ui/main_menu.tscn", {"_analytics_service": service})
		if menu == null:
			service.free()
			return
		var dialog: AnalyticsConsent = menu.get("_analytics_dialog")
		var panel: PanelContainer = dialog.get("_panel")
		_check(dialog.visible and panel.has_focus(),
			"Beim ersten Start erscheint die Freigabeabfrage automatisch und ohne vorausgewaehlte Antwort")
		_send_ui_action(&"ui_accept")
		service.call("game_started", "continue")
		service.call("_process", 0.0)
		var state: Dictionary = service.get("_state")
		var client: Node = service.get("_client")
		var requests: Array = client.get("requests")
		_check(dialog.visible and not bool(service.call("has_consent"))
			and state["distinct_id"] == "" and state["queue"].is_empty()
			and requests.is_empty() and not FileAccess.file_exists(path),
			"Vor der bewussten Freigabe gibt es weder Kennung noch Messung, Datei oder Versand")
		var choice: Button = dialog.get("_accept" if allow else "_decline")
		_click_control(choice)
		_check(not dialog.visible and bool(service.call("has_consent")) == allow
			and not bool(service.call("needs_consent")),
			"Die Erststart-Entscheidung %s wird per Mausklick gespeichert" % allow)
		state = service.get("_state")
		var previous_id: String = state["distinct_id"]
		menu.queue_free()
		await _wait(0.1)
		service.free()

		service = suite.make_ui_service(path)
		menu = await _load_scene("res://scenes/ui/main_menu.tscn", {"_analytics_service": service})
		if menu == null:
			service.free()
			_remove_analytics_ui_files(path)
			return
		dialog = menu.get("_analytics_dialog")
		state = service.get("_state")
		_check(not dialog.visible and bool(service.call("has_consent")) == allow
			and not bool(service.call("needs_consent")) and state["distinct_id"] == previous_id,
			"Nach Neustart bleibt die Entscheidung %s ohne erneute Abfrage erhalten" % allow)
		var analytics_button: Button = menu.get("_analytics_button")
		_check(UiKit.button_text(analytics_button)
				== "Nutzungsanalyse: " + ("an" if allow else "aus"),
			"Die Optionen zeigen die gespeicherte Freigabeentscheidung")
		menu.queue_free()
		await _wait(0.1)
		service.free()
		_remove_analytics_ui_files(path)


func _remove_analytics_ui_files(path: String) -> void:
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			_check(DirAccess.remove_absolute(file) == OK, "Analytics-Testdatei wird entfernt")

