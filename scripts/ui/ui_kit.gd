## Gemeinsame Fabrik fuer Bedienelemente.
##
## Vorher entstanden Knoepfe an 25 Stellen in sechs Dateien und in drei
## verschiedenen Stilen. Jede durchgaengige Aenderung -- etwa "jeder Knopf
## bekommt ein Symbol" -- musste deshalb jede dieser Stellen anfassen und kollidierte
## mit jedem parallel laufenden Feature-Branch.
##
## Hier laeuft das zusammen: Schriftgroesse, Mindesthoehe, Symbol und der
## Rueckfall auf einen Tooltip. Welches Symbol ein Knopf bekommt, steht in
## `IconSet.BUTTON_ICONS` -- also in Daten, nicht am Bauort.
##
## Die Darstellungsart gilt global und laesst sich in einem Zug umstellen:
##   TEXT_ONLY      nur Beschriftung (Voreinstellung)
##   TEXT_AND_ICON  Symbol neben der Beschriftung
##   ICON_ONLY      nur Symbol; die Beschriftung wandert in den Tooltip
class_name UiKit
extends RefCounted

enum IconMode {
	TEXT_ONLY,
	TEXT_AND_ICON,
	ICON_ONLY,
}

## Schluessel in den Einstellungen; siehe SaveManager.
const SETTING_KEY := "button_icons"

## Der Autoload wird ueber den Knoten geholt, weil UiKit auch ausserhalb des
## laufenden Spiels benutzt wird (Lint, Tests). Der Typ kommt vom Skript.
const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")

const DEFAULT_FONT_SIZE := 12
const DEFAULT_MIN_HEIGHT := 28

## Einstellungswert -> Darstellungsart.
const MODE_NAMES := {
	"text": IconMode.TEXT_ONLY,
	"both": IconMode.TEXT_AND_ICON,
	"icon": IconMode.ICON_ONLY,
}

static var _icon_mode: IconMode = IconMode.TEXT_ONLY
static var _mode_loaded: bool = false


## Aktuelle Darstellungsart. Wird beim ersten Zugriff aus den Einstellungen
## gelesen; ohne Eintrag bleiben Symbole aus.
static func icon_mode() -> IconMode:
	if not _mode_loaded:
		_mode_loaded = true
		_icon_mode = _mode_from_settings()
	return _icon_mode


## Setzt die Darstellungsart zur Laufzeit -- fuer Optionen und Tests.
static func set_icon_mode(mode: IconMode) -> void:
	_icon_mode = mode
	_mode_loaded = true


static func _mode_from_settings() -> IconMode:
	# Statisch aufgerufen, auch ausserhalb des laufenden Spiels (Lint, Tests).
	# Ohne Autoload bleibt es bei der Voreinstellung.
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null or not loop.root.has_node("SaveManager"):
		return IconMode.TEXT_ONLY
	var manager := loop.root.get_node("SaveManager") as SaveManagerScript
	if manager == null:
		return IconMode.TEXT_ONLY
	var settings := manager.load_settings()
	var mode_name: String = String(settings.get(SETTING_KEY, "text"))
	if not MODE_NAMES.has(mode_name):
		return IconMode.TEXT_ONLY
	var mode: IconMode = MODE_NAMES[mode_name]
	return mode


## Baut einen Knopf mit einheitlichem Aussehen.
##
## `node_name` ist zugleich der Schluessel fuer das Symbol und der Name, ueber
## den die Testsuiten den Knopf finden -- er ist deshalb Pflicht.
## Wird `parent` angegeben, haengt der Knopf dort direkt ein. `unique_owner`
## macht ihn zusaetzlich ueber `%Name` erreichbar.
static func button(text: String, node_name: String, parent: Node = null,
		font_size: int = DEFAULT_FONT_SIZE,
		min_height: int = DEFAULT_MIN_HEIGHT,
		unique_owner: Node = null) -> Button:
	var control := Button.new()
	control.name = node_name
	control.text = text
	if font_size > 0:
		# 0 heisst: Schriftgroesse aus dem Theme uebernehmen.
		control.add_theme_font_size_override("font_size", font_size)
	control.custom_minimum_size.y = min_height
	apply_icon(control, node_name)
	if parent != null:
		parent.add_child(control)
	if unique_owner != null:
		# Muss nach dem Einhaengen passieren, sonst lehnt Godot den Besitzer ab.
		control.owner = unique_owner
		control.unique_name_in_owner = true
	return control


## Uebernimmt einen in der Szene angelegten Knopf in dieselbe Darstellung.
## Fuer `.tscn`-Knoepfe, die nicht im Code entstehen.
static func decorate(control: Button, icon_name: String = "") -> Button:
	apply_icon(control, control.name, icon_name)
	return control


## Haengt das passende Symbol an und beruecksichtigt die Darstellungsart.
static func apply_icon(control: Button, node_name: String,
		icon_name: String = "") -> void:
	var mode := icon_mode()
	if mode == IconMode.TEXT_ONLY:
		return
	var wanted := icon_name if not icon_name.is_empty() else IconSet.for_button(node_name)
	var texture := IconSet.texture(wanted)
	if texture == null:
		# Ohne Atlas oder ohne Zuordnung bleibt der Knopf bei seiner Beschriftung.
		return
	control.icon = texture
	control.expand_icon = false
	if mode == IconMode.ICON_ONLY:
		if control.tooltip_text.is_empty() and not control.text.is_empty():
			# Ohne Beschriftung muss der Tooltip die Bedeutung tragen.
			control.tooltip_text = control.text
		control.text = ""
		# Viele Knoepfe richten ihren Text links aus; ohne Text gehoert das
		# Symbol in die Mitte, sonst klebt es am Rand einer breiten Flaeche.
		control.alignment = HORIZONTAL_ALIGNMENT_CENTER
		control.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control.custom_minimum_size.x = maxf(control.custom_minimum_size.y,
			float(DEFAULT_MIN_HEIGHT))


## Aendert die Beschriftung, ohne die Darstellungsart zu durchbrechen.
##
## Knoepfe, deren Text sich zur Laufzeit aendert ("Einrichten"/"Abbrechen"),
## muessen hierueber gehen -- sonst taucht bei ICON_ONLY wieder Text auf.
static func set_button_text(control: Button, text: String) -> void:
	if icon_mode() == IconMode.ICON_ONLY and control.icon != null:
		control.tooltip_text = text
		control.text = ""
		return
	control.text = text


## Beschriftung eines Knopfes, unabhaengig von der Darstellungsart.
static func button_text(control: Button) -> String:
	if not control.text.is_empty():
		return control.text
	return control.tooltip_text


## Baut ein Textfeld, das keine Maus- oder Touch-Eingaben abfaengt.
static func label(text: String, font_size: int = DEFAULT_FONT_SIZE,
		parent: Node = null) -> Label:
	var control := Label.new()
	control.text = text
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	if parent != null:
		parent.add_child(control)
	return control


## Kopie des Panel-Stils mit engeren Innenabstaenden.
static func compact_panel_style(source: Control, left: int = 6, right: int = 6,
		top: int = 4, bottom: int = 4) -> StyleBox:
	var style := source.get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	style.content_margin_left = left
	style.content_margin_right = right
	style.content_margin_top = top
	style.content_margin_bottom = bottom
	return style
