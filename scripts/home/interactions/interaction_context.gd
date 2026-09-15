## Umgebung, die eine Interaktion beim Aufruf in die Hand bekommt.
##
## Wird einmal gebaut und wiederverwendet: `hint()` laeuft in jedem Bild fuer
## den anvisierten Gegenstand, ein neues Objekt pro Bild waere Verschwendung.
class_name InteractionContext
extends RefCounted

## Der anvisierte Gegenstand; vor jedem Aufruf gesetzt.
var item: HomeItemData

## Ob der Spieler gerade eine Katze traegt.
var holding: bool = false

var simulation: HomeSimulation

var _toast: Callable
var _supply: Callable
var _save: Callable


func _init(sim: HomeSimulation, toast: Callable, supply: Callable, save: Callable) -> void:
	simulation = sim
	_toast = toast
	_supply = supply
	_save = save


## Kurze Meldung an den Spieler.
func toast(text: String) -> void:
	_toast.call(text)


## Ergebnis einer Vorratsaktion: Fehlermeldung oder Erfolg mit Ton und Speichern.
func supply_result(error: String, message: String, sound: String = "care") -> void:
	_supply.call(error, message, sound)


func save() -> void:
	_save.call()


## Was der Spieler gerade auf dem Arm hat ("" wenn die Haende frei sind).
func cargo_kind() -> String:
	return GameState.supplies.cargo_kind
