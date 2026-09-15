## Basis fuer Vorratsstellen: hier wechselt das Getragene den Besitzer.
class_name SupplyStationInteraction
extends ItemInteraction


func perform(context: InteractionContext) -> void:
	var previous := context.cargo_kind()
	var error := GameState.use_supply_station(context.item.id)
	var message := GameState.supplies.cargo_text() + ". " \
		+ SupplyCatalog.cargo_destination(context.cargo_kind())
	if context.cargo_kind().is_empty():
		message = handover_message(previous)
	context.supply_result(error, message)


## Meldung, wenn die Haende nach der Aktion wieder frei sind.
func handover_message(_previous: String) -> String:
	return ""
