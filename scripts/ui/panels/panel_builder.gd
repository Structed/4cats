## Werkzeug, das ein Fenster beim Bauen in die Hand bekommt.
##
## Buendelt die drei Dinge, die jedes Fenster braucht: wohin der Inhalt kommt,
## wem die Knoepfe gehoeren (die Testsuiten finden sie ueber `%Name`) und wie
## eine Aktion an die Szene gemeldet wird.
##
## Dadurch kennt ein Fenster das HUD nicht -- es kann also in einer eigenen
## Datei liegen, ohne dass eine Aenderung daran das HUD anfasst.
class_name PanelBuilder
extends RefCounted

## Behaelter fuer den Inhalt des Fensters.
var content: VBoxContainer

## Besitzer der erzeugten Knoepfe; macht sie ueber `%Name` auffindbar.
var host: Control

var _act: Callable


func _init(content_box: VBoxContainer, panel_host: Control, act: Callable) -> void:
	content = content_box
	host = panel_host
	_act = act


func label(text: String, font_size: int = 12) -> Label:
	var control := UiKit.label(text, font_size)
	content.add_child(control)
	return control


## Textfeld, das lange Texte umbricht statt ueber den Rand zu laufen.
func wrapped(text: String, font_size: int = 12) -> Label:
	var control := label(text, font_size)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control


func button(text: String, node_name: String) -> Button:
	return UiKit.button(text, node_name, content, 12, 28, host)


## Bettet ein fertiges Bedienelement ein und macht es ueber `%Name` auffindbar.
func adopt(node: Control) -> void:
	content.add_child(node)
	node.owner = host
	node.unique_name_in_owner = true


## Meldet eine Aktion an die Szene.
##
## Welche Aktion was ausloest, steht an genau einer Stelle:
## `HomeScene._on_hud_action`.
func act(action: StringName, payload: Variant = null) -> void:
	_act.call(action, payload)
