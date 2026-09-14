## Pause: Steuerung nachschlagen, weiterspielen oder ins Hauptmenue.
class_name PausePanel
extends HomePanel


func title() -> String:
	return "Pause · " + DifficultyRules.title(GameState.difficulty_id)


func build(ui: PanelBuilder) -> void:
	ui.wrapped("Gehen: WASD / Pfeiltasten\nInteraktion: E / Leertaste\nEinrichten: B · Drehen: R · Einlagern: X\nAbbrechen / Pause: Esc\n\n%s\n\nFutter am Schrank, Wasser am Hahn holen.\nPakete vor dem Nachfüllen im Schrank einräumen.\nWasser, Waschen, Behandlung und Katzenklo-Reinigung bleiben kostenlos." % DifficultyRules.description(
		GameState.difficulty_id), 12)
	ui.button("Weiterspielen", "ResumeButton").pressed.connect(
		func() -> void: ui.act(&"close"))
	ui.button("Hauptmenü", "MenuButton").pressed.connect(
		func() -> void: ui.act(&"menu"))
