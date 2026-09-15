## Vorratsschrank: Futter holen, zuruecklegen oder ein Paket einraeumen.
class_name PantryInteraction
extends SupplyStationInteraction


func hint(context: InteractionContext) -> String:
	var title := "Futter holen"
	if context.cargo_kind() == "package":
		title = "Paket einräumen"
	elif context.cargo_kind() == "food":
		title = "Futter zurücklegen"
	var detail := "Vorrat: %d Portionen · Für alle Schränke gemeinsam." \
		% GameState.supplies.food_stock
	if context.holding:
		detail = "Setze zuerst die Katze ab."
	elif context.cargo_kind() == "water":
		detail = "Wasser zuerst am Hahn zurückgeben."
	elif GameState.supplies.food_stock == 0 and context.cargo_kind().is_empty():
		detail = "Schrank leer: im Laden holen oder unter Vorräte bestellen."
	return "%s\n%s" % [title, detail]


func handover_message(previous: String) -> String:
	return "%s Vorrat: %d Portionen." % [
		"Paket eingeräumt." if previous == "package" else "Futter zurückgelegt.",
		GameState.supplies.food_stock]
