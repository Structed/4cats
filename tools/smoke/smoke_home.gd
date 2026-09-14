## Durchlauf durch das Zuhause: Fenster, Katzenstatus, Hinweise, Einrichten.
extends SmokeSuite

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

## Wird per Signal gesetzt. Muss ein Feld sein, kein lokaler Wert: GDScript
## erfasst einfache Typen in Lambdas als Kopie, eine lokale bool bliebe false.
var _adoption_seen: bool = false


func run() -> void:
	await _test_home()
	await _test_adoption_status()
	await _test_home_hint_layout()
	await _test_touch_furnishing()

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

