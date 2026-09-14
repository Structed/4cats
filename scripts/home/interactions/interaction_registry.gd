## Verzeichnis aller bedienbaren Gegenstaende im Haus.
##
## Die einzige Stelle, an der eine neue Gegenstandsart eingetragen wird.
## Die Reihenfolge spielt keine Rolle.
class_name InteractionRegistry
extends RefCounted

const HANDLERS := {
	"food": preload("res://scripts/home/interactions/bowl_interaction.gd"),
	"water": preload("res://scripts/home/interactions/bowl_interaction.gd"),
	"pantry": preload("res://scripts/home/interactions/pantry_interaction.gd"),
	"faucet": preload("res://scripts/home/interactions/faucet_interaction.gd"),
	"litter": preload("res://scripts/home/interactions/litter_interaction.gd"),
	"wash": preload("res://scripts/home/interactions/care_station_interaction.gd"),
	"vet": preload("res://scripts/home/interactions/care_station_interaction.gd"),
}

static var _cache: Dictionary = {}


static func has(kind: String) -> bool:
	return HANDLERS.has(kind)


## Alle bedienbaren Arten.
static func kinds() -> PackedStringArray:
	var result: PackedStringArray = []
	for kind: String in HANDLERS:
		result.append(kind)
	return result


## Die Interaktion zu einer Art, oder null. Je Art gibt es eine Instanz.
static func handler(kind: String) -> ItemInteraction:
	if not HANDLERS.has(kind):
		return null
	if not _cache.has(kind):
		var script: GDScript = HANDLERS[kind]
		_cache[kind] = script.new()
	var cached: ItemInteraction = _cache[kind]
	return cached
