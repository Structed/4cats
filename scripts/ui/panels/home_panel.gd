## Basis fuer ein Fenster im Haus.
##
## Ein neues Menue ist eine neue Datei neben dieser und eine Zeile in
## `HomeHUD.PANELS` -- nicht ein weiterer Zweig in einer langen
## Fallunterscheidung und nicht ein weiteres Signal quer durch zwei Dateien.
##
## Fenster sind bewusst RefCounted und keine Knoten: sie werden bei jedem
## Oeffnen neu gebaut, weil ihr Inhalt vom Spielstand abhaengt.
class_name HomePanel
extends RefCounted


## Ueberschrift ueber dem Inhalt.
func title() -> String:
	return ""


## Baut den Inhalt des Fensters.
func build(_ui: PanelBuilder) -> void:
	pass
