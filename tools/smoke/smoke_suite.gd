## Gemeinsame Grundlage aller Oberflaechen-Durchlaeufe.
##
## Haelt die Helfer, die jede Suite braucht: Szenen laden, Knoepfe druecken,
## Eingaben schicken, echte Sekunden warten. Eine neue Suite ist damit eine
## neue Datei, die hiervon erbt -- und keine weiteren hundert Zeilen in einer
## Datei, die alle gleichzeitig bearbeiten.
##
## Suiten sind Knoten, weil die Pruefungen `await get_tree()...` brauchen.
class_name SmokeSuite
extends Node

const UI_WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1760, 720),
]
const MENU_FOCUS_ACTIONS: Array[StringName] = [
	&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]

## Beschreibungen fehlgeschlagener Pruefungen; der Laeufer sammelt sie ein.
var failures: PackedStringArray = []


## Fuehrt die Pruefungen der Suite aus. Wird vom Laeufer awaited.
func run() -> void:
	pass


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [ok]    %s" % description)
	else:
		print("  [FEHLER] %s" % description)
		failures.append(description)

func _load_scene(path: String, properties: Dictionary = {}) -> Node:
	if not ResourceLoader.exists(path):
		_check(false, "Szene vorhanden: %s" % path)
		return null
	var scene: PackedScene = load(path)
	var node: Node = scene.instantiate()
	for key: String in properties:
		node.set(key, properties[key])
	get_tree().root.add_child(node)
	await get_tree().process_frame
	await get_tree().physics_frame
	return node


func _node(root: Node, unique_path: String) -> Node:
	var found := root.get_node_or_null(unique_path)
	if found == null:
		_check(false, "Knoten fehlt: %s" % unique_path)
	return found


func _press(root: Node, unique_path: String) -> void:
	var button := _node(root, unique_path) as Button
	if button != null:
		button.pressed.emit()


func _click_control(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _send_ui_action(action: StringName, target: Viewport = null) -> void:
	if target != null:
		# Eingebettete Fenster erhalten Eingaben ueber ihren Eltern-Viewport.
		var input_target: Viewport = target
		if target is Window and target.is_embedded():
			input_target = target.get_parent().get_viewport()
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey:
				for pressed: bool in [true, false]:
					var key := binding.duplicate() as InputEventKey
					key.pressed = pressed
					key.echo = false
					input_target.push_input(key)
				return
		_check(false, "Tastaturbelegung fehlt fuer %s" % action)
		return
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _check_focus_within(panel: Control, context: String) -> void:
	for action in MENU_FOCUS_ACTIONS:
		_send_ui_action(action)
		var focused := get_viewport().gui_get_focus_owner()
		_check(focused != null and (focused == panel or panel.is_ancestor_of(focused)),
			"Der Fokus bleibt im Dialog: %s (%s)" % [context, action])


## Wartet echte Sekunden.
##
## Frames zu zaehlen und mit 1/60 zu multiplizieren geht hier nicht: headless
## rendert ohne Bildsynchronisierung mit weit ueber 60 Bildern je Sekunde, ein
## "Warten" von 4 Sekunden waere in Wirklichkeit ein Bruchteil davon. Die
## Blenden des SceneRouter laufen aber in echter Zeit.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _screen_tap(control: Control, index: int = 0) -> void:
	var point := control.get_global_rect().get_center()
	_screen_touch(point, index, true)
	await _wait(0.06)
	_screen_touch(point, index, false)
	await _wait(0.2)


func _screen_touch(point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	get_viewport().push_input(event, true)


## Drueckt einen Knopf des Touch-Overlays im Zuhause.
func _home_action(home: Node, button_name: String = "ActionButton") -> void:
	await _wait(0.05)
	var button: Button = home.get_node("TouchControls/Root/" + button_name)
	button.button_down.emit()
	await _wait(0.06)
	button.button_up.emit()
	await _wait(0.06)
