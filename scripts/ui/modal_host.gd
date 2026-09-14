## Gemeinsame Steuerung fuer Fenster, die alles andere ueberdecken.
##
## Rettungs-HUD und Haus-HUD hatten dafuer zwei getrennte Zustandsmaschinen mit
## denselben Aufgaben: Sichtbarkeit von Abdunklung und Fenster, den gemerkten
## Fokus, das Umlaufen des Fokusrings und den Schutz davor, dass die Tastatur
## hinter das Fenster wandert. Nur eine der beiden konnte den Fokus umlaufen
## lassen -- im Haus liefen Tastatur und Gamepad aus dem Fenster heraus.
##
## Hier liegt beides zusammen. Ein neues Fenster anzumelden ist eine Zeile:
##
##     _modals = ModalHost.new(self)
##     _modals.register("pause", _pause_panel, _pause_dim)
##
## Was der Besitzer behaelt, ist das, was wirklich nur ihn angeht: das Anhalten
## der Spielwelt, die Spielfigur und der Inhalt des Fensters.
class_name ModalHost
extends RefCounted

## Ein Fenster wurde geoeffnet oder geschlossen; `kind` ist der angemeldete Name.
signal opened(kind: String)
signal closed(kind: String)

## Name des offenen Fensters, sonst leer.
var kind: String = ""

var _owner: Control
var _panels: Dictionary = {}
var _dims: Dictionary = {}
var _saved_focus: Control


func _init(owner: Control) -> void:
	_owner = owner


## Meldet ein Fenster samt optionaler Abdunklung an.
##
## Das Fenster wird dabei gleich in den geschlossenen Zustand gebracht, damit
## niemand daneben noch von Hand ausblenden muss.
func register(modal_kind: String, panel: Control, dim: Control = null) -> void:
	_panels[modal_kind] = panel
	if dim != null:
		_dims[modal_kind] = dim
	_apply_visibility()


func is_open() -> bool:
	return not kind.is_empty()


## Das Fenster des offenen Modals, oder null.
func panel() -> Control:
	if not _panels.has(kind):
		return null
	var control: Control = _panels[kind]
	return control


## Oeffnet ein angemeldetes Fenster und merkt sich den bisherigen Fokus.
## Liefert false, wenn der Name nicht angemeldet ist.
func open(modal_kind: String) -> bool:
	if not _panels.has(modal_kind):
		push_error("Unbekanntes Modal: %s" % modal_kind)
		return false
	if not is_open():
		# Nur beim ersten Oeffnen merken, sonst ueberschreibt ein Wechsel
		# zwischen zwei Fenstern den Fokus aus der Spielwelt.
		_saved_focus = _focus_owner()
	kind = modal_kind
	_apply_visibility()
	opened.emit(modal_kind)
	return true


## Schliesst das offene Fenster. Der gemerkte Fokus wird bewusst nicht von
## selbst wiederhergestellt -- beim Szenenwechsel waere das falsch.
func close() -> void:
	if not is_open():
		return
	var previous := kind
	kind = ""
	_apply_visibility()
	var viewport := _viewport()
	if viewport != null:
		viewport.gui_release_focus()
	closed.emit(previous)


## Gibt den Fokus an das Bedienelement zurueck, das vor dem Fenster aktiv war.
func restore_focus() -> void:
	if is_instance_valid(_saved_focus) and _saved_focus.is_visible_in_tree() \
			and _saved_focus.focus_mode != Control.FOCUS_NONE:
		_saved_focus.grab_focus()
	_saved_focus = null


## Verwirft den gemerkten Fokus, ohne ihn zu setzen.
func forget_focus() -> void:
	_saved_focus = null


## Alle bedienbaren Knoepfe des offenen Fensters in Anzeigereihenfolge.
##
## Bewusst aus dem Szenenbaum gelesen statt je Fenster aufgezaehlt: ein Knopf
## mehr im Fenster braucht dadurch keine zweite Aenderung an anderer Stelle.
func buttons() -> Array[Button]:
	var found: Array[Button] = []
	var active := panel()
	if active != null:
		_collect(active, found)
	return found


## Legt den Fokusring so, dass er am Ende wieder von vorn beginnt.
func link_focus() -> void:
	var ring: Array[Button] = buttons()
	if ring.is_empty():
		return
	for index in ring.size():
		var button: Button = ring[index]
		var next: Button = ring[(index + 1) % ring.size()]
		var previous: Button = ring[posmod(index - 1, ring.size())]
		button.focus_next = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
	var focused := _focus_owner()
	if focused == null or (focused is Button and (focused as Button).disabled):
		focus_first()


func focus_first() -> void:
	if not is_open() or not _owner.is_inside_tree():
		return
	var ring: Array[Button] = buttons()
	if not ring.is_empty():
		ring[0].grab_focus()


## Holt den Fokus zurueck, wenn er hinter das Fenster gewandert ist.
func guard_focus(control: Control) -> void:
	if not is_open() or control == null:
		return
	var active := panel()
	if active != null and not active.is_ancestor_of(control):
		focus_first.call_deferred()


## Ein Fenster ist genau dann sichtbar, wenn es zum offenen Modal gehoert.
##
## Bewusst ueber einen Abgleich statt ueber einen Vergleich je Eintrag: im Haus
## teilen sich alle Modale dasselbe Fenster und tauschen nur den Inhalt. Ein
## Vergleich je Eintrag wuerde es beim naechsten Schleifendurchlauf wieder
## ausblenden.
func _apply_visibility() -> void:
	var shown: Array[Control] = []
	if is_open():
		shown.append(_panels[kind])
		if _dims.has(kind):
			shown.append(_dims[kind])
	for modal_kind: String in _panels:
		var control: Control = _panels[modal_kind]
		control.visible = control in shown
	for modal_kind: String in _dims:
		var control: Control = _dims[modal_kind]
		control.visible = control in shown


func _viewport() -> Viewport:
	return _owner.get_viewport() if _owner.is_inside_tree() else null


func _focus_owner() -> Control:
	var viewport := _viewport()
	return viewport.gui_get_focus_owner() if viewport != null else null


static func _collect(node: Node, into: Array[Button]) -> void:
	for child in node.get_children():
		var button := child as Button
		if button != null and not button.disabled and button.is_visible_in_tree() \
				and button.focus_mode != Control.FOCUS_NONE:
			into.append(button)
		_collect(child, into)
