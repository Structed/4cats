## Hauptmenue mit Optionen.
extends Control

const TOUCH_SETTING := "force_touch_controls"

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton

@onready var _options_panel: PanelContainer = %OptionsPanel
@onready var _options_dim: ColorRect = %OptionsDim
@onready var _master_slider: HSlider = %MasterSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _touch_check: CheckButton = %TouchCheck
@onready var _options_close: Button = %OptionsCloseButton

@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _confirm_dim: ColorRect = %ConfirmDim
@onready var _confirm_yes: Button = %ConfirmYesButton
@onready var _confirm_no: Button = %ConfirmNoButton


func _ready() -> void:
	_set_options_visible(false)
	_set_confirm_visible(false)
	_continue_button.visible = SaveManager.has_save()
	# Auf Handys gibt es keinen sinnvollen „Beenden"-Knopf.
	_quit_button.visible = OS.get_name() not in ["Android", "iOS", "Web"]

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_options_close.pressed.connect(_on_options_close_pressed)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)

	_load_settings()
	_master_slider.value_changed.connect(_on_master_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_touch_check.toggled.connect(_on_touch_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _confirm_panel.visible:
		_on_confirm_no()
		get_viewport().set_input_as_handled()
	elif _options_panel.visible:
		_on_options_close_pressed()
		get_viewport().set_input_as_handled()


## Blendet Abdunklung und Fenster gemeinsam ein oder aus.
func _set_options_visible(shown: bool) -> void:
	_options_panel.visible = shown
	_options_dim.visible = shown


func _set_confirm_visible(shown: bool) -> void:
	_confirm_panel.visible = shown
	_confirm_dim.visible = shown


func _load_settings() -> void:
	var settings := SaveManager.load_settings()
	_master_slider.value = float(settings.get("volume_master", 1.0))
	_sfx_slider.value = float(settings.get("volume_sfx", 1.0))
	_music_slider.value = float(settings.get("volume_music", 0.7))
	_touch_check.button_pressed = bool(settings.get(TOUCH_SETTING, false))


func _store(key: String, value: Variant) -> void:
	var settings := SaveManager.load_settings()
	settings[key] = value
	SaveManager.save_settings(settings)


# --- Knoepfe -----------------------------------------------------------------

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	SaveManager.load_game()
	SceneRouter.goto_home()


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if SaveManager.has_save():
		_set_confirm_visible(true)
		return
	_start_new_game()


func _start_new_game() -> void:
	GameState.reset()
	SaveManager.save_game()
	SceneRouter.goto_home()


func _on_confirm_yes() -> void:
	AudioManager.play_sfx("ui_click")
	_set_confirm_visible(false)
	_start_new_game()


func _on_confirm_no() -> void:
	AudioManager.play_sfx("ui_back")
	_set_confirm_visible(false)


func _on_options_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	_set_options_visible(true)


func _on_options_close_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	_set_options_visible(false)


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Optionen ----------------------------------------------------------------

func _on_master_changed(value: float) -> void:
	AudioManager.set_bus_volume("Master", value)
	_store("volume_master", value)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_bus_volume(AudioManager.SFX_BUS, value)
	_store("volume_sfx", value)
	AudioManager.play_sfx("ui_click")


func _on_music_changed(value: float) -> void:
	AudioManager.set_bus_volume(AudioManager.MUSIC_BUS, value)
	_store("volume_music", value)


func _on_touch_toggled(pressed: bool) -> void:
	_store(TOUCH_SETTING, pressed)
