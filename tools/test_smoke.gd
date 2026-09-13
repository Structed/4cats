## Durchlauf durch alle Szenen und Interaktionen.
##
## Aufruf:
##   godot --headless --path . -- --smoketest
##
## Zweck ist nicht, Spielregeln zu pruefen -- das machen test_gameplay.gd und
## test_playthrough.gd. Hier geht es darum, jede Szene und jeden Knopf einmal
## anzufassen, damit Skriptfehler auffallen, die nur bei Interaktion auftreten:
## fehlende Knoten, Zugriffe auf bereits freigegebene Objekte, kaputte Signale.
##
## Alle Fehler und Warnungen der Engine landen dabei in der Ausgabe und werden
## am Ende gezaehlt.
extends Node

const UI_WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1760, 720),
]
const NAVIGATION_ZOOMS: Array[Vector2] = [Vector2(2, 2), Vector2(1.5, 1.5)]
# Gemessene Ausgangsflaechen fuer Mimi bei Genesung und beim Aufheben.
const CAT_STATUS_REFERENCE_AREA := 276.0 * 108.0
const HOME_HINT_REFERENCE_AREA := 260.0 * 56.0
const COMPACT_AREA_RATIO := 0.7
const HOME_HINT_LAYOUT_CASES: PackedStringArray = [
	"E: Mimi aufheben",
	"Mimi absetzen\nZum Waschen oder Behandeln tragen.",
	"Pflege …\nAktion / Esc: abbrechen",
	"Behandlungsstation platzieren\nJoystick: bewegen · rechts aufstellen\nDie Bedienseite von „Behandlungsstation“ ist nicht erreichbar.",
	"E: Mimi aufheben",
]
const MENU_FOCUS_ACTIONS: Array[StringName] = [
	&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]

var _failures: PackedStringArray = []

## Wird per Signal gesetzt. Muss ein Feld sein, kein lokaler Wert: GDScript
## erfasst einfache Typen in Lambdas als Kopie, eine lokale bool bliebe false.
var _adoption_seen: bool = false


func _ready() -> void:
	# An die Wurzel haengen, nicht an die Startszene. Sonst nimmt uns der erste
	# Szenenwechsel mit ins Grab, und danach ist get_tree() null.
	call_deferred("_reparent_to_root")


func _reparent_to_root() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [ok]    %s" % description)
	else:
		print("  [FEHLER] %s" % description)
		_failures.append(description)


func _run() -> void:
	var suite := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			suite = argument.trim_prefix("--suite=")
	if suite not in ["all", "menus"]:
		_check(false, "Unbekannte Oberflaechensuite: %s" % suite)
		_finish()
		return
	if suite == "menus":
		await _test_main_menu()
		await _test_analytics_menu()
		await _test_new_game_modes()
		_finish()
		return
	await _test_main_menu()
	await _test_analytics_menu()
	await _test_home()
	await _test_adoption_status()
	await _test_home_hint_layout()
	await _test_touch_furnishing()
	await _test_rescue()
	await _test_scene_transitions()
	await _test_real_ui_path()
	await _test_new_game_modes()
	await _test_resume_with_save()
	_finish()


# --- Fortsetzen mit vorhandenem Spielstand -----------------------------------

## Wer das Spiel mit Katzen im Tragekorb verlaesst und spaeter weiterspielt,
## laedt einen Zustand, den keine der obigen Pruefungen herstellt.
func _test_resume_with_save() -> void:
	print("--- Weiterspielen mit Spielstand ---")

	# Einen Spielstand bauen, wie er nach echtem Spielen aussieht.
	GameState.reset()
	GameState.add_coins(320)
	GameState.purchase_upgrade("carry_capacity")
	for i in 3:
		GameState.pick_up_cat(CatData.create_random())
	GameState.deliver_carried_cats()
	# Und zwei Katzen bleiben unterwegs im Korb.
	for i in 2:
		GameState.pick_up_cat(CatData.create_random())
	SaveManager.save_game()

	var carried_before := GameState.carried_cats.size()
	var home_before := GameState.home_cats.size()
	var coins_before := GameState.coins

	# So tun, als startete das Spiel frisch.
	GameState.reset()
	_check(SaveManager.load_game(), "Der Spielstand laesst sich laden")
	_check(GameState.carried_cats.size() == carried_before,
		"Getragene Katzen sind wieder da (%d)" % GameState.carried_cats.size())
	_check(GameState.home_cats.size() == home_before,
		"Katzen zu Hause sind wieder da (%d)" % GameState.home_cats.size())
	_check(GameState.coins == coins_before, "Muenzen stimmen (%d)" % GameState.coins)

	# Mit diesem Zustand ins Zuhause und ins Level -- dabei baut der Spieler
	# seine getragenen Katzen ueber dem Kopf auf.
	SceneRouter.goto_home()
	await _wait_for_scene("HomeScene")
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "HomeScene",
		"Das Zuhause oeffnet sich mit geladenem Spielstand")

	SceneRouter.goto_rescue()
	await _wait_for_scene("RescueLevel")
	var level := get_tree().current_scene
	_check(level != null and level.name == "RescueLevel",
		"Das Level oeffnet sich mit Katzen im Korb")
	if level == null:
		return

	var carry_slot: Node2D = level.get_node("Player/CarrySlot")
	_check(carry_slot.get_child_count() == GameState.carried_cats.size(),
		"Die getragenen Katzen werden angezeigt (%d)" % carry_slot.get_child_count())

	await _wait(1.0)
	_check(true, "Das Level laeuft mit geladenem Spielstand weiter")


# --- Echter Weg durch die Oberflaeche ----------------------------------------

