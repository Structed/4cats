## Virtueller Joystick fuer Touch-Bedienung.
##
## Der Joystick speist seine Auslenkung direkt in die InputMap ein
## (`Input.action_press` mit Staerke). Dadurch funktioniert im restlichen
## Spielcode weiterhin schlicht `Input.get_vector(...)` und Tastatur- sowie
## Touch-Eingabe teilen sich denselben Codepfad.
##
## Im dynamischen Modus erscheint der Joystick dort, wo der Daumen aufsetzt --
## das ist auf Handys deutlich angenehmer als eine feste Position.
##
## Der Name lautet bewusst nicht „VirtualJoystick": so heisst in Godot 4.7
## bereits eine eingebaute Klasse.
class_name TouchJoystick
extends Control

## Unterhalb dieser Auslenkung gilt der Stick als neutral.
@export_range(0.0, 0.5) var deadzone: float = 0.18

## Maximaler Ausschlag des Knopfes in Pixeln.
@export var max_radius: float = 46.0

## Wenn true, erscheint der Joystick an der Beruehrungsstelle.
@export var dynamic: bool = true

## Zeigt die Touch-Zone auch ohne aufgelegten Finger, etwa beim Einrichten.
@export var show_idle_hint: bool = false:
	set(shown):
		show_idle_hint = shown
		queue_redraw()

@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_up"
@export var action_down: StringName = &"move_down"

@export var base_color: Color = Color(1, 1, 1, 0.16)
@export var knob_color: Color = Color(1, 1, 1, 0.42)

## Aktuelle Auslenkung, normalisiert auf Laenge 0..1.
var value: Vector2 = Vector2.ZERO

var _active: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_origin = size * 0.5
	_knob = _origin


func _notification(what: int) -> void:
	# Beim Verlassen des Baums duerfen keine Aktionen haengen bleiben.
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_release()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_begin(touch.position, touch.index)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _touch_index:
			_update(drag.position)
			accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _active:
				_begin(mb.position, -1)
			elif not mb.pressed and _touch_index == -1:
				_release()
			accept_event()

	elif event is InputEventMouseMotion and _active and _touch_index == -1:
		_update((event as InputEventMouseMotion).position)
		accept_event()


func _begin(local_position: Vector2, index: int) -> void:
	_active = true
	_touch_index = index
	_origin = local_position if dynamic else size * 0.5
	_update(local_position)


func _update(local_position: Vector2) -> void:
	var offset := local_position - _origin
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	_knob = _origin + offset

	var raw := offset / max_radius
	value = Vector2.ZERO if raw.length() < deadzone else raw
	_apply_to_input_map()
	queue_redraw()


func _release() -> void:
	if not _active and value.is_zero_approx():
		return
	_active = false
	_touch_index = -1
	value = Vector2.ZERO
	_origin = size * 0.5
	_knob = _origin
	_apply_to_input_map()
	queue_redraw()


## Uebertraegt die Auslenkung als analoge Aktionsstaerke in die InputMap.
func _apply_to_input_map() -> void:
	_set_axis(action_right, maxf(value.x, 0.0))
	_set_axis(action_left, maxf(-value.x, 0.0))
	_set_axis(action_down, maxf(value.y, 0.0))
	_set_axis(action_up, maxf(-value.y, 0.0))


func _set_axis(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _draw() -> void:
	if not _active:
		# Im Ruhezustand nur eine dezente Andeutung in der Mitte.
		if dynamic and not show_idle_hint:
			return
		var idle_color := Color(0.09, 0.12, 0.17, 0.65) if show_idle_hint else base_color
		draw_circle(size * 0.5, max_radius, idle_color)
		draw_arc(size * 0.5, max_radius, 0.0, TAU, 32, knob_color, 2.0, true)
		draw_circle(size * 0.5, max_radius * 0.42, knob_color)
		return

	draw_circle(_origin, max_radius, base_color)
	draw_arc(_origin, max_radius, 0.0, TAU, 32, knob_color, 2.0, true)
	draw_circle(_knob, max_radius * 0.42, knob_color)
