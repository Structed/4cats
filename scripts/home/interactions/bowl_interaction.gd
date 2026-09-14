## Futter- und Wassernapf: aus dem Getragenen nachfuellen.
class_name BowlInteraction
extends ItemInteraction

const SOURCE_HINTS := {
	"food": "Futter zuerst am Schrank holen.",
	"water": "Wasser zuerst am Hahn holen.",
}
const TITLES := {
	"food": "Futter nachfüllen",
	"water": "Wasser nachfüllen",
}


func hint(context: InteractionContext) -> String:
	var item := context.item
	var capacity := HomeCatalog.capacity(item.kind)
	var detail: String = SOURCE_HINTS[item.kind]
	if context.holding:
		detail = "Setze zuerst die Katze ab."
	elif item.stock == capacity:
		detail = "Dieser Napf ist schon voll."
	elif context.cargo_kind() == "package":
		detail = "Paket zuerst im Schrank einräumen."
	elif context.cargo_kind() == item.kind:
		detail = "%d Portionen auf dem Arm." % GameState.supplies.cargo_amount
	var title: String = TITLES[item.kind]
	return "%s\nNapf: %d/%d · %s" % [title, item.stock, capacity, detail]


func perform(context: InteractionContext) -> void:
	var item := context.item
	var before := item.stock
	var error := GameState.refill_bowl(item.id)
	context.supply_result(error, "%d Portionen eingefüllt. %s." % [
		item.stock - before, GameState.supplies.cargo_text()])
