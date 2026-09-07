## Touch-Overlay fuer die Rettungs-Phase.
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

var _forced: bool = false


func _ready() -> void:
	layer = 5
	_forced = bool(SaveManager.load_settings().get(SETTING_KEY, false))
	_apply_visibility()

	_action_button.button_down.connect(_on_action_down)
	_action_button.button_up.connect(_on_action_up)


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
	var show_controls := DisplayServer.is_touchscreen_available() or _forced
	_joystick.visible = show_controls
	_action_button.visible = show_controls


func _on_action_down() -> void:
	if InputMap.has_action("interact"):
		Input.action_press("interact")
	action_pressed.emit()


func _on_action_up() -> void:
	if InputMap.has_action("interact") and Input.is_action_pressed("interact"):
		Input.action_release("interact")


func _exit_tree() -> void:
	# Keine haengende Aktion zuruecklassen.
	if InputMap.has_action("interact") and Input.is_action_pressed("interact"):
		Input.action_release("interact")
