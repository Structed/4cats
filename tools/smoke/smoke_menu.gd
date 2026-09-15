## Durchlauf durch das Hauptmenue und seine Dialoge.
extends SmokeSuite


func run() -> void:
	await _test_main_menu()

func _test_main_menu() -> void:
	print("--- Hauptmenue ---")
	var menu := await _load_scene("res://scenes/ui/main_menu.tscn")
	if menu == null:
		return

	var version: String = ProjectSettings.get_setting("application/config/version")
	var version_label := menu.get_node_or_null("%VersionLabel") as Label
	_check(version_label != null and version_label.text == "Version %s" % version,
		"Das Hauptmenue zeigt die tatsaechliche Projektversion")
	if version_label != null:
		_check(version_label.is_visible_in_tree()
			and version_label.get_viewport_rect().encloses(version_label.get_global_rect()),
			"Die Versionsanzeige liegt sichtbar innerhalb des Bildschirms")
		_check(version_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Die Versionsanzeige faengt keine Eingaben ab")

	await _test_main_menu_layout(menu)

	var credits_button: Button = _node(menu, "%CreditsButton")
	var credits_close: Button = _node(menu, "%CreditsCloseButton")
	var credits_panel: PanelContainer = _node(menu, "%CreditsPanel")
	var credits_dim: ColorRect = _node(menu, "%CreditsDim")
	var options_button: Button = _node(menu, "%OptionsButton")
	_check(not credits_panel.visible and not credits_dim.visible,
		"Credits sind beim Start geschlossen")

	# Echte Eingaben pruefen auch Fokus und Abschirmung, nicht nur Signale.
	credits_button.grab_focus()
	_send_ui_action(&"ui_accept")
	await _wait(0.2)
	_check(credits_panel.visible, "Credits lassen sich per Tastatur oeffnen")
	_check(credits_dim.visible, "Credits dunkeln den Hintergrund ab")
	var credits_text: Label = credits_panel.get_node("Box/Text")
	_check(credits_text.text.contains("Support:\nYvonne Ebner"),
		"Die Credits nennen Yvonne Ebner fuer den Support")
	_check(credits_panel.get_viewport_rect().encloses(credits_panel.get_global_rect())
		and credits_panel.get_global_rect().encloses(credits_text.get_global_rect())
		and credits_panel.get_global_rect().encloses(credits_close.get_global_rect()),
		"Alle Credits und der Schliessen-Knopf passen vollstaendig ins Bild")
	_check(credits_close.has_focus(), "Credits fokussieren den Schliessen-Knopf")
	for action in MENU_FOCUS_ACTIONS:
		_send_ui_action(action)
		_check(credits_close.has_focus(), "Der Fokus bleibt in den Credits (%s)" % action)
	_click_control(options_button)
	_check(not _node(menu, "%OptionsPanel").visible,
		"Die Credits sperren Mausklicks auf das Hauptmenue")

	_click_control(credits_close)
	await _wait(0.2)
	_check(not credits_panel.visible and not credits_dim.visible,
		"Credits lassen sich mit dem Schliessen-Knopf schliessen")
	_check(credits_button.has_focus(), "Nach den Credits kehrt der Fokus ins Hauptmenue zurueck")

	_click_control(credits_button)
	_check(credits_panel.visible, "Credits lassen sich per Maus erneut oeffnen")
	_send_ui_action(&"ui_accept")
	_check(not credits_panel.visible and not credits_dim.visible,
		"Credits lassen sich per Tastatur bestaetigen und schliessen")
	_click_control(credits_button)
	_send_ui_action(&"pause")
	_check(not credits_panel.visible and not credits_dim.visible and credits_button.has_focus(),
		"Pause schliesst die Credits samt Abdunklung und stellt den Fokus wieder her")

	# Optionen auf und wieder zu.
	_press(menu, "%OptionsButton")
	await _wait(0.2)
	_check(_node(menu, "%OptionsPanel").visible, "Optionen lassen sich oeffnen")
	_check(_node(menu, "%OptionsDim").visible, "Dahinter wird abgedunkelt")
	_check(_node(menu, "%MasterSlider").has_focus(), "Die Optionen erhalten den Tastaturfokus")

	# Alle Regler bewegen.
	for slider_name in ["%MasterSlider", "%SfxSlider", "%MusicSlider"]:
		var slider: HSlider = _node(menu, slider_name)
		slider.value = 0.4
		await _wait(0.05)
	var touch_check: CheckButton = _node(menu, "%TouchCheck")
	touch_check.button_pressed = not touch_check.button_pressed
	await _wait(0.1)
	touch_check.button_pressed = not touch_check.button_pressed
	await _wait(0.1)

	_press(menu, "%OptionsCloseButton")
	await _wait(0.2)
	_check(not _node(menu, "%OptionsPanel").visible, "Optionen lassen sich schliessen")
	_check(options_button.has_focus(), "Nach den Optionen kehrt der Fokus ins Hauptmenue zurueck")

	# Bestaetigungsfenster: nur sichtbar, wenn ein Spielstand vorliegt.
	SaveManager.save_game()
	_press(menu, "%NewGameButton")
	await _wait(0.2)
	_check(_node(menu, "%ConfirmPanel").visible, "Nachfrage vor dem Ueberschreiben")
	_check(_node(menu, "%ConfirmNoButton").has_focus(), "Die Nachfrage fokussiert Abbrechen")
	var selection: OptionButton = _node(menu, "%DifficultyChoice")
	var mode_description: Label = _node(menu, "%DifficultyDescription")
	_check(selection.item_count == DifficultyRules.IDS.size() and selection.selected == 0,
		"Ein neues Spiel bietet drei Modi mit sicherer Vorauswahl")
	var snapshot := JSON.stringify(GameState.to_dict())
	selection.select(2)
	selection.item_selected.emit(2)
	_check(mode_description.text.contains("sterben") and JSON.stringify(GameState.to_dict()) == snapshot,
		"Die harte Modusvorschau warnt vor Katzentod und aendert noch keinen Spielstand")
	var previous_size := get_window().size
	for window_size in UI_WINDOW_SIZES:
		get_window().size = window_size
		await _wait(0.1)
		var panel: Control = _node(menu, "%ConfirmPanel")
		_check(panel.get_viewport_rect().encloses(panel.get_global_rect())
			and panel.get_global_rect().encloses(_node(menu, "%ConfirmYesButton").get_global_rect())
			and panel.get_global_rect().encloses(mode_description.get_global_rect()),
			"Moduswahl, Warnung und Bestaetigung passen ins Bild (%s)" % window_size)
	get_window().size = previous_size
	_press(menu, "%ConfirmNoButton")
	await _wait(0.2)
	_check(not _node(menu, "%ConfirmPanel").visible, "Nachfrage laesst sich abbrechen")
	_check(_node(menu, "%NewGameButton").has_focus(), "Nach Abbrechen kehrt der Fokus zurueck")
	_check(JSON.stringify(GameState.to_dict()) == snapshot, "Abbrechen behaelt den bisherigen Modus und Zustand")

	menu.queue_free()
	await _wait(0.1)


func _test_main_menu_layout(menu: Node) -> void:
	var window := get_window()
	var previous_size := window.size
	var continue_button: Button = _node(menu, "%ContinueButton")
	var continue_visible := continue_button.visible
	var center: Control = _node(menu, "%Center")
	var attribution: Label = _node(menu, "%MadeWithLabel")
	var version: Label = _node(menu, "%VersionLabel")
	for window_size in UI_WINDOW_SIZES:
		window.size = window_size
		for shown: bool in [false, true]:
			continue_button.visible = shown
			await _wait(0.1)
			var viewport := get_viewport().get_visible_rect()
			var menu_rect := center.get_global_rect()
			var attribution_rect := attribution.get_global_rect()
			var version_rect := version.get_global_rect()
			var context := "%s, Weiterspielen=%s" % [window_size, shown]
			_check(viewport.encloses(menu_rect) and viewport.encloses(attribution_rect)
				and viewport.encloses(version_rect),
				"Hauptmenue und Fusszeile liegen vollstaendig im Bildschirm (%s)" % context)
			_check(not menu_rect.intersects(attribution_rect)
				and not menu_rect.intersects(version_rect)
				and not attribution_rect.intersects(version_rect),
				"Hauptmenue und Fusszeile ueberlappen sich nicht (%s)" % context)
			_check(attribution.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Die Fusszeile faengt keine Eingaben ab (%s)" % context)
	continue_button.visible = continue_visible
	window.size = previous_size
	await _wait(0.1)

