## Einrichten: vorhandene Gegenstaende versetzen, neue kaufen.
class_name FurnishPanel
extends HomePanel


func title() -> String:
	return "Einrichten · %d Münzen" % GameState.coins


func build(ui: PanelBuilder) -> void:
	var fixture_text := HomeCatalog.fixture_hint()
	if not fixture_text.is_empty():
		ui.wrapped(fixture_text, 11)
	ui.label("Vorhandene Einrichtung", 13)
	for item in GameState.home.items:
		var caption := "%s · %s" % [HomeCatalog.title(item.kind),
			"versetzen" if item.placed else "aufstellen"]
		var select := ui.button(caption, "Select_" + item.id)
		# Der Knotenname traegt die Gegenstands-Id, nicht die Art -- das
		# Symbol muss deshalb ausdruecklich mitgegeben werden.
		UiKit.apply_icon(select, select.name, item.kind)
		select.disabled = GameState.home_simulation.item_in_use(item.id)
		select.pressed.connect(func() -> void: ui.act(&"select_item", item.id))
	ui.label("Zusätzliche Einrichtung", 13)
	for kind in HomeCatalog.KINDS:
		var price := HomeCatalog.price(kind)
		var caption := "%s – %s" % [HomeCatalog.title(kind),
			"kostenlos" if price == 0 else "%d Münzen" % price]
		var buy := ui.button(caption, "Buy_" + kind)
		buy.disabled = GameState.coins < price
		buy.pressed.connect(func() -> void: ui.act(&"buy_item", kind))
