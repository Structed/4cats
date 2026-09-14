## Prueft die Abschnitte des Spielstands.
##
## Aufruf ueber tools/test_gameplay.gd (`--test`).
##
## Der wichtigste Test liest scripts/state/ vom Datentraeger: ein neuer
## Abschnitt, den niemand im Spielzustand eingetragen hat, wuerde stumm nicht
## gespeichert -- der Spieler merkt das erst, wenn sein Fortschritt fehlt.
extends RefCounted

const SECTION_DIR := "res://scripts/state"

var _failures: PackedStringArray = []


func run() -> PackedStringArray:
	_failures = []
	_test_registry_is_complete()
	_test_fields_reach_the_save()
	_test_roundtrip()
	_test_every_section_can_reject()
	_test_upgrade_catalog()
	return _failures


## Jeder Abschnitt auf dem Datentraeger muss im Spielzustand eingetragen sein.
func _test_registry_is_complete() -> void:
	var saved := GameState.to_dict()
	var found := 0
	for file in DirAccess.get_files_at(SECTION_DIR):
		if not file.ends_with(".gd"):
			continue
		var section_script: GDScript = load("%s/%s" % [SECTION_DIR, file])
		if section_script == null or not section_script.can_instantiate():
			_check(false, "Abschnitt %s laesst sich nicht laden." % file)
			continue
		var section: Variant = section_script.new()
		if section is not SaveSection:
			continue
		var probe := {}
		section.reset(DifficultyRules.DEFAULT)
		section.write(probe)
		if probe.is_empty():
			continue
		found += 1
		for key: String in probe:
			_check(saved.has(key),
				"Abschnitt %s schreibt „%s“, der Spielstand kennt das Feld nicht." % [file, key])
	_check(found >= 6, "Es wurden nur %d Abschnitte gefunden." % found)


## Die weitergereichten Felder muessen auf denselben Abschnitt zeigen, der
## gespeichert wird -- sonst geht eine Aenderung beim Speichern verloren.
func _test_fields_reach_the_save() -> void:
	var before := GameState.to_dict()
	GameState.coins += 7
	GameState.rescued_total += 3
	var after := GameState.to_dict()
	_check(int(after["coins"]) == int(before["coins"]) + 7,
		"Geaenderte Muenzen erreichen den Spielstand nicht.")
	_check(int(after["rescued_total"]) == int(before["rescued_total"]) + 3,
		"Geaenderte Zaehler erreichen den Spielstand nicht.")
	GameState.coins -= 7
	GameState.rescued_total -= 3
	_check(GameState.upgrade_levels.has("carry_capacity"),
		"Die Ausbaustufen sind nicht mehr erreichbar.")
	_check(GameState.supplies != null and GameState.home != null
		and GameState.analytics != null,
		"Vorraete, Haus oder Statistik sind nicht mehr erreichbar.")


func _test_roundtrip() -> void:
	var snapshot := GameState.to_dict()
	_check(GameState.from_dict(snapshot.duplicate(true)),
		"Der eigene Spielstand laesst sich nicht wieder laden.")
	_check(JSON.stringify(GameState.to_dict()) == JSON.stringify(snapshot),
		"Speichern und Laden ergibt einen anderen Zustand.")


## Zu jedem Abschnitt gehoert ein Fehlerfall. Wird einer abgelehnt, darf der
## laufende Zustand sich nicht veraendert haben.
func _test_every_section_can_reject() -> void:
	var cases := {
		"Fortschritt": func(data: Dictionary) -> void: data["coins"] = -5,
		"Ausbauten": func(data: Dictionary) -> void: data["upgrade_levels"] = "kaputt",
		"Katzen": func(data: Dictionary) -> void: data["home_cats"] = "kaputt",
		"Vorraete": func(data: Dictionary) -> void: data["supplies"] = 42,
		"Haus": func(data: Dictionary) -> void: data.erase("home"),
		"Statistik": func(data: Dictionary) -> void: data.erase("analytics"),
	}
	var snapshot := JSON.stringify(GameState.to_dict())
	for name: String in cases:
		var broken := GameState.to_dict()
		var damage: Callable = cases[name]
		damage.call(broken)
		_check(not GameState.from_dict(broken),
			"Ein beschaedigter Abschnitt „%s“ wird angenommen." % name)
		_check(JSON.stringify(GameState.to_dict()) == snapshot,
			"Nach dem abgelehnten Abschnitt „%s“ ist der Zustand veraendert." % name)


func _test_upgrade_catalog() -> void:
	for id: String in UpgradeCatalog.ENTRIES:
		_check(not UpgradeCatalog.label(id).is_empty(),
			"Ausbau „%s“ hat keinen Namen." % id)
		_check(not UpgradeCatalog.description(id).is_empty(),
			"Ausbau „%s“ hat keine Beschreibung." % id)
		var top := UpgradeCatalog.max_level(id)
		_check(top > 0, "Ausbau „%s“ hat keine Stufen." % id)
		_check(UpgradeCatalog.cost_at(id, 0) > 0,
			"Ausbau „%s“ kostet auf Stufe 1 nichts." % id)
		_check(UpgradeCatalog.cost_at(id, top) == -1,
			"Ausbau „%s“ laesst sich ueber die letzte Stufe hinaus kaufen." % id)
		_check(UpgradeCatalog.cost_at(id, -1) == -1,
			"Ausbau „%s“ liefert einen Preis fuer eine ungueltige Stufe." % id)
	_check(UpgradeCatalog.max_level("gibtsnicht") == 0,
		"Ein unbekannter Ausbau meldet Stufen.")
	_check(UpgradeCatalog.cost_at("gibtsnicht", 0) == -1,
		"Ein unbekannter Ausbau meldet einen Preis.")
	_check(GameState.UPGRADES.size() == UpgradeCatalog.ENTRIES.size(),
		"Der Spielzustand kennt andere Ausbauten als der Katalog.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
