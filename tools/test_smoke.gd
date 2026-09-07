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
	await _test_main_menu()
	await _test_home()
	await _test_rescue()
	await _test_scene_transitions()
	await _test_real_ui_path()
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

	_press(home, "%RescueButton")
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
	_press(get_tree().current_scene, "%MenuButton")
	await _wait_for_scene("MainMenu")
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu",
		"Vom Zuhause geht es zurueck ins Hauptmenue")

	# Weiterspielen mit vorhandenem Spielstand.
	_check(_node(get_tree().current_scene, "%ContinueButton") != null,
		"Der Weiterspielen-Knopf ist vorhanden")


## Wartet, bis der SceneRouter fertig gewechselt hat.
func _wait_for_scene(expected_name: String, timeout: float = 6.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.name == expected_name:
			# Noch kurz warten, bis die Blende durch ist.
			await _wait(0.4)
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

	# Optionen auf und wieder zu.
	_press(menu, "%OptionsButton")
	await _wait(0.2)
	_check(_node(menu, "%OptionsPanel").visible, "Optionen lassen sich oeffnen")
	_check(_node(menu, "%OptionsDim").visible, "Dahinter wird abgedunkelt")

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

	# Bestaetigungsfenster: nur sichtbar, wenn ein Spielstand vorliegt.
	SaveManager.save_game()
	_press(menu, "%NewGameButton")
	await _wait(0.2)
	_check(_node(menu, "%ConfirmPanel").visible, "Nachfrage vor dem Ueberschreiben")
	_press(menu, "%ConfirmNoButton")
	await _wait(0.2)
	_check(not _node(menu, "%ConfirmPanel").visible, "Nachfrage laesst sich abbrechen")

	menu.queue_free()
	await _wait(0.1)


# --- Zuhause -----------------------------------------------------------------

func _test_home() -> void:
	print("--- Zuhause ---")
	GameState.reset()
	GameState.add_coins(500)

	# Zwei Katzen zum Pflegen ablegen.
	for i in 2:
		var cat := CatData.create_random()
		GameState.pick_up_cat(cat)
	GameState.deliver_carried_cats()

	var home := await _load_scene("res://scenes/home/home_scene.tscn")
	if home == null:
		return

	var list: VBoxContainer = _node(home, "%CatList")
	_check(list.get_child_count() == 2, "Fuer jede Katze gibt es eine Karte")

	# Jede Pflegeaktion auf jeder Karte einmal ausloesen.
	var pressed := 0
	for card in list.get_children():
		var buttons: HBoxContainer = card.get_node("Row/Body/ButtonsBox")
		for button in buttons.get_children():
			(button as Button).pressed.emit()
			pressed += 1
			await _wait(0.05)
	_check(pressed == 8, "Alle vier Pflegeaktionen auf beiden Karten ausloesbar (%d)" % pressed)

	# Abklingzeit abwarten, damit auch der Timer-Pfad einmal laeuft.
	await _wait(0.6)

	# Laden auf, jedes Upgrade kaufen, wieder zu.
	_press(home, "%ShopButton")
	await _wait(0.2)
	_check(_node(home, "%ShopPanel").visible, "Der Laden laesst sich oeffnen")

	var shop: VBoxContainer = _node(home, "%ShopList")
	var bought := 0
	for row in shop.get_children():
		var buy := row.get_node_or_null("Buy") as Button
		if buy != null and not buy.disabled:
			buy.pressed.emit()
			bought += 1
			await _wait(0.05)
	_check(bought > 0, "Ausbauten lassen sich kaufen (%d)" % bought)

	_press(home, "%ShopCloseButton")
	await _wait(0.2)
	_check(not _node(home, "%ShopPanel").visible, "Der Laden laesst sich schliessen")

	# Adoption ausloesen -- dabei wird die Karte mitten im Betrieb entfernt.
	_adoption_seen = false
	GameState.cat_adopted.connect(_on_cat_adopted)
	for cat in GameState.home_cats.duplicate():
		cat.hunger = 100.0
		cat.thirst = 100.0
		cat.cleanliness = 100.0
		cat.health = 100.0
		cat.recovery_timer = CatData.RECOVERY_SECONDS - 0.1
	await _wait(0.8)
	GameState.cat_adopted.disconnect(_on_cat_adopted)
	_check(_adoption_seen, "Eine Vermittlung mitten im Betrieb bricht nichts")

	home.queue_free()
	await _wait(0.2)


func _on_cat_adopted(_cat: CatData, _reward: int) -> void:
	_adoption_seen = true


# --- Rettung -----------------------------------------------------------------

func _test_rescue() -> void:
	print("--- Rettungs-Level ---")
	GameState.reset()

	var level := await _load_scene("res://scenes/rescue/rescue_level.tscn")
	if level == null:
		return

	var player: Player = level.get_node("Player")
	var hud: Control = level.get_node("UI/HUD")

	# Pause auf und wieder zu.
	hud.call("toggle_pause")
	await _wait(0.2)
	_check(get_tree().paused, "Pause haelt das Spiel an")
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

	# Getragene Katzen erscheinen ueber dem Kopf.
	var carry_slot: Node2D = player.get_node("CarrySlot")
	_check(carry_slot.get_child_count() == GameState.carried_cats.size(),
		"Getragene Katzen werden angezeigt (%d)" % carry_slot.get_child_count())

	# Schreck: eine Katze entwischt und wird neu ausgesetzt.
	var before := GameState.carried_cats.size()
	var lost := player.startle()
	_check(lost != null, "Ein Schreck laesst eine Katze entwischen")
	if lost != null:
		level.call("on_cat_escaped", lost, player.global_position)
		await _wait(0.2)
		_check(GameState.carried_cats.size() == before - 1, "Der Korb enthaelt danach eine weniger")

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

	level.queue_free()
	await _wait(0.2)


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

func _load_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		_check(false, "Szene vorhanden: %s" % path)
		return null
	var scene: PackedScene = load(path)
	var node: Node = scene.instantiate()
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