## Klickt sich so durch das Spiel, wie es ein Mensch tut: ueber die Knoepfe der
## jeweils aktiven Szene, mit echten Szenenwechseln durch den SceneRouter.
## Die Tests oben haengen die Szenen direkt an die Wurzel -- damit bleibt der
## Pfad ungetestet, auf dem das Spiel tatsaechlich laeuft.
func _test_real_ui_path() -> void:
	print("--- Echter Weg durch die Oberflaeche ---")

	SaveManager.delete_save()
	GameState.reset()

	SceneRouter.goto_main_menu()
	await _wait_for_scene("MainMenu")

	var menu := get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "Hauptmenue ist die aktive Szene")
	if menu == null:
		return

	_check(not bool(SceneRouter.get("_busy")),
		"Der Szenenwechsler ist nach dem Wechsel wieder frei")

	# Der SceneRouter sichert bei jedem Wechsel -- es liegt also immer ein
	# Spielstand vor und "Neues Spiel" fragt vorher nach.
	_press(menu, "%NewGameButton")
	await _wait(0.4)
	var confirm: PanelContainer = _node(menu, "%ConfirmPanel")
	_check(confirm != null and confirm.visible, "Neues Spiel fragt vor dem Ueberschreiben nach")
	_press(menu, "%ConfirmYesButton")

	await _wait_for_scene("HomeScene")
	var home := get_tree().current_scene
	_check(home != null and home.name == "HomeScene", "Neues Spiel fuehrt ins Zuhause")
	if home == null:
		printerr("  Szenenwechsler beschaeftigt: %s" % str(SceneRouter.get("_busy")))
		return

	var home_player: Player = home.get_node("Player")
	home_player.position = HomeCatalog.world(HomeCatalog.ENTRY)
	await _home_action(home)
	await _wait_for_scene("RescueLevel")
	var level := get_tree().current_scene
	_check(level != null and level.name == "RescueLevel", "Von dort geht es ins Rettungs-Level")
	if level == null:
		return

	# Ein paar Sekunden laufen lassen: Autos, Hunde und Katzen bewegen sich.
	await _wait(2.0)

	# Der Touch-Knopf loest das Aufheben aus.
	var touch: CanvasLayer = level.get_node_or_null("TouchControls")
	_check(touch != null, "Die Touch-Bedienung haengt im Level")
	if touch != null:
		var action := touch.get_node_or_null("Root/ActionButton") as Button
		var sprint := touch.get_node_or_null("Root/SprintButton") as Button
		_check(action != null, "Der Aufheben-Knopf ist vorhanden")
		_check(sprint != null, "Der Rennen-Knopf ist vorhanden")
		if action != null:
			action.button_down.emit()
			await _wait(0.1)
			action.button_up.emit()
			await _wait(0.1)
		if sprint != null:
			sprint.toggled.emit(true)
			await _wait(0.3)
			sprint.toggled.emit(false)
			await _wait(0.1)
		_check(not Input.is_action_pressed("sprint"), "Der Rennen-Knopf laesst die Aktion wieder los")

	# Ueber das Pausenmenue zurueck ins Zuhause.
	var hud: Control = level.get_node("UI/HUD")
	hud.call("toggle_pause")
	await _wait(0.3)
	_press(hud, "%ToHomeButton")
	await _wait_for_scene("HomeScene")
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "HomeScene",
		"Das Pausenmenue fuehrt zurueck ins Zuhause")
	_check(not get_tree().paused, "Die Pause ist danach aufgehoben")

	# Und weiter ins Hauptmenue.
	var home_hud: HomeHUD = get_tree().current_scene.get("hud")
	_press(home_hud, "%PauseButton")
	_press(home_hud, "%MenuButton")
	await _wait_for_scene("MainMenu")
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu",
		"Vom Zuhause geht es zurueck ins Hauptmenue")

	# Weiterspielen mit vorhandenem Spielstand.
	_check(_node(get_tree().current_scene, "%ContinueButton") != null,
		"Der Weiterspielen-Knopf ist vorhanden")


func _test_new_game_modes() -> void:
	print("--- Moduswahl ueber echte Menueeingaben ---")
	for index in DifficultyRules.IDS.size():
		SceneRouter.goto_main_menu()
		await _wait_for_scene("MainMenu")
		var menu := get_tree().current_scene
		if menu == null or menu.name != "MainMenu":
			_check(false, "Hauptmenue fuer Moduswahl vorhanden")
			return
		_click_control(_node(menu, "%NewGameButton"))
		await _wait(0.1)
		var choice: OptionButton = _node(menu, "%DifficultyChoice")
		choice.grab_focus()
		_send_ui_action(&"ui_accept")
		await _wait(0.1)
		var popup := choice.get_popup()
		_check(popup.visible, "Die Modusauswahl laesst sich per Tastatur oeffnen")
		for step in index:
			_send_ui_action(&"ui_down", popup)
			await get_tree().process_frame
		_send_ui_action(&"ui_accept", popup)
		await _wait(0.1)
		_check(not popup.visible, "Die Tastaturbestaetigung schliesst das eingebettete Menue")
		_check(choice.selected == index, "Der gewaehlte Modus folgt der Tastatureingabe (erwartet %d, gewaehlt %d)" % [
			index, choice.selected])
		_click_control(_node(menu, "%ConfirmYesButton"))
		await _wait_for_scene("HomeScene")
		var expected: String = DifficultyRules.IDS[index]
		_check(GameState.difficulty_id == expected and GameState.home_cats.is_empty()
			and GameState.supplies.food_stock == SupplyCatalog.START_FOOD,
			"Ein bestaetigtes neues Spiel startet im gewaehlten Modus (%s)" % expected)
		_check(SaveManager.load_game() and GameState.difficulty_id == expected,
			"Der Modus gehoert dauerhaft zum Spielstand (%s)" % expected)


