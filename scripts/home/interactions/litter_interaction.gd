## Katzenklo: Streu wechseln. Kostenlos, aber nur mit freien Haenden.
class_name LitterInteraction
extends ItemInteraction


func hint(context: InteractionContext) -> String:
	var detail := "Die Streu ist sauber." if context.item.dirt == 0 \
		else "Frische Streu wird gebraucht."
	if context.holding:
		detail = "Setze zuerst die Katze ab."
	return "Katzenklo reinigen\n" + detail


func perform(context: InteractionContext) -> void:
	if not context.simulation.held_cat_id.is_empty():
		context.toast("Setze zuerst die Katze ab.")
		return
	if context.simulation.item_in_use(context.item.id):
		context.toast("Bitte warten, bis die Katze fertig ist.")
		return
	context.item.dirt = 0
	AudioManager.play_sfx_varied("care")
	context.toast("Das Katzenklo ist wieder sauber.")
	context.save()
