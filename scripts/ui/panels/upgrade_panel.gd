## Ausbauen: dauerhafte Verbesserungen kaufen.
class_name UpgradePanel
extends HomePanel


func title() -> String:
	return "Ausbauen · %d Münzen" % GameState.coins


func build(ui: PanelBuilder) -> void:
	for id: String in GameState.UPGRADES:
		var info: Dictionary = GameState.UPGRADES[id]
		var cost := GameState.upgrade_cost(id)
		ui.label("%s · Stufe %d/%d" % [String(info["name"]),
			GameState.upgrade_level(id), GameState.upgrade_max_level(id)], 14)
		ui.wrapped(String(info["description"]), 11)
		var buy := ui.button("Voll ausgebaut" if cost < 0 else "Ausbauen – %d Münzen" % cost,
			"Upgrade_" + id)
		buy.disabled = not GameState.can_afford_upgrade(id)
		buy.pressed.connect(func() -> void: ui.act(&"upgrade", id))
