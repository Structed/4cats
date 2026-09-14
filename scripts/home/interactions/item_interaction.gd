## Basis fuer alles, was im Haus mit E bedient werden kann.
##
## Ein neuer bedienbarer Gegenstand ist eine neue Datei neben dieser und eine
## Zeile in `InteractionRegistry.HANDLERS`. Vorher waren dafuer fuenf
## Aenderungen an home_scene.gd noetig: die Liste der bedienbaren Arten, der
## Hinweistext, der Zweig in `interact()` und der in `_interact_item()`.
##
## Interaktionen sind zustandslos; je Art gibt es genau eine Instanz.
class_name ItemInteraction
extends RefCounted


## Text ueber dem Kopf des Spielers: erste Zeile Titel, danach Erklaerung.
func hint(_context: InteractionContext) -> String:
	return ""


## Was beim Druck auf E passiert.
func perform(_context: InteractionContext) -> void:
	pass
