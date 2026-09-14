## Hauptmenue mit Optionen, Credits und Nutzungsanalyse.
extends Control

const TOUCH_SETTING := "force_touch_controls"
const AnalyticsService := preload("res://scripts/autoload/analytics_manager.gd")

var _analytics_service: AnalyticsService = AnalyticsManager
var _analytics_button: Button
var _analytics_dialog: AnalyticsConsent

@onready var _menu_actions: VBoxContainer = %Center
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _credits_button: Button = %CreditsButton
@onready var _version_label: Label = %VersionLabel

@onready var _credits_panel: PanelContainer = %CreditsPanel
@onready var _credits_dim: ColorRect = %CreditsDim
@onready var _credits_close: Button = %CreditsCloseButton

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
@onready var _difficulty_choice: OptionButton = %DifficultyChoice
@onready var _difficulty_description: Label = %DifficultyDescription
@onready var _confirm_text: Label = $ConfirmPanel/Box/Text
@onready var _menu_error: Label = %MenuError


func _ready() -> void:
	GameState.simulation_active = false
	UiKit.adopt(self)
	var version: String = ProjectSettings.get_setting("application/config/version")
	_version_label.text = "Version %s" % version
	_set_credits_visible(false)
	_set_options_visible(false)
	_set_confirm_visible(false)
	_continue_button.visible = SaveManager.has_save()
	# Auf Handys gibt es keinen sinnvollen „Beenden"-Knopf.
	_quit_button.visible = OS.get_name() not in ["Android", "iOS", "Web"]

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_credits_close.pressed.connect(_on_credits_close_pressed)
	_options_close.pressed.connect(_on_options_close_pressed)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)
	for id in DifficultyRules.IDS:
		_difficulty_choice.add_item(DifficultyRules.title(id))
	_difficulty_choice.item_selected.connect(_on_difficulty_selected)
	_on_difficulty_selected(0)
	SaveManager.save_failed.connect(_show_error)

	_load_settings()
	_master_slider.value_changed.connect(_on_master_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_touch_check.toggled.connect(_on_touch_toggled)
	_build_analytics_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _analytics_dialog.visible:
		_analytics_dialog.dismiss()
		get_viewport().set_input_as_handled()
	elif _confirm_panel.visible:
		_on_confirm_no()
		get_viewport().set_input_as_handled()
	elif _credits_panel.visible:
		_on_credits_close_pressed()
		get_viewport().set_input_as_handled()
	elif _options_panel.visible:
		_on_options_close_pressed()
		get_viewport().set_input_as_handled()


## Blendet Abdunklung und Credits-Fenster gemeinsam ein oder aus.
func _set_credits_visible(shown: bool) -> void:
	_set_modal_visible(_credits_panel, _credits_dim, shown,
		_credits_close if shown else _credits_button)


## Blendet Abdunklung und Fenster gemeinsam ein oder aus.
func _set_options_visible(shown: bool) -> void:
	_set_modal_visible(_options_panel, _options_dim, shown,
		_master_slider if shown else _options_button)


func _set_confirm_visible(shown: bool) -> void:
	_set_modal_visible(_confirm_panel, _confirm_dim, shown,
		_confirm_no if shown else _new_game_button)


## Die Abdunklung allein blockiert keine Tastaturbedienung im Hintergrund.
func _set_modal_visible(panel: PanelContainer, dim: ColorRect, shown: bool,
		focus_target: Control) -> void:
	var was_visible := panel.visible
	panel.visible = shown
	dim.visible = shown
	_update_modal_focus()
	if shown or was_visible:
		focus_target.grab_focus()


func _update_modal_focus() -> void:
	var analytics_visible := is_instance_valid(_analytics_dialog) and _analytics_dialog.visible
	var modal_visible := analytics_visible or _credits_panel.visible \
		or _options_panel.visible or _confirm_panel.visible
	_menu_actions.focus_behavior_recursive = (Control.FOCUS_BEHAVIOR_DISABLED
		if modal_visible else Control.FOCUS_BEHAVIOR_INHERITED)
	for panel: PanelContainer in [_credits_panel, _options_panel, _confirm_panel]:
		panel.focus_behavior_recursive = (Control.FOCUS_BEHAVIOR_DISABLED
			if analytics_visible else Control.FOCUS_BEHAVIOR_INHERITED)


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
	if SaveManager.load_game():
		_analytics_service.game_started("continue")
		SceneRouter.goto_home()
	else:
		_show_error("Der Spielstand konnte nicht geladen werden.")


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	_difficulty_choice.select(0)
	_on_difficulty_selected(0)
	_confirm_text.text = "Ein neues Spiel überschreibt deinen Spielstand." if SaveManager.has_save() \
		else "Wähle den Modus für dein neues Katzenhaus."
	_menu_error.hide()
	_set_confirm_visible(true)


func _start_new_game(mode: String = DifficultyRules.DEFAULT) -> void:
	var previous := GameState.to_dict()
	GameState.reset(mode)
	if SaveManager.save_game():
		_analytics_service.game_started("new")
		SceneRouter.goto_home()
	else:
		GameState.from_dict(previous)


func _on_confirm_yes() -> void:
	AudioManager.play_sfx("ui_click")
	var mode: String = DifficultyRules.IDS[_difficulty_choice.selected]
	_set_confirm_visible(false)
	_start_new_game(mode)


func _on_confirm_no() -> void:
	AudioManager.play_sfx("ui_back")
	_set_confirm_visible(false)


func _on_difficulty_selected(index: int) -> void:
	_difficulty_description.text = DifficultyRules.description(DifficultyRules.IDS[index])


func _show_error(message: String) -> void:
	_menu_error.text = message
	_menu_error.show()


func _on_options_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	_set_options_visible(true)


func _on_options_close_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	_set_options_visible(false)


func _on_credits_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	_set_credits_visible(true)


func _on_credits_close_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	_set_credits_visible(false)


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


func _build_analytics_ui() -> void:
	var box := _options_close.get_parent()
	_analytics_button = UiKit.button("", "AnalyticsButton", box, 12)
	box.move_child(_analytics_button, _options_close.get_index())
	_analytics_dialog = AnalyticsConsent.new()
	_analytics_dialog.name = "AnalyticsDialog"
	add_child(_analytics_dialog)
	_analytics_dialog.visibility_changed.connect(_update_modal_focus)
	_analytics_button.pressed.connect(_show_analytics)
	_analytics_service.changed.connect(_refresh_analytics)
	_refresh_analytics()
	if _analytics_service.needs_consent():
		_show_analytics()


func _refresh_analytics() -> void:
	UiKit.set_button_text(_analytics_button,
		"Nutzungsanalyse: " + ("an" if _analytics_service.has_consent() else "aus"))


func _show_analytics() -> void:
	_analytics_dialog.present(_analytics_service)
