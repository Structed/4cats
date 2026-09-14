## Regeln der Bedienelement-Fabrik und der Symbolzuordnung.
##
## Die Suite sichert vor allem zwei Dinge ab, die sonst erst im fertigen Spiel
## auffallen wuerden:
##
## 1. Jede Zuordnung in `IconSet.BUTTON_ICONS` zeigt auf ein Symbol, das es im
##    Atlas wirklich gibt. Ein Tippfehler dort waere sonst unsichtbar -- der
##    Knopf bekaeme einfach kein Symbol.
## 2. In der Darstellung ICON_ONLY bleibt die Bedeutung jedes Knopfes ueber den
##    Tooltip erhalten, auch wenn sich die Beschriftung zur Laufzeit aendert.
extends RefCounted

var _failures: PackedStringArray = []


func run() -> PackedStringArray:
	var previous := UiKit.icon_mode()
	_test_registry()
	_test_atlas()
	_test_factory()
	_test_icon_modes()
	_test_runtime_text()
	UiKit.set_icon_mode(previous)
	IconSet.clear_cache()
	return _failures


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FEHLER", description])
	if not condition:
		_failures.append(description)


func _test_registry() -> void:
	print("--- Bedienelemente: Symbolzuordnung ---")
	var unknown: PackedStringArray = []
	for node_name: String in IconSet.BUTTON_ICONS:
		var icon_name: String = String(IconSet.BUTTON_ICONS[node_name])
		if not IconSet.ICONS.has(icon_name):
			unknown.append("%s -> %s" % [node_name, icon_name])
	_check(unknown.is_empty(),
		"Jede Knopfzuordnung zeigt auf ein vorhandenes Symbol%s"
			% ("" if unknown.is_empty() else ": " + ", ".join(unknown)))

	var bad_prefix: PackedStringArray = []
	for prefix: String in IconSet.BUTTON_PREFIXES:
		var mapped: String = String(IconSet.BUTTON_PREFIXES[prefix])
		if not mapped.is_empty() and not IconSet.ICONS.has(mapped):
			bad_prefix.append(prefix)
	_check(bad_prefix.is_empty(), "Jeder Knopf-Praefix zeigt auf ein vorhandenes Symbol")

	_check(IconSet.for_button("PauseButton") == "pause",
		"Ein eingetragener Knotenname liefert sein Symbol")
	_check(IconSet.for_button("Buy_food") == "food",
		"Ein Kaufknopf leitet sein Symbol aus dem Gegenstand ab")
	_check(IconSet.for_button("Upgrade_pantry") == "upgrade",
		"Ein Ausbauknopf nutzt das gemeinsame Ausbau-Symbol")
	_check(IconSet.for_button("Buy_gibtsnicht").is_empty(),
		"Ein unbekannter Gegenstand liefert kein Symbol statt eines falschen")
	_check(IconSet.for_button("VoelligUnbekannt").is_empty(),
		"Ein Knopf ohne Zuordnung bleibt ohne Symbol")


func _test_atlas() -> void:
	print("--- Bedienelemente: Symbolatlas ---")
	if not ResourceLoader.exists(IconSet.ATLAS_PATH):
		# Ohne Atlas laeuft das Spiel bewusst weiter -- also kein Fehler.
		_check(true, "Ohne Atlas bleiben alle Knoepfe bei ihrer Beschriftung")
		return
	var atlas := load(IconSet.ATLAS_PATH) as Texture2D
	_check(atlas != null, "Der Symbolatlas laesst sich laden")
	if atlas == null:
		return
	var expected := IconSet.ICONS.size() * IconSet.CELL
	_check(atlas.get_width() == expected,
		"Der Atlas hat eine Zelle je Symbol (erwartet %d, gemessen %d)"
			% [expected, atlas.get_width()])
	_check(atlas.get_height() == IconSet.CELL,
		"Der Atlas ist genau eine Zelle hoch")
	var last_name := ""
	var last_column := -1
	for icon_name: String in IconSet.ICONS:
		var column: int = IconSet.ICONS[icon_name]
		if column > last_column:
			last_column = column
			last_name = icon_name
	var region := IconSet.texture(last_name) as AtlasTexture
	_check(region != null and region.region.end.x <= float(atlas.get_width()),
		"Das letzte Symbol liegt noch innerhalb des Atlas")


