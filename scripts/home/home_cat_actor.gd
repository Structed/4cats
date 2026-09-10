class_name HomeCatActor
extends Node2D

const DIRECTIONS := {"down": 0, "up": 1, "left": 2, "right": 3}
const NEEDS: PackedStringArray = ["hunger", "thirst", "cleanliness", "health", "enrichment"]

var data: CatData
var simulation: HomeSimulation
var selected: bool = false
var _sprite := Sprite2D.new()
var _atlas := AtlasTexture.new()
var _icons: Texture2D
var _time: float = 0.0
var _facing: String = "down"
var _icon: int = 6

func _ready() -> void:
	_atlas.atlas = load("res://assets/sprites/cats.png")
	_sprite.texture = _atlas
	_sprite.position.y = -4.0
	add_child(_sprite)
	_icons = load("res://assets/sprites/home_icons.png")
	var label := Label.new()
	label.text = data.cat_name
	label.position = Vector2(-32, 7)
	label.size = Vector2(64, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#382c31"))
	add_child(label)

func _process(delta: float) -> void:
	if not simulation.data.cats.has(data.id):
		return
	var state: HomeCatState = simulation.data.cats[data.id]
	position = state.position
	visible = simulation.held_cat_id != data.id
	_time += delta
	var moving := not state.motion.is_zero_approx()
	if moving:
		if absf(state.motion.x) >= absf(state.motion.y):
			_facing = "right" if state.motion.x > 0 else "left"
		else:
			_facing = "down" if state.motion.y > 0 else "up"
	var direction: int = DIRECTIONS[_facing]
	var frame := int(_time / 0.22) % 2 if moving else 0
	_atlas.region = Rect2((direction * 2 + frame) * 16, data.fur_variant * 16, 16, 16)
	var playing := state.task == "toy" and state.path.is_empty()
	_sprite.position.y = -4.0 - absf(sin(_time * 8.0)) * 3.0 if playing else -4.0
	_sprite.rotation = sin(_time * 9.0) * 0.2 if playing else 0.0
	_sprite.modulate = Color("#c3baaf") if data.cleanliness < 50.0 else Color.WHITE
	_icon = 6
	var lowest := CatData.RECOVERY_THRESHOLD
	for index in NEEDS.size():
		var value := float(data.get(NEEDS[index]))
		if value < lowest:
			lowest = value
			_icon = index
	if state.toilet_elapsed >= HomeSimulation.TOILET_INTERVAL:
		_icon = 5
	if not state.target_id.is_empty() and state.path.is_empty():
		_icon = HomeCatalog.KINDS.find(state.task)
	queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow()
	if selected:
		draw_arc(Vector2(0, 3), 10.0, 0.0, TAU, 24, Color("#e8ae48"), 1.5)
	if _icons != null and _icon >= 0:
		draw_circle(Vector2(0, -26), 10.0, Color("#fff5df"))
		draw_circle(Vector2(-3, -15), 2.0, Color("#fff5df"))
		draw_texture_rect_region(_icons, Rect2(-8, -34, 16, 16), Rect2(_icon * 16, 0, 16, 16))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 8, Color(0.15, 0.1, 0.1, 0.18))
	draw_set_transform(Vector2.ZERO)