func _wait_for_scene(expected_name: String, timeout: float = 6.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var current := get_tree().current_scene
		# Auch beim erneuten Oeffnen derselben Szene auf die ganze Blende warten.
		if current != null and current.name == expected_name and not bool(SceneRouter.get("_busy")):
			await get_tree().process_frame
			return
	var actual := get_tree().current_scene
	printerr("  Szene '%s' erschien nicht innerhalb von %.0f s (aktuell: %s)"
		% [expected_name, timeout, actual.name if actual != null else "keine"])


# --- Hauptmenue --------------------------------------------------------------

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


# --- Zuhause -----------------------------------------------------------------

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
		_check(not accept.disabled and accept.text == "Ja, erlauben" and decline.text == "Nein danke"
			and is_equal_approx(accept.size.x, decline.size.x),
			"Zustimmung und Ablehnung sind gleichwertig erreichbar")
		_check(message.text == AnalyticsConsent.SUMMARY and message.get_content_height() <= message.size.y,
			"Die kurze Erklaerung ist bei %s ohne Scrollen lesbar" % window_size)
		_send_ui_action(&"ui_focus_next")
		_check(details.has_focus(), "Datenschutzdetails sind vor der Entscheidung per Tastatur erreichbar")
		_send_ui_action(&"ui_accept")
		await _wait(0.1)
		_check(message.text == String(service.call("privacy_text"))
			and details.text == "Zurück zur Kurzfassung"
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
		_check(analytics_button.text == "Nutzungsanalyse: " + ("an" if allow else "aus"),
			"Die Optionen zeigen die gespeicherte Freigabeentscheidung")
		menu.queue_free()
		await _wait(0.1)
		service.free()
		_remove_analytics_ui_files(path)


func _remove_analytics_ui_files(path: String) -> void:
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			_check(DirAccess.remove_absolute(file) == OK, "Analytics-Testdatei wird entfernt")


func _test_home() -> void:
	print("--- Zuhause ---")
	GameState.reset()
	GameState.add_coins(500)

	# Zwei Katzen zum Pflegen ablegen.
	for i in 2:
		var cat := CatData.create_random()
		cat.cat_name = "Mimi" if i == 0 else "Balu"
		GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()

	var home := await _load_scene("res://scenes/home/home_scene.tscn")
	if home == null:
		return

	var player: Player = home.get_node("Player")
	var hud: HomeHUD = home.get("hud")
	var simulation: HomeSimulation = home.get("simulation")
	var actors: Dictionary = home.get("_cat_actors")
	var hint_panel: Control = hud.get("_hint_panel")
	var hint: Label = hud.get("_hint")
	var idle_position := HomeCatalog.world(Vector2i(16, 11))
	_check(actors.size() == 2, "Fuer jede Hauskatze gibt es eine laufende Darstellung")
	_check(GameState.home.items.size() == HomeCatalog.KINDS.size(), "Die kostenlose Grundausstattung ist vorhanden")
	var touch: CanvasLayer = home.get_node("TouchControls")
	touch.call("set_forced", true)
	player.position = HomeCatalog.world(HomeCatalog.ENTRY)
	home.call("_resolve_focus")
	_check(hint_panel.visible and hint.text.contains("Rausgehen"),
		"Am Ausgang erscheint der konkrete Hinweis zum Rausgehen")
	player.position = idle_position
	home.call("_resolve_focus")
	_check(home.get("_focus_kind") == "" and not hint_panel.visible and hint.text.is_empty(),
		"Beim freien Herumlaufen gibt es weder Standardtext noch eine leere Hinweisbox")
	for kind in ["food", "water"]:
		var source := GameState.home.item_by_id("starter_pantry" if kind == "food" else "starter_faucet")
		player.position = HomeCatalog.world(source.port())
		await _home_action(home)
		_check(GameState.supplies.cargo_kind == kind, "%s wird zuerst per Touch an der Quelle geholt" % kind)
		player.position = idle_position
		home.call("_resolve_focus")
		_check(home.get("_focus_kind") == "" and hint_panel.visible
			and hint.text.contains(GameState.supplies.cargo_text()) and not hint.text.begins_with("E:"),
			"Getragene Versorgung behaelt ihre Zielhilfe ohne eine unmoegliche Aktion anzubieten")
		var item := GameState.home.item_by_id("starter_" + kind)
		player.position = HomeCatalog.world(item.port())
		home.call("_resolve_focus")
		_check(hint_panel.visible and hint.text.contains("nachfüllen"),
			"Der Hinweis zum %s erscheint erst am Napf" % kind)
		await _home_action(home)
		_check(item.stock > 0, "%s laesst sich per Touch-Kontextaktion auffuellen" % kind)
		if not GameState.supplies.cargo_kind.is_empty():
			player.position = HomeCatalog.world(source.port())
			await _home_action(home)

	var cat: CatData = GameState.home_cats[0]
	var state: HomeCatState = GameState.home.cats[cat.id]
	player.position = state.position + Vector2(0, 10)
	home.call("_resolve_focus")
	var cat_panel: PanelContainer = hud.get("_cat_panel")
	var cat_name: Label = hud.get("_cat_name")
	_check(cat_panel.visible and cat_name.text.contains(cat.cat_name),
		"Die fokussierte Hauskatze zeigt ihren Vermittlungsstatus ohne Aufnehmen oder Hover")
	var cat_age: Label = hud.get("_cat_age")
	_check(cat_age.is_visible_in_tree() and cat_age.text == cat.age_title(),
		"Die kompakte Zustandsanzeige behaelt die Altersgruppe der Katze")
	_check(hint_panel.visible and hint.text == "Mimi aufheben",
		"An der Katze bleibt nur die kurze Aktion ohne doppelte Pflegebeschreibung")
	var toilet_before := state.toilet_elapsed
	state.toilet_elapsed = HomeSimulation.TOILET_OVERDUE
	home.call("_resolve_focus")
	_check(hint.text.contains("erreichbares Katzenklo"),
		"Der besondere Toilettenbedarf geht beim Kuerzen nicht verloren")
	state.toilet_elapsed = toilet_before
	player.position = idle_position
	home.call("_resolve_focus")
	_check(not hint_panel.visible and not cat_panel.visible,
		"Beim Entfernen von der Katze verschwinden beide Hinweise")
	player.position = state.position + Vector2(0, 10)
	home.call("_resolve_focus")
	await _home_action(home)
	_check(simulation.held_cat_id == cat.id, "Eine Hauskatze laesst sich aufnehmen")
	_check(cat_panel.visible, "Der Vermittlungsstatus bleibt beim Tragen sichtbar")
	_check(hint_panel.visible and hint.text.contains("absetzen"),
		"Beim Tragen bleibt der konkrete Hinweis zum Absetzen sichtbar")
	for kind in ["wash", "vet"]:
		var station := GameState.home.item_by_id("starter_" + kind)
		player.position = HomeCatalog.world(station.port())
		await _home_action(home)
		_check(simulation.is_caring(), "Die Station %s beginnt die Pflege" % kind)
		_check(hint_panel.visible and hint.text.contains("abbrechen"),
			"Waehrend %s bleibt die Pflege mit sichtbarem Hinweis abbrechbar" % kind)
		if kind == "wash":
			await _home_action(home)
			_check(not simulation.is_caring() and hint_panel.visible and hint.text.contains("waschen"),
				"Ein Pflegeabbruch stellt den aktuellen Stationshinweis wieder her")
			await _home_action(home)
		await _wait(HomeSimulation.CARE_SECONDS + 0.2)
		_check(not simulation.is_caring(), "Die Station %s beendet die Pflege" % kind)
		home.call("_process", 0.0)
		var need := "cleanliness" if kind == "wash" else "health"
		var labels: Dictionary = hud.get("_cat_need_labels")
		var value_label: Label = labels[need]
		_check(value_label.text == "%s: %d" % [
			String(HomeHUD.NEED_LABELS[need]), floori(float(cat.get(need)))],
			"Die Zustandsanzeige uebernimmt die abgeschlossene Pflege an der Station %s" % kind)
	player.position += Vector2(0, 48)
	await _home_action(home)
	_check(simulation.held_cat_id.is_empty(), "Die Hauskatze laesst sich absetzen")
	var litter := GameState.home.item_by_id("starter_litter")
	litter.dirt = HomeCatalog.capacity("litter")
	player.position = HomeCatalog.world(litter.port())
	home.call("_resolve_focus")
	_check(hint_panel.visible and hint.text.contains("reinigen"),
		"Am Katzenklo erscheint der konkrete Reinigungshinweis")
	await _home_action(home)
	_check(litter.dirt == 0, "Die Reinigung wird aus der Welt bedient")

	_press(hud, "%ShopButton")
	await _wait(0.2)
	_check(hud.modal_kind == "shop", "Der Laden laesst sich oeffnen")
	_check(not hint_panel.visible and not cat_panel.visible,
		"Im Laden verdecken keine alten Spielhinweise den Katalog")
	_check(get_tree().paused, "Der geoeffnete Laden pausiert die Hausversorgung")
	var before := cat.hunger
	await _wait(0.2)
	_check(is_equal_approx(cat.hunger, before), "Beduerfnisse stehen im Laden still")
	var bought := 0
	for id: String in GameState.UPGRADES:
		var buy := hud.get_node_or_null("%Upgrade_" + id) as Button
		if buy != null and not buy.disabled:
			buy.pressed.emit()
			bought += 1
			await _wait(0.05)
	_check(bought > 0, "Ausbauten lassen sich kaufen (%d)" % bought)
	player.position = idle_position
	_press(hud, "%ModalCloseButton")
	await _wait(0.2)
	_check(hud.modal_kind.is_empty() and not get_tree().paused, "Der Laden laesst sich schliessen")
	_check(not hint_panel.visible, "Nach dem Schliessen gilt der aktuelle statt des alten Handlungskontexts")

	_press(hud, "%FurnishButton")
	_press(hud, "%Buy_toy")
	_check(GameState.home.items.size() == HomeCatalog.KINDS.size() + 1, "Ein neues Spielzeug landet im Inventar")
	var toy: HomeItemData = GameState.home.items.back()
	var old_cell := toy.cell
	player.position = HomeCatalog.world(Vector2i(16, 11))
	_press(hud, "%Select_" + toy.id)
	await _wait(0.2)
	_check(home.get("_preview") != null, "Ein Gegenstand bekommt eine Platzierungsvorschau")
	await _home_action(home, "RotateButton")
	var preview: HomeItemActor = home.get("_preview")
	_check(preview.data.turns == 1, "Drehen funktioniert ueber Touch")
	_check(hint_panel.visible and hint_panel.get_global_rect().end.y <= hud.get_viewport_rect().end.y,
		"Mehrzeilige Einrichtungshinweise bleiben innerhalb des Bildschirms")
	_check(not toy.placed and toy.cell == old_cell, "Die Vorschau veraendert noch keine Hausdaten")
	await _home_action(home)
	_check(toy.placed, "Die Kontextaktion stellt das Spielzeug auf")
	_press(hud, "%FurnishButton")
	_press(hud, "%Select_" + toy.id)
	await _wait(0.2)
	await _home_action(home, "StoreButton")
	_check(not toy.placed, "Einlagern funktioniert ueber Touch")
	_press(hud, "%FurnishButton")
	_press(hud, "%Select_" + toy.id)
	await _wait(0.2)
	_press(hud, "%FurnishButton")
	_check(home.get("_preview") == null and not toy.placed, "Abbrechen verwirft nur die Vorschau")
	await _wait(0.1)
	_check(not hint_panel.visible, "Nach dem Einrichtungsabbruch bleibt keine Platzierungshilfe stehen")
	_check(not Input.is_action_pressed("interact") and not Input.is_action_pressed("home_rotate"),
		"Die Touch-Aktionen bleiben nicht gedrueckt")

	# Adoption ausloesen -- dabei wird die Hauskatze mitten im Betrieb entfernt.
	_adoption_seen = false
	GameState.cat_adopted.connect(_on_cat_adopted)
	for recovered_cat in GameState.home_cats.duplicate():
		recovered_cat.hunger = 100.0
		recovered_cat.thirst = 100.0
		recovered_cat.cleanliness = 100.0
		recovered_cat.health = 100.0
		recovered_cat.enrichment = 100.0
		recovered_cat.recovery_timer = CatData.RECOVERY_SECONDS - 0.1
	await _wait(0.8)
	GameState.cat_adopted.disconnect(_on_cat_adopted)
	_check(_adoption_seen, "Eine Vermittlung mitten im Betrieb bricht nichts")
	_check(not cat_panel.visible, "Nach der Vermittlung bleibt keine veraltete Zustandsanzeige stehen")

	home.queue_free()
	await _wait(0.2)


func _on_cat_adopted(_cat: CatData, _reward: int) -> void:
	_adoption_seen = true


func _test_adoption_status() -> void:
	print("--- Vermittlungsstatus im Katzenhaus ---")
	GameState.reset()
	GameState.add_coins(500)
	var cat := CatData.create_random()
	cat.cat_name = "Mimi"
	GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()
	var hud := HomeHUD.new()
	get_tree().root.add_child(hud)
	var status: Label = hud.get("_cat_recovery")
	var details: Label = hud.get("_cat_details")
	var need_labels: Dictionary = hud.get("_cat_need_labels")
	var health_value: Label = need_labels["health"]
	var window := get_tree().root
	var original_size := window.size

	for need_key: String in cat.needs():
		cat.set(need_key, CatData.NEED_MAX)
	cat.health = CatData.RECOVERY_THRESHOLD - 0.1
	cat.recovery_timer = 0.0
	hud.set_cat_status(cat)
	_check(status.text.begins_with("Pflege fehlt") and cat.wellbeing() > CatData.RECOVERY_THRESHOLD,
		"Hoher Durchschnitt wird bei fehlendem Einzelwert nicht als vermittlungsbereit angezeigt")
	var name_label: Label = hud.get("_cat_name")
	_check(name_label.text.contains("Wohlbefinden:"), "Der Durchschnitt ist als Wohlbefinden beschriftet")
	_check(need_labels.size() == cat.needs().size(), "Alle fuenf Pflegewerte werden als Zahlen angezeigt")
	_check(health_value.text == "Gesundheit: %d!" % (int(CatData.RECOVERY_THRESHOLD) - 1),
		"Ein Wert knapp unter der Schwelle wird nicht aufgerundet")
	_check_missing_needs(hud, ["health"])
	_check(details.text.contains("! Pflege fehlt") \
			and details.text.contains("alle Werte ab %d" % int(CatData.RECOVERY_THRESHOLD)),
		"Die inklusive Zielschwelle ist sichtbar")
	_check(not status.text.contains("noch ca.") and not status.text.contains("sinkt"),
		"Ohne Fortschritt gibt es weder Countdown noch eine falsche Rueckschrittsmeldung")

	cat.health = CatData.RECOVERY_THRESHOLD
	hud.set_cat_status(cat)
	_check(status.text.begins_with("Genesung:") and status.text.ends_with("noch ca. 30 s") \
			and details.text.contains("automatisch"),
		"Genau auf der Schwelle zeigt die Anzeige die automatische Vermittlung mit Restzeit")
	_check_missing_needs(hud, [])
	cat.health = CatData.NEED_MAX
	cat.enrichment = CatData.RECOVERY_THRESHOLD - 0.1
	hud.set_cat_status(cat)
	_check_missing_needs(hud, ["enrichment"])
	_check(status.text.begins_with("Pflege fehlt"),
		"Das neue Beschaeftigungsbeduerfnis verhindert die Vermittlung trotz vier guter Werte")
	cat.enrichment = CatData.RECOVERY_THRESHOLD
	hud.set_cat_status(cat)
	_check(status.text.begins_with("Genesung:"), "Auch Beschaeftigung genau auf der Schwelle reicht aus")
	_check_missing_needs(hud, [])
	cat.enrichment = CatData.NEED_MAX

	cat.hunger = CatData.RECOVERY_THRESHOLD - 0.1
	cat.thirst = CatData.RECOVERY_THRESHOLD - 0.1
	cat.recovery_timer = 10.0
	hud.set_cat_status(cat)
	_check(status.text.contains("sinkt") and details.text.contains("Pflege fehlt"),
		"Fehlende Pflege bei Restfortschritt erklaert den Rueckschritt")
	_check_missing_needs(hud, ["hunger", "thirst"])
	_check(not status.text.contains("noch ca."), "Waehrend der Unterbrechung wird kein Countdown versprochen")
	var before := cat.recovery_timer
	GameState._tick_needs(1.0)
	hud.set_cat_status(cat)
	_check(cat.recovery_timer < before and status.text.contains("%d %%" % floori(cat.recovery_progress() * 100.0)),
		"Die Genesungsanzeige zeigt den tatsaechlichen Rueckschritt ohne alten Pflegebalken")
	var retained := cat.recovery_timer

	cat.hunger = CatData.NEED_MAX
	cat.thirst = CatData.NEED_MAX
	hud.set_cat_status(cat)
	_check(cat.all_needs_met() and status.text.begins_with("Genesung:") and not status.text.contains("sinkt"),
		"Ausreichende Versorgung wechselt die Anzeige zur laufenden Genesung")
	_check(is_equal_approx(cat.recovery_timer, retained), "Pflege erhaelt den bisherigen Fortschritt")
	var remaining_before := GameState.recovery_seconds_remaining(cat)
	var status_before := status.text
	_check(GameState.purchase_upgrade("vet"), "Tierarzt-Ausbau waehrend der Genesung ist moeglich")
	hud.set_cat_status(cat)
	_check(GameState.recovery_seconds_remaining(cat) < remaining_before and status.text != status_before,
		"Ein Tierarzt-Kauf verkuerzt den Countdown ohne Neuaufbau der Anzeige")
	_check(status.text.ends_with("noch ca. %d s" % ceili(GameState.recovery_seconds_remaining(cat))),
		"Die angezeigte Restzeit entspricht der aktuellen Tierarzt-Stufe")
	GameState._tick_needs(1.0)
	hud.set_cat_status(cat)
	_check(cat.recovery_timer > retained, "Nach der Unterbrechung steigt der Fortschritt wieder")

	cat.health = CatData.RECOVERY_THRESHOLD - 0.1
	cat.recovery_timer = 0.5
	GameState._tick_needs(1.0)
	hud.set_cat_status(cat)
	_check(status.text.begins_with("Pflege fehlt") and not status.text.contains("sinkt"),
		"Bei aufgebrauchtem Fortschritt wechselt die Anzeige zur fehlenden Pflege")
	cat.health = CatData.NEED_MAX
	cat.recovery_timer = CatData.RECOVERY_SECONDS - 0.001
	hud.set_cat_status(cat)
	_check(status.text.ends_with("noch ca. 1 s") and not status.text.contains("100 %"),
		"Kurz vor Abschluss werden weder null Sekunden noch volle Genesung vorgetaeuscht")
	var simulation := GameState.home_simulation
	_check(simulation.pick_up(cat.id), "Die fast genesene Katze laesst sich noch tragen")
	hud.set_cat_status(cat)
	_check(not details.text.contains("automatisch") and details.text.contains("absetzen"),
		"Waehrend des Tragens wird die zusaetzliche Voraussetzung zum Vermitteln erklaert")
	GameState._tick_needs(0.01)
	hud.set_cat_status(cat)
	_check(cat.state == CatData.State.AT_HOME and status.text == "Genesung abgeschlossen",
		"Abgeschlossene Genesung wird beim Tragen nicht als erfolgte Vermittlung dargestellt")
	_check(details.text.contains("absetzen"), "Eine genesene getragene Katze muss sichtbar erst abgesetzt werden")
	cat.enrichment = CatData.RECOVERY_THRESHOLD - 0.1
	hud.set_cat_status(cat)
	_check(status.text.contains("sinkt") and details.text.contains("Pflege fehlt"),
		"Fehlende Pflege hat auch bei vollem Fortschritt Vorrang vor der Abschlussmeldung")
	_check(simulation.drop(simulation.layout.free_position()), "Die Katze kann wieder abgesetzt werden")

	for window_size in UI_WINDOW_SIZES:
		window.size = window_size
		for need_key: String in cat.needs():
			cat.set(need_key, CatData.RECOVERY_THRESHOLD - 0.1)
		cat.recovery_timer = 10.0
		hud.set_cat_status(cat)
		await _wait(0.1)
		_check_cat_status_layout(hud, "mit allen fehlenden Werten bei %s" % window_size)
		_check_missing_needs(hud, ["hunger", "thirst", "cleanliness", "health", "enrichment"])
		for need_key: String in cat.needs():
			cat.set(need_key, CatData.NEED_MAX)
		hud.set_cat_status(cat)
		await _wait(0.1)
		_check_cat_status_layout(hud, "mit Countdown bei %s" % window_size)
		cat.cat_name = "Prinzessin Schnurrhaar"
		hud.set_cat_status(cat)
		await _wait(0.1)
		_check_cat_status_layout(hud, "mit langem Namen bei %s" % window_size, false)
		cat.cat_name = "Mimi"

	window.size = original_size
	hud.set_cat_status(null)
	var panel: PanelContainer = hud.get("_cat_panel")
	_check(not panel.visible, "Ohne beobachtete Katze ist die Zustandsanzeige ausgeblendet")
	hud.queue_free()
	await _wait(0.1)


func _check_missing_needs(hud: HomeHUD, expected: PackedStringArray) -> void:
	var labels: Dictionary = hud.get("_cat_need_labels")
	var marked: PackedStringArray = []
	for need_key: String in HomeHUD.NEED_LABELS:
		var label: Label = labels[need_key]
		if label.text.ends_with("!"):
			marked.append(need_key)
	_check(marked == expected,
		"Fehlende Werte werden auch ohne Farbe eindeutig markiert: %s" % str(expected))


func _check_cat_status_layout(hud: HomeHUD, context: String, compact: bool = true) -> void:
	var panel: PanelContainer = hud.get("_cat_panel")
	var bounds := panel.get_global_rect().grow(0.1)
	if compact:
		_check(panel.get_global_rect().get_area() <= CAT_STATUS_REFERENCE_AREA * COMPACT_AREA_RATIO,
			"Die Katzenanzeige braucht mindestens 30 Prozent weniger Flaeche %s" % context)
	_check(hud.get_viewport_rect().encloses(panel.get_global_rect()),
		"Die Zustandsanzeige passt ins Fenster %s" % context)
	_check(panel.get_global_rect().position.y >= 62 \
			and panel.get_global_rect().end.y <= hud.get_viewport_rect().end.y - 166,
		"Die Zustandsanzeige laesst Kopfzeile und Touch-Knoepfe frei %s" % context)
	_check_passive_panel(panel)
	var labels: Array[Label] = [
		hud.get("_cat_name"), hud.get("_cat_recovery"), hud.get("_cat_details"), hud.get("_cat_age"),
	]
	var need_labels: Dictionary = hud.get("_cat_need_labels")
	for label: Label in need_labels.values():
		labels.append(label)
	for label in labels:
		_check(bounds.encloses(label.get_global_rect()) and label.get_visible_line_count() == label.get_line_count(),
			"Alle Textzeilen bleiben innerhalb der Zustandsanzeige %s" % context)
		_check(label.get_theme_font_size("font_size") >= 9,
			"Die kompakte Katzenanzeige verkleinert die Schrift nicht unter die bisherige Mindestgroesse")


func _check_passive_panel(panel: Control) -> void:
	var ignores_input := panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
	for control: Control in panel.find_children("*", "Control", true, false):
		ignores_input = ignores_input and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check(ignores_input, "Die Anzeige samt Inhalt faengt keine Maus- oder Touch-Eingaben ab")


func _test_home_hint_layout() -> void:
	print("--- Kompakte Aktionshinweise im Katzenhaus ---")
	var hud := HomeHUD.new()
	get_tree().root.add_child(hud)
	var touch_scene: PackedScene = load("res://scenes/ui/touch_controls.tscn")
	var touch: CanvasLayer = touch_scene.instantiate()
	get_tree().root.add_child(touch)
	touch.call("configure_home")
	touch.call("set_forced", true)
	touch.call("set_building", true)
	var panel: Control = hud.get("_hint_panel")
	var hint: Label = hud.get("_hint")
	var toast: Control = hud.get("_toast_panel")
	var window := get_tree().root
	var original_size := window.size
	_check(not panel.visible, "Eine neue Hinweisbox ist bis zur ersten konkreten Aktion unsichtbar")
	for window_size in UI_WINDOW_SIZES:
		window.size = window_size
		for text in HOME_HINT_LAYOUT_CASES:
			hud.set_hint(text)
			await _wait(0.1)
			var rect := panel.get_global_rect()
			_check(panel.visible and hud.get_viewport_rect().encloses(rect),
				"Der Aktionshinweis bleibt im Fenster bei %s" % window_size)
			_check(rect.grow(0.1).encloses(hint.get_global_rect()) \
					and hint.get_visible_line_count() == hint.get_line_count(),
				"Auch lange Hinweise und Fehler werden vollstaendig angezeigt")
			_check(hint.get_theme_font_size("font_size") == 12,
				"Der kompakte Aktionshinweis behaelt seine bisherige Schriftgroesse")
			if text == HOME_HINT_LAYOUT_CASES[0]:
				_check(rect.get_area() <= HOME_HINT_REFERENCE_AREA * COMPACT_AREA_RATIO,
					"Die Aktionsbox bleibt auch nach langem Text mindestens 30 Prozent kleiner")
			for node_name in ["Joystick", "ActionButton", "RotateButton", "StoreButton"]:
				var control: Control = touch.get_node("Root/" + node_name)
				_check(not rect.intersects(control.get_global_rect()),
					"Der Aktionshinweis laesst %s frei" % node_name)
		hud.show_toast("Futter ist bereit.")
		await _wait(0.1)
		_check(toast.visible and toast.get_global_rect().end.y <= panel.get_global_rect().position.y - 8.0,
			"Kurzzeitige Meldungen halten Abstand zum sichtbaren Aktionshinweis")
		hud.set_hint("")
		await _wait(0.1)
		_check(not panel.visible and is_equal_approx(toast.get_global_rect().end.y,
				hud.get_viewport_rect().end.y - 8.0),
			"Ohne Aktionshinweis bleibt kein reservierter Abstand unter der Meldung")
	for kind in ["pause", "furnish", "shop", "supplies"]:
		hud.set_hint(HOME_HINT_LAYOUT_CASES[0])
		hud.open_modal(kind)
		hud.set_hint(HOME_HINT_LAYOUT_CASES[1])
		_check(not panel.visible, "Im Menue %s bleibt die Spielhilfe ausgeblendet" % kind)
		hud.close_modal()
		_check(not panel.visible and hint.text.is_empty(),
			"Beim Schliessen wird kein veralteter Handlungskontext eingeblendet")
		hud.set_hint(HOME_HINT_LAYOUT_CASES[0])
		_check(panel.visible, "Ein neuer Handlungskontext zeigt die Hilfe wieder an")
	_check_passive_panel(panel)
	window.size = original_size
	touch.queue_free()
	hud.queue_free()
	await _wait(0.1)


func _home_action(home: Node, button_name: String = "ActionButton") -> void:
	await _wait(0.05)
	var button: Button = home.get_node("TouchControls/Root/" + button_name)
	button.button_down.emit()
	await _wait(0.06)
	button.button_up.emit()
	await _wait(0.06)


func _test_touch_furnishing() -> void:
	print("--- Echte Touch-Gesten beim Einrichten ---")
	GameState.reset()
	var home := await _load_scene("res://scenes/home/home_scene.tscn")
	if home == null:
		return
	var touch: CanvasLayer = home.get_node("TouchControls")
	touch.call("set_forced", true)
	var hud: HomeHUD = home.get("hud")
	var player: Player = home.get_node("Player")
	var food := GameState.home.item_by_id("starter_food")
	var original_cell := food.cell
	var emulation_before := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	await _screen_tap(hud.get_node("%FurnishButton"))
	_check(hud.modal_kind == "furnish", "Eine echte Beruehrung oeffnet den Einrichtungskatalog")
	if hud.modal_kind == "furnish":
		await _screen_tap(hud.get_node("%Select_starter_food"))
		var preview: HomeItemActor = home.get("_preview")
		_check(preview != null and not get_tree().paused,
			"Eine echte Beruehrung waehlt einen Gegenstand zum Versetzen")
		if preview != null:
			var joystick: TouchJoystick = home.get_node("TouchControls/Root/Joystick")
			var movement_hint: Label = home.get_node("TouchControls/Root/MovementHint")
			_check(joystick.show_idle_hint and movement_hint.is_visible_in_tree(),
				"Der Joystick ist beim Einrichten schon vor der ersten Beruehrung erkennbar")
			var hint: Label = hud.get("_hint")
			_check(hint.text.contains("Joystick") and not hint.text.contains("R drehen"),
				"Der Einrichtungshinweis beschreibt die Touch-Bedienung")
			var origin := joystick.get_global_rect().get_center()
			var start := player.position
			_screen_touch(origin, 0, true)
			await _wait(0.05)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = origin + Vector2(0, -60)
			drag.relative = Vector2(0, -60)
			get_viewport().push_input(drag, true)
			await _wait(0.6)
			_check(player.position.y < start.y - 20,
				"Ein Finger am Joystick bewegt Spielfigur und Platzierungsvorschau")
			await _screen_tap(home.get_node("TouchControls/Root/ActionButton"), 1)
			_check(home.get("_preview") == null and food.cell != original_cell,
				"Ein zweiter Finger stellt den Gegenstand waehrend der Joystick-Geste um")
			_check(Input.is_action_pressed("move_up"),
				"Der zweite Finger unterbricht den gehaltenen Joystick nicht")
			_check(not joystick.show_idle_hint and not movement_hint.is_visible_in_tree(),
				"Nach dem Aufstellen kehrt die normale dynamische Touch-Anzeige zurueck")
			_screen_touch(drag.position, 0, false)
			await _wait(0.1)
			_check(Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx(),
				"Nach dem Loslassen bleiben keine Bewegungsaktionen aktiv")
	Input.emulate_mouse_from_touch = emulation_before
	home.queue_free()
	await _wait(0.2)


func _screen_tap(control: Control, index: int = 0) -> void:
	var point := control.get_global_rect().get_center()
	_screen_touch(point, index, true)
	await _wait(0.06)
	_screen_touch(point, index, false)
	await _wait(0.2)


func _screen_touch(point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	get_viewport().push_input(event, true)
# --- Rettung -----------------------------------------------------------------

func _test_rescue() -> void:
	print("--- Rettungs-Level ---")
	GameState.reset()

	var level := await _load_scene("res://scenes/rescue/rescue_level.tscn")
	if level == null:
		return

	var player: Player = level.get_node("Player")
	var hud: Control = level.get_node("UI/HUD")
	var indicator := hud.get_node_or_null("HomeIndicator") as HomeIndicator
	_check(indicator != null, "Der Wegweiser ist Teil des Rettungs-HUD")
	if indicator != null:
		_check(indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Der Wegweiser faengt weder Maus noch Touch ab")
		_check(indicator.get_index() < hud.get_node("%PauseDim").get_index(),
			"Die Pausenabdunklung liegt ueber dem Wegweiser")
		_check_home_navigation(level, "ohne getragene Katze")
		await _test_home_navigation(level)

	# Pause auf und wieder zu.
	hud.call("toggle_pause")
	await _wait(0.2)
	_check(get_tree().paused, "Pause haelt das Spiel an")
	if indicator != null:
		_check_home_navigation(level, "in der Pause")
	hud.call("toggle_pause")
	await _wait(0.2)
	_check(not get_tree().paused, "Pause laesst sich wieder aufheben")

	# Aufheben ins Leere -- darf nicht knallen.
	level.call("_try_pick_up")
	await _wait(0.1)
	_check(true, "Aufheben ohne Katze in Reichweite bricht nichts")

	# Mit vollem Korb eine weitere Katze anfassen.
	while GameState.can_carry_more():
		GameState.pick_up_cat(CatData.create_random())
	level.call("_try_pick_up")
	await _wait(0.1)
	_check(true, "Aufheben mit vollem Korb bricht nichts")
	if indicator != null:
		_check_home_navigation(level, "mit vollem Korb")

	# Getragene Katzen erscheinen ueber dem Kopf.
	var carry_slot: Node2D = player.get_node("CarrySlot")
	_check(carry_slot.get_child_count() == GameState.carried_cats.size(),
		"Getragene Katzen werden angezeigt (%d)" % carry_slot.get_child_count())

	# Schreck: eine Katze entwischt und wird neu ausgesetzt.
	var before := GameState.carried_cats.size()
	var cats_before := get_tree().get_nodes_in_group("cats").size()
	var lost := player.startle()
	_check(lost != null, "Ein Schreck laesst eine Katze entwischen")
	if lost != null:
		level.call("on_cat_escaped", lost, player.global_position)
		await _wait(0.2)
		_check(GameState.carried_cats.size() == before - 1, "Der Korb enthaelt danach eine weniger")
		# Das Aussetzen laeuft verzoegert (Physik-Rueckruf) -- es muss trotzdem
		# tatsaechlich passieren.
		_check(get_tree().get_nodes_in_group("cats").size() == cats_before + 1,
			"Die entwischte Katze streunt wieder im Level")

	# Waehrend der Betaeubung darf ein zweiter Schreck nichts tun.
	var during_stun := player.startle()
	_check(during_stun == null, "Waehrend der Betaeubung erschrickt man nicht erneut")

	# Autos und Hunde einmal laufen lassen.
	await _wait(1.5)
	var cars := 0
	var dogs := 0
	for child in level.get_node("Entities").get_children():
		if child is Car:
			cars += 1
		elif child is Dog:
			dogs += 1
	_check(cars > 0, "Autos fahren im Level (%d)" % cars)
	_check(dogs > 0, "Hunde streunen im Level (%d)" % dogs)

	# Abliefern in der Heimzone.
	GameState.pick_up_cat(CatData.create_random())
	player.global_position = level.get_node("HomeZone").global_position
	await _wait(0.4)
	_check(GameState.carried_cats.is_empty(), "In der Heimzone werden Katzen abgegeben")
	if indicator != null:
		_check_home_navigation(level, "nach dem Abliefern")

	level.queue_free()
	await _wait(0.2)
	_check(not is_instance_valid(indicator), "Der Wegweiser endet mit der Rettungsszene")


func _test_home_navigation(level: Node) -> void:
	print("--- Wegweiser: Kamera, Fenster und Touch ---")
	var player: Player = level.get_node("Player")
	var camera: Camera2D = level.get_node("Player/Camera")
	var home_zone: Node2D = level.get_node("HomeZone")
	var touch: CanvasLayer = level.get_node("TouchControls")
	var window := get_tree().root
	var original_size := window.size
	var original_position := player.global_position
	var original_zoom := camera.zoom
	var original_smoothing := camera.position_smoothing_enabled
	var original_physics := player.is_physics_processing()
	var original_forced: bool = touch.call("is_forced")

	player.set_physics_process(false)
	camera.position_smoothing_enabled = false
	for window_size in UI_WINDOW_SIZES:
		window.size = window_size
		await _wait(0.1)
		_check(is_equal_approx(player.get_viewport_rect().size.aspect(), Vector2(window_size).aspect()),
			"Der Viewport uebernimmt das Fensterformat %s" % window_size)
		for zoom in NAVIGATION_ZOOMS:
			camera.zoom = zoom
			var positions: Array[Vector2] = [
				home_zone.global_position + Vector2(0, 32),
				Vector2(camera.limit_right - 32, 32),
				Vector2(camera.limit_right - 32, camera.limit_bottom - 32),
			]
			for position in positions:
				player.global_position = position
				camera.reset_smoothing()
				camera.force_update_scroll()
				touch.call("set_forced", false)
				await _wait(0.1)
				_check_home_navigation(level, "bei %s, Zoom %s" % [window_size, zoom])
				touch.call("set_forced", true)
				await _wait(0.1)
				_check_home_navigation(level, "mit Touch bei %s, Zoom %s" % [window_size, zoom])

	window.size = original_size
	camera.zoom = original_zoom
	player.global_position = original_position
	camera.force_update_scroll()
	camera.reset_smoothing()
	camera.position_smoothing_enabled = true
	await _wait(0.1)
	player.global_position += Vector2(150, 60)
	for i in 4:
		await _wait(0.03)
		_check_home_navigation(level, "waehrend der Kameranachfuehrung")

	player.global_position = original_position
	camera.position_smoothing_enabled = original_smoothing
	camera.reset_smoothing()
	camera.force_update_scroll()
	player.set_physics_process(original_physics)
	touch.call("set_forced", original_forced)
	await _wait(0.1)


func _check_home_navigation(level: Node, context: String) -> void:
	var hud: Control = level.get_node("UI/HUD")
	var indicator: HomeIndicator = hud.get_node("HomeIndicator")
	var home_zone: Node2D = level.get_node("HomeZone")
	_check(indicator.is_visible_in_tree() and indicator.is_processing()
		and bool(indicator.get("_has_target")), "Wegweiser bleibt sichtbar: %s" % context)

	var hud_inverse := indicator.get_global_transform_with_canvas().affine_inverse()
	var target: Vector2 = hud_inverse * home_zone.get_global_transform_with_canvas().origin
	var viewport_rect: Rect2 = hud_inverse * indicator.get_viewport_rect()
	var radius := Vector2.ONE * HomeIndicator.MARKER_RADIUS
	var marker_rect := Rect2(indicator.marker_position - radius, radius * 2.0)
	var direction := target - indicator.marker_position
	_check(indicator.marker_position.is_finite() and is_finite(indicator.marker_angle)
		and viewport_rect.encloses(marker_rect), "Pfeil bleibt vollstaendig im Bild: %s" % context)
	_check(direction.is_zero_approx()
		or Vector2.from_angle(indicator.marker_angle).dot(direction.normalized()) > 0.999,
		"Pfeil zeigt auf die tatsaechliche Bildschirmposition des Zuhauses: %s" % context)

	if viewport_rect.has_point(target):
		_check(indicator.marker_position.distance_to(target) < 160.0,
			"Sichtbares Zuhause wird direkt markiert: %s" % context)
	else:
		var bounds := viewport_rect.grow(-HomeIndicator.MARKER_RADIUS - HomeIndicator.EDGE_GAP)
		var position := indicator.marker_position
		_check(is_equal_approx(position.x, bounds.position.x)
			or is_equal_approx(position.x, bounds.end.x)
			or is_equal_approx(position.y, bounds.position.y)
			or is_equal_approx(position.y, bounds.end.y),
			"Nicht sichtbares Zuhause bekommt einen Randpfeil: %s" % context)

	var controls: Array[Control] = [
		hud.get_node("TopLeft"), hud.get_node("%HomeButton"), hud.get_node("%HintLabel"),
		level.get_node("HomeZone/Label"), level.get_node("TouchControls/Root/Joystick"),
		level.get_node("TouchControls/Root/ActionButton"), level.get_node("TouchControls/Root/SprintButton"),
	]
	var clear := true
	for control in controls:
		if control.is_visible_in_tree():
			var rect: Rect2 = (hud_inverse * control.get_global_transform_with_canvas()
				* Rect2(Vector2.ZERO, control.size))
			if marker_rect.intersects(rect.grow(HomeIndicator.UI_GAP - 0.01)):
				clear = false
	_check(clear, "Wegweiser laesst HUD, Beschriftung und Touch-Bedienung frei: %s" % context)


# --- Szenenwechsel -----------------------------------------------------------

func _test_scene_transitions() -> void:
	print("--- Szenenwechsel ---")
	# Der SceneRouter blendet ab, wechselt und blendet wieder auf. Dabei wird
	# gespeichert -- ein guter Anlass fuer Fehler.
	for path in [SceneRouter.HOME, SceneRouter.RESCUE, SceneRouter.MAIN_MENU]:
		SceneRouter.goto_scene(path)
		await _wait(2.0)
		var current := get_tree().current_scene
		_check(current != null, "Wechsel nach %s liefert eine Szene" % path.get_file())
		if current != null:
			var indicator := current.get_node_or_null("UI/HUD/HomeIndicator")
			_check((indicator != null) == (path == SceneRouter.RESCUE),
				"Der Wegweiser erscheint nur in der Rettungsszene")

	# Zwei Wechsel kurz hintereinander -- der zweite muss abprallen, statt
	# mitten im Uebergang eine halb geladene Szene zu hinterlassen.
	SceneRouter.goto_scene(SceneRouter.HOME)
	SceneRouter.goto_scene(SceneRouter.RESCUE)
	await _wait(2.0)
	var after := get_tree().current_scene
	_check(after != null and after.name == "HomeScene",
		"Bei zwei Wechseln kurz hintereinander gewinnt der erste (%s)"
			% [after.name if after != null else "keine"])


# --- Hilfen ------------------------------------------------------------------

func _load_scene(path: String, properties: Dictionary = {}) -> Node:
	if not ResourceLoader.exists(path):
		_check(false, "Szene vorhanden: %s" % path)
		return null
	var scene: PackedScene = load(path)
	var node: Node = scene.instantiate()
	for key: String in properties:
		node.set(key, properties[key])
	get_tree().root.add_child(node)
	await get_tree().process_frame
	await get_tree().physics_frame
	return node


func _node(root: Node, unique_path: String) -> Node:
	var found := root.get_node_or_null(unique_path)
	if found == null:
		_check(false, "Knoten fehlt: %s" % unique_path)
	return found


func _press(root: Node, unique_path: String) -> void:
	var button := _node(root, unique_path) as Button
	if button != null:
		button.pressed.emit()


func _click_control(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _send_ui_action(action: StringName, target: Viewport = null) -> void:
	if target != null:
		# Eingebettete Fenster erhalten Eingaben ueber ihren Eltern-Viewport.
		var input_target: Viewport = target
		if target is Window and target.is_embedded():
			input_target = target.get_parent().get_viewport()
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey:
				for pressed: bool in [true, false]:
					var key := binding.duplicate() as InputEventKey
					key.pressed = pressed
					key.echo = false
					input_target.push_input(key)
				return
		_check(false, "Tastaturbelegung fehlt fuer %s" % action)
		return
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _check_focus_within(panel: Control, context: String) -> void:
	for action in MENU_FOCUS_ACTIONS:
		_send_ui_action(action)
		var focused := get_viewport().gui_get_focus_owner()
		_check(focused != null and (focused == panel or panel.is_ancestor_of(focused)),
			"Der Fokus bleibt im Dialog: %s (%s)" % [context, action])


## Wartet echte Sekunden.
##
## Frames zu zaehlen und mit 1/60 zu multiplizieren geht hier nicht: headless
## rendert ohne Bildsynchronisierung mit weit ueber 60 Bildern je Sekunde, ein
## "Warten" von 4 Sekunden waere in Wirklichkeit ein Bruchteil davon. Die
## Blenden des SceneRouter laufen aber in echter Zeit.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


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