func _test_factory() -> void:
	print("--- Bedienelemente: Fabrik ---")
	UiKit.set_icon_mode(UiKit.IconMode.TEXT_ONLY)
	var box := VBoxContainer.new()
	var button := UiKit.button("Kaufen", "BuyFoodButton", box, 14, 40)
	_check(button.name == "BuyFoodButton", "Der Knopf traegt den verlangten Knotennamen")
	_check(button.text == "Kaufen", "Der Knopf traegt seine Beschriftung")
	_check(button.get_parent() == box, "Der Knopf haengt am angegebenen Elternknoten")
	_check(is_equal_approx(button.custom_minimum_size.y, 40.0),
		"Die Mindesthoehe wird uebernommen")
	_check(button.get_theme_font_size("font_size") == 14,
		"Die Schriftgroesse wird uebernommen")
	var themed := UiKit.button("Ohne", "ThemedButton", box, 0)
	_check(not themed.has_theme_font_size_override("font_size"),
		"Schriftgroesse 0 laesst dem Theme den Vortritt")
	_check(UiKit.label("Hinweis", 11, box).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Ein Textfeld faengt keine Eingaben ab")
	box.free()


func _test_icon_modes() -> void:
	print("--- Bedienelemente: Darstellungsarten ---")
	var has_atlas := ResourceLoader.exists(IconSet.ATLAS_PATH)

	UiKit.set_icon_mode(UiKit.IconMode.TEXT_ONLY)
	var plain := UiKit.button("Pause", "PauseButton")
	_check(plain.icon == null and plain.text == "Pause",
		"Ohne Symbolmodus bleibt der Knopf unveraendert")
	plain.free()

	UiKit.set_icon_mode(UiKit.IconMode.TEXT_AND_ICON)
	var both := UiKit.button("Pause", "PauseButton")
	_check(both.text == "Pause", "Mit Symbol bleibt die Beschriftung erhalten")
	_check((both.icon != null) == has_atlas,
		"Das Symbol erscheint genau dann, wenn der Atlas vorhanden ist")
	both.free()

	var unmapped := UiKit.button("Sonstiges", "VoelligUnbekannt")
	_check(unmapped.icon == null and unmapped.text == "Sonstiges",
		"Ein Knopf ohne Zuordnung behaelt seine Beschriftung")
	unmapped.free()

	UiKit.set_icon_mode(UiKit.IconMode.ICON_ONLY)
	var icon_only := UiKit.button("Pause", "PauseButton")
	if has_atlas:
		_check(icon_only.text.is_empty() and icon_only.tooltip_text == "Pause",
			"Nur-Symbol verschiebt die Beschriftung in den Tooltip")
		_check(icon_only.custom_minimum_size.x > 0.0,
			"Ein Knopf ohne Text behaelt eine Mindestbreite")
		_check(icon_only.alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"Ein Knopf ohne Text zeigt sein Symbol mittig")
	else:
		_check(icon_only.text == "Pause",
			"Ohne Atlas bleibt die Beschriftung auch im Nur-Symbol-Modus stehen")
	_check(UiKit.button_text(icon_only) == "Pause",
		"Die Beschriftung ist in jeder Darstellungsart abfragbar")
	icon_only.free()


func _test_runtime_text() -> void:
	print("--- Bedienelemente: Beschriftung zur Laufzeit ---")
	var has_atlas := ResourceLoader.exists(IconSet.ATLAS_PATH)

	UiKit.set_icon_mode(UiKit.IconMode.TEXT_AND_ICON)
	var button := UiKit.button("Einrichten", "FurnishButton")
	UiKit.set_button_text(button, "Abbrechen")
	_check(button.text == "Abbrechen", "Mit Beschriftung aendert sich der sichtbare Text")

	UiKit.set_icon_mode(UiKit.IconMode.ICON_ONLY)
	var silent := UiKit.button("Einrichten", "FurnishButton")
	UiKit.set_button_text(silent, "Abbrechen")
	if has_atlas:
		_check(silent.text.is_empty() and silent.tooltip_text == "Abbrechen",
			"Nur-Symbol laesst auch geaenderte Beschriftungen nicht durch")
	else:
		_check(silent.text == "Abbrechen",
			"Ohne Atlas bleibt die geaenderte Beschriftung sichtbar")

	var decorated := Button.new()
	decorated.name = "PauseButton"
	decorated.text = "Pause"
	UiKit.decorate(decorated)
	_check((decorated.icon != null) == has_atlas,
		"Auch ein in der Szene angelegter Knopf bekommt sein Symbol")

	var forced := Button.new()
	forced.name = "Select_toy"
	forced.text = "Spielzeug"
	UiKit.decorate(forced, "toy")
	_check((forced.icon != null) == has_atlas,
		"Ein ausdruecklich genanntes Symbol kommt ohne Zuordnung aus")

	button.free()
	silent.free()
	decorated.free()
	forced.free()
