## Waschplatz und Behandlungsstation: hierher wird eine Katze getragen.
class_name CareStationInteraction
extends ItemInteraction

const TITLES := {
	"wash": "Katze waschen",
	"vet": "Katze behandeln",
}


func hint(context: InteractionContext) -> String:
	var title: String = TITLES[context.item.kind]
	var detail := "Sanfte Pflege · kostenlos." if context.holding \
		else "Trage zuerst eine Katze hierher."
	return "%s\n%s" % [title, detail]


func perform(context: InteractionContext) -> void:
	if not context.cargo_kind().is_empty():
		context.toast(SupplyCatalog.cargo_return_hint(context.cargo_kind()))
	elif context.simulation.held_cat_id.is_empty():
		context.toast("Trage zuerst eine Katze zur Pflege hierher.")
	elif not context.simulation.begin_care(context.item):
		context.toast("Die Station ist gerade nicht frei.")
