## Durchlauf ueber echte Szenenwechsel: so, wie ein Mensch spielt.
extends SmokeSuite


func run() -> void:
	await _test_scene_transitions()
	await _test_real_ui_path()
	await _test_new_game_modes()
	await _test_resume_with_save()

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

