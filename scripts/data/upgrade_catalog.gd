class_name UpgradeCatalog
extends RefCounted
## Alle Ausbauten mit Name, Beschreibung und Preis je Stufe.
##
## Ein neuer Ausbau ist ein Eintrag in ENTRIES. Preise und Texte stehen damit
## an einer Stelle statt verteilt im Spielzustand.

## Ausbau-Id -> Name, Beschreibung und Preise. `costs` enthaelt den Preis je Stufe.
const ENTRIES := {
	"carry_capacity": {
		"name": "Tragekorb",
		"description": "Du kannst eine Katze mehr gleichzeitig tragen.",
		"costs": [50, 120, 260],
	},
	"treats": {
		"name": "Leckerlis",
		"description": "Katzen fassen schneller Vertrauen und sind weniger scheu.",
		"costs": [40, 100, 220],
	},
	"comfort": {
		"name": "Komfort",
		"description": "Bedürfnisse sinken zu Hause langsamer.",
		"costs": [60, 140, 300],
	},
	"vet": {
		"name": "Tierarzt",
		"description": "Katzen genesen schneller und werden früher vermittelt.",
		"costs": [70, 160, 340],
	},
}


static func has(id: String) -> bool:
	return ENTRIES.has(id)


static func ids() -> Array:
	return ENTRIES.keys()


static func label(id: String) -> String:
	return String(ENTRIES[id]["name"])


static func description(id: String) -> String:
	return String(ENTRIES[id]["description"])


## Hoechste kaufbare Stufe. 0 fuer unbekannte Ausbauten.
static func max_level(id: String) -> int:
	if not ENTRIES.has(id):
		return 0
	var costs: Array = ENTRIES[id]["costs"]
	return costs.size()


## Preis der naechsten Stufe, oder -1 wenn bereits voll ausgebaut.
static func cost_at(id: String, level: int) -> int:
	if level < 0 or level >= max_level(id):
		return -1
	var costs: Array = ENTRIES[id]["costs"]
	return int(costs[level])

