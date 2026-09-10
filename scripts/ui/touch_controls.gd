## Gemeinsames Touch-Overlay fuer Rettung und Zuhause.
##
## Links ein virtueller Joystick, rechts ein Aktionsknopf. Beides speist die
## normale InputMap, deshalb braucht der Spielcode keine Sonderbehandlung.
##
## Sichtbar ist die Bedienung nur auf Geraeten mit Touchscreen -- in den
## Optionen laesst sie sich aber erzwingen, um am PC zu testen.
extends CanvasLayer

## Wird ausgeloest, wenn der Aktionsknopf gedrueckt wird.
signal action_pressed()

const SETTING_KEY := "force_touch_controls"

@onready var _joystick: TouchJoystick = $Root/Joystick
@onready var _action_button: Button = $Root/ActionButton
@onready var _sprint_button: Button = $Root/SprintButton

var _forced: bool = false
var _enabled: bool = true
var _building: bool = false
var _rotate_button: Button
var _store_button: Button
var _movement_hint: Label


func _ready() -> void:
	layer = 5
	_forced = bool(SaveManager.load_settings().get(SETTING_KEY, false))
	_apply_visibility()

	_action_button.button_down.connect(_on_action_down)
	_action_button.button_up.connect(_on_action_up)
	# Umschalter statt Halten: einen zweiten Finger dauerhaft aufzulegen ist
	# beim Spielen mit dem Daumen unbequem.
	_sprint_button.toggled.connect(_on_sprint_toggled)


## Blendet die Touch-Bedienung dauerhaft ein oder aus.
func set_forced(forced: bool) -> void:
	_forced = forced
	var settings := SaveManager.load_settings()
	settings[SETTING_KEY] = forced
	SaveManager.save_settings(settings)
	_apply_visibility()


func is_forced() -> bool:
	return _forced


## Soll die Touch-Bedienung angezeigt werden? Auch ohne Instanz nutzbar.
static func should_show() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	return bool(SaveManager.load_settings().get(SETTING_KEY, false))


func _apply_visibility() -> void:
	var show_controls := is_touch_visible()
	_joystick.visible = show_controls
	_joystick.show_idle_hint = _building
	_action_button.visible = show_controls
	_sprint_button.visible = show_controls and not _building
	if _rotate_button != null:
		_rotate_button.visible = show_controls and _building
		_store_button.visible = show_controls and _building
		_movement_hint.visible = show_controls and _building


func is_touch_visible() -> bool:
	return _enabled and (DisplayServer.is_touchscreen_available() or _forced)


func configure_home() -> void:
	_action_button.add_theme_font_size_override("font_size", 12)
	_rotate_button = _home_button("Drehen", "RotateButton", "home_rotate", -166.0, -114.0)
	_store_button = _home_button("Einlagern", "StoreButton", "home_store", -224.0, -172.0)
	_movement_hint = Label.new()
	_movement_hint.name = "MovementHint"
	_movement_hint.text = "Vorschau bewegen"
	_movement_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_movement_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_movement_hint.add_theme_font_size_override("font_size", 12)
	$Root.add_child(_movement_hint)
	_movement_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_movement_hint.offset_left = 6
	_movement_hint.offset_right = 186
	_movement_hint.offset_top = -186
	_movement_hint.offset_bottom = -164
	_apply_visibility()


func _home_button(caption: String, node_name: String, action: String,
		top: float, bottom: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	$Root.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -104
	button.offset_right = -14
	button.offset_top = top
	button.offset_bottom = bottom
	button.button_down.connect(func() -> void:
		if _enabled:
			Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	return button


func set_action_label(text: String) -> void:
	_action_button.text = text.replace(" ", "\n")


func set_building(building: bool) -> void:
	_building = building
	_sprint_button.set_pressed_no_signal(false)
	Input.action_release("sprint")
	_apply_visibility()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_sprint_button.set_pressed_no_signal(false)
		for action in ["interact", "sprint", "home_rotate", "home_store"]:
			if InputMap.has_action(action):
				Input.action_release(action)
	_apply_visibility()


func _on_action_down() -> void:
	if not _enabled:
		return
	if InputMap.has_action("interact"):
		Input.action_press("interact")
	action_pressed.emit()


func _on_action_up() -> void:
	if InputMap.has_action("interact") and Input.is_action_pressed("interact"):
		Input.action_release("interact")


func _on_sprint_toggled(pressed: bool) -> void:
	if not InputMap.has_action("sprint"):
		return
	if pressed:
		Input.action_press("sprint")
	elif Input.is_action_pressed("sprint"):
		Input.action_release("sprint")


func _notification(what: int) -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_enabled(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		set_enabled(not get_tree().paused)


func _exit_tree() -> void:
	# Keine haengenden Aktionen zuruecklassen.
	for action in ["interact", "sprint", "home_rotate", "home_store"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
