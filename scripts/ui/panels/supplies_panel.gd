## Futter bestellen: bettet die gemeinsame Vorrats-Ansicht ein.
class_name SuppliesPanel
extends HomePanel


func title() -> String:
	return "Futter bestellen"


func build(ui: PanelBuilder) -> void:
	var supplies := SupplyPanel.new()
	supplies.name = "SupplyPanel"
	supplies.delivery = true
	supplies.message.connect(func(text: String) -> void: ui.act(&"toast", text))
	ui.adopt(supplies)
