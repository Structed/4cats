## Wasserhahn: Wasser holen oder Reste zurueckgeben. Immer kostenlos.
class_name FaucetInteraction
extends SupplyStationInteraction


func hint(context: InteractionContext) -> String:
	var title := "Wasser zurückgeben" if context.cargo_kind() == "water" else "Wasser holen"
	var detail := "Kostenlos · Zum Wassernapf tragen."
	if context.holding:
		detail = "Setze zuerst die Katze ab."
	elif context.cargo_kind() in ["food", "package"]:
		detail = "Futter zuerst im Schrank einräumen."
	return "%s\n%s" % [title, detail]


func handover_message(_previous: String) -> String:
	return "Wasser zurückgegeben. Die Hände sind frei."
