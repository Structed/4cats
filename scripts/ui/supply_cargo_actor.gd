class_name SupplyCargoActor
extends Node2D

const COLUMNS := {"food": 0, "water": 1, "package": 2}

var _texture: Texture2D
var _kind: String = ""

func _ready() -> void:
	position = Vector2(9, -10)
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = load("res://assets/sprites/supply_cargo.png")
	GameState.supplies_changed.connect(_refresh)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var kind: String = GameState.supplies.cargo_kind
	visible = not kind.is_empty() and GameState.supplies.cargo_amount > 0
	if kind != _kind:
		_kind = kind
		queue_redraw()

func _draw() -> void:
	if _texture == null or not COLUMNS.has(_kind):
		return
	var column: int = COLUMNS[_kind]
	draw_texture_rect_region(_texture, Rect2(-8, -8, 16, 16),
		Rect2(column * 16, 0, 16, 16))
