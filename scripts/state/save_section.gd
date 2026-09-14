class_name SaveSection
extends RefCounted
## Ein Abschnitt des Spielstands.
##
## Dauerhafte Daten bekommen eine eigene Datei statt neuer Zeilen in einem
## gemeinsamen to_dict()/from_dict(). Ein neues Feature legt einen Abschnitt an
## und traegt ihn einmal im Spielzustand ein -- neue Dateien lassen sich ohne
## Konflikt zusammenfuehren, gewachsene Sammelfunktionen nicht.
##
## Das Laden laeuft in zwei Stufen: read() prueft den Spielstand und legt die
## Werte beiseite, commit() uebernimmt sie erst, wenn alle Abschnitte
## einverstanden sind. Ein beschaedigter Spielstand bleibt damit folgenlos,
## statt einen halb geladenen Zustand zu hinterlassen.


## Setzt den Abschnitt auf den Anfangszustand eines neuen Spiels.
func reset(_mode: String) -> void:
	pass


## Schreibt die eigenen Felder in den Spielstand.
func write(_data: Dictionary) -> void:
	pass


## Prueft die eigenen Felder. false lehnt den gesamten Spielstand ab.
func read(_data: Dictionary) -> bool:
	return true


## Uebernimmt die in read() geprueften Werte.
func commit() -> void:
	pass
