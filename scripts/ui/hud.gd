## Anzeige waehrend der Rettungs-Phase.
##
## Zeigt getragene Katzen, Muenzen und kurze Hinweise -- und enthaelt das
## Pausenmenue.
extends Control

const HINT_SECONDS := 3.5

@onready var _carry_label: Label = %CarryLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _hint_label: Label = %HintLabel
@onready var _pause_panel: PanelContainer = %PausePanel
@onready var _pause_dim: ColorRect = %PauseDim
@onready var _home_button: Button = %HomeButton
@onready var _resume_button: Button = %ResumeButton
@onready var _to_home_button: Button = %ToHomeButton
@onready var _to_menu_button: Button = %ToMenuButton

var _hint_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_pause_visible(false)
	_hint_label.text = ""

	GameState.carried_changed.connect(_on_carried_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.cat_adopted.connect(_on_cat_adopted)
	SaveManager.save_failed.connect(set_hint)

	_home_button.pressed.connect(_on_home_pressed)
	_resume_button.pressed.connect(func() -> void: toggle_pause())
	_to_home_button.pressed.connect(_on_home_pressed)
	_to_menu_button.pressed.connect(_on_menu_pressed)

	_on_carried_changed(GameState.carried_cats.size(), GameState.carry_capacity())
	_on_coins_changed(GameState.coins)


func _process(delta: float) -> void:
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_label.text = ""


func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_timer = HINT_SECONDS


func _on_cat_adopted(cat: CatData, reward: int) -> void:
	set_hint("%s hat ein Zuhause gefunden! +%d Münzen" % [cat.cat_name, reward])


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_set_pause_visible(paused)
	AudioManager.play_sfx("ui_click")


## Blendet Abdunklung und Pausenfenster gemeinsam ein oder aus.
func _set_pause_visible(shown: bool) -> void:
	_pause_panel.visible = shown
	_pause_dim.visible = shown


func _on_carried_changed(carried: int, capacity: int) -> void:
	_carry_label.text = "Katzen dabei: %d / %d" % [carried, capacity]


func _on_coins_changed(amount: int) -> void:
	_coin_label.text = "Münzen: %d" % amount


func _on_home_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().paused = false
	SceneRouter.goto_home()


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	get_tree().paused = false
	SceneRouter.goto_main_menu()
