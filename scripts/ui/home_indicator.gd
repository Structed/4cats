## Dauerhafter Wegweiser zur Heimzone, unabhaengig vom Inhalt des Tragekorbs.
class_name HomeIndicator
extends Control

const MARKER_RADIUS := 16.0
const EDGE_GAP := 8.0
const UI_GAP := 6.0
const HOME_OFFSET := Vector2(0, -34)
const ARROW_COLOR := Color(0.45, 0.95, 0.6)
const OUTLINE_COLOR := Color(0.04, 0.08, 0.06)
const OUTLINE_WIDTH := 4.0
const ARROW_POINTS: PackedVector2Array = [
	Vector2(-11, -5), Vector2(1, -5), Vector2(1, -10), Vector2(14, 0),
	Vector2(1, 10), Vector2(1, 5), Vector2(-11, 5),
]

var marker_position := Vector2.ZERO
var marker_angle := 0.0

var _player: Node2D
var _home_zone: Node2D
var _obstacles: Array[Control] = []
var _has_target: bool = false
var _layout_obstructed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Erst nach der Kamera rechnen, damit Nachfuehrung und Limits schon gelten.
	process_priority = 1
	set_process(false)


func configure(player: Node2D, home_zone: Node2D, obstacles: Array[Control]) -> void:
	_player = player
	_home_zone = home_zone
	_obstacles = obstacles.duplicate()
	set_process(true)
	_update_marker()


func _process(_delta: float) -> void:
	_update_marker()


func _update_marker() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_home_zone):
		push_error("Zuhause-Wegweiser: Spieler oder Heimzone fehlt.")
		_has_target = false
		set_process(false)
		queue_redraw()
		return

	var hud_inverse := get_global_transform_with_canvas().affine_inverse()
	var player_position: Vector2 = hud_inverse * _player.get_global_transform_with_canvas().origin
	var home_position: Vector2 = hud_inverse * _home_zone.get_global_transform_with_canvas().origin
	var viewport_rect: Rect2 = hud_inverse * get_viewport_rect()
	var occupied: Array[Rect2] = []
	for obstacle in _obstacles:
		if obstacle.is_visible_in_tree():
			var transform := hud_inverse * obstacle.get_global_transform_with_canvas()
			occupied.append(transform * Rect2(Vector2.ZERO, obstacle.size))

	marker_position = calculate_position(player_position, home_position, viewport_rect, occupied)
	var direction := home_position - marker_position
	marker_angle = PI * 0.5 if direction.is_zero_approx() else direction.angle()
	_has_target = true

	var obstructed := not _is_clear(marker_position, occupied)
	if obstructed and not _layout_obstructed:
		push_warning("Zuhause-Wegweiser: Kein freier Platz neben den Bedienelementen.")
	_layout_obstructed = obstructed
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	draw_set_transform(marker_position, marker_angle)
	draw_polyline(ARROW_POINTS, OUTLINE_COLOR, OUTLINE_WIDTH)
	draw_line(ARROW_POINTS[-1], ARROW_POINTS[0], OUTLINE_COLOR, OUTLINE_WIDTH)
	draw_colored_polygon(ARROW_POINTS, ARROW_COLOR)


## Alle Koordinaten liegen im HUD-Raum; die Berechnung braucht keine Szene.
static func calculate_position(
		player_position: Vector2, home_position: Vector2, viewport_rect: Rect2,
		obstacles: Array[Rect2] = []) -> Vector2:
	var inset := minf(MARKER_RADIUS + EDGE_GAP,
		minf(viewport_rect.size.x, viewport_rect.size.y) * 0.5)
	var bounds := viewport_rect.grow(-inset)
	var on_screen := viewport_rect.has_point(home_position)
	var preferred := (home_position + HOME_OFFSET).clamp(bounds.position, bounds.end)
	if not on_screen:
		preferred = _ray_to_edge(player_position, home_position, bounds)
	if _is_clear(preferred, obstacles):
		return preferred

	# Der naechste freie Punkt liegt auf einer Rechteckkante oder deren
	# Schnittpunkt. Das erfasst auch einander ueberlappende UI-Bereiche.
	var xs: Array[float] = [preferred.x, bounds.position.x, bounds.end.x]
	var ys: Array[float] = [preferred.y, bounds.position.y, bounds.end.y]
	for obstacle in obstacles:
		var padded := obstacle.grow(MARKER_RADIUS + UI_GAP)
		xs.append(clampf(padded.position.x, bounds.position.x, bounds.end.x))
		xs.append(clampf(padded.end.x, bounds.position.x, bounds.end.x))
		ys.append(clampf(padded.position.y, bounds.position.y, bounds.end.y))
		ys.append(clampf(padded.end.y, bounds.position.y, bounds.end.y))

	var nearest := preferred
	var nearest_distance := INF
	for x in xs:
		for y in ys:
			var candidate := Vector2(x, y)
			if not on_screen and not _is_on_edge(candidate, bounds):
				continue
			var distance := candidate.distance_squared_to(preferred)
			if distance < nearest_distance and _is_clear(candidate, obstacles):
				nearest = candidate
				nearest_distance = distance
	# Falls die UI alles belegt, bleibt der Pfeil sichtbar. Der Aufrufer
	# meldet diesen Ausnahmefall, ohne jede Bildaktualisierung zu protokollieren.
	return nearest


static func _ray_to_edge(origin: Vector2, target: Vector2, bounds: Rect2) -> Vector2:
	var start := origin.clamp(bounds.position, bounds.end)
	var direction := target - start
	if direction.is_zero_approx():
		return start

	var factor := INF
	if not is_zero_approx(direction.x):
		var edge := bounds.end.x if direction.x > 0.0 else bounds.position.x
		factor = minf(factor, (edge - start.x) / direction.x)
	if not is_zero_approx(direction.y):
		var edge := bounds.end.y if direction.y > 0.0 else bounds.position.y
		factor = minf(factor, (edge - start.y) / direction.y)
	return (start + direction * factor).clamp(bounds.position, bounds.end)


static func _is_on_edge(point: Vector2, bounds: Rect2) -> bool:
	return (is_equal_approx(point.x, bounds.position.x)
		or is_equal_approx(point.x, bounds.end.x)
		or is_equal_approx(point.y, bounds.position.y)
		or is_equal_approx(point.y, bounds.end.y))


static func _is_clear(point: Vector2, obstacles: Array[Rect2]) -> bool:
	for obstacle in obstacles:
		var padded := obstacle.grow(MARKER_RADIUS + UI_GAP)
		if (point.x > padded.position.x and point.x < padded.end.x
				and point.y > padded.position.y and point.y < padded.end.y):
			return false
	return true
