## Die Kollisionen liegen ausschliesslich in der Objekt-Tilemap des Generators.
class_name FoodShop
extends Node2D

const REACH := 22.0

var _generator: LevelGenerator
var _sign: Label
var _counter_hint: Label
var _highlighted: bool = false


func configure(generator: LevelGenerator) -> void:
	_generator = generator
	position = Vector2(generator.shop_area.position) * LevelGenerator.TILE_SIZE
	z_index = 1
	_sign = _label("ShopSign", "Futterladen", 10)
	_sign.position = Vector2(0, -16)
	_sign.size = Vector2(generator.shop_area.size.x * LevelGenerator.TILE_SIZE, 16)
	_counter_hint = _label("CounterHint", "Futterpakete · Theke", 7)
	_counter_hint.position = Vector2(8, 49)
	_counter_hint.size = Vector2(96, 14)
	queue_redraw()


func _label(node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#ffe5b4"))
	label.add_theme_color_override("font_outline_color", Color("#292331"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


func sign_control() -> Control:
	return _sign


func can_interact(player: Node2D) -> bool:
	if _generator == null or not is_instance_valid(player):
		return false
	var target := LevelGenerator.cell_to_world(_generator.shop_cell)
	var origin := player.global_position
	var cell := LevelGenerator.world_to_cell(origin)
	if not _generator.shop_area.has_point(cell) or _generator.is_blocked(cell) \
			or origin.distance_to(target) > REACH:
		return false
	var steps := maxi(1, ceili(origin.distance_to(target) / 4.0))
	for step in range(1, steps + 1):
		var point := origin.lerp(target, float(step) / float(steps))
		if _generator.is_blocked(LevelGenerator.world_to_cell(point)):
			return false
	return true


func set_highlighted(highlighted: bool) -> void:
	if _highlighted == highlighted:
		return
	_highlighted = highlighted
	_counter_hint.text = "E / Aktion: Einkaufen" if highlighted else "Futterpakete · Theke"
	queue_redraw()


func _draw() -> void:
	if _generator == null:
		return
	# Waren liegen sichtbar auf der bereits kollidierenden Theke.
	for column in range(1, 6):
		var corner := Vector2(column * LevelGenerator.TILE_SIZE + 4, 18)
		draw_rect(Rect2(corner, Vector2(8, 10)), Color("#e7c38b"))
		draw_rect(Rect2(corner + Vector2(0, 6), Vector2(8, 3)), Color("#ca734b"))
		draw_circle(corner + Vector2(4, 3), 1.5, Color("#664951"))
	var entrance: Vector2 = LevelGenerator.cell_to_world(_generator.shop_entry) - position
	draw_line(entrance + Vector2(-20, 0), entrance + Vector2(20, 0),
		Color("#e7c38b"), 2.0)
	if _highlighted:
		var target: Vector2 = LevelGenerator.cell_to_world(_generator.shop_cell) - position
		draw_arc(target + Vector2(0, 3), 7, 0, TAU, 24, Color("#ffe5b4"), 1.5)
