class_name HomeItemActor
extends Node2D

var data: HomeItemData
var simulation: HomeSimulation
var ghost: bool = false
var allowed: bool = true
var selected: bool = false
var _texture: Texture2D
var _time: float = 0.0

func _ready() -> void:
	_texture = load("res://assets/sprites/home_items.png")
	if not ghost:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(data.rect().size * HomeCatalog.TILE)
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	_update_position()

func _update_position() -> void:
	position = data.center()
	rotation = data.turns * PI / 2.0

func _process(delta: float) -> void:
	_time += delta
	_update_position()
	queue_redraw()

func _draw() -> void:
	if _texture == null:
		return
	var row := 0
	var using_item := simulation != null and simulation.item_in_use(data.id)
	if data.kind in ["food", "water"]:
		row = 1 if data.stock > 0 else 0
	elif data.kind == "litter":
		row = 2 if data.dirt >= HomeCatalog.capacity("litter") else (1 if data.dirt > 0 else 0)
	elif using_item:
		row = 1 + int(_time * 3.0) % 2
	var column := HomeCatalog.KINDS.find(data.kind)
	var tint := Color(0.55, 1.0, 0.7, 0.75) if allowed else Color(1.0, 0.3, 0.3, 0.65)
	var footprint := Vector2(data.rect().size * HomeCatalog.TILE)
	if selected or ghost:
		draw_rect(Rect2(-footprint / 2, footprint), Color("#dba844") if not ghost else tint, false, 1.5)
	draw_texture_rect_region(_texture, Rect2(-16, -16, 32, 32),
		Rect2(column * 32, row * 32, 32, 32), tint if ghost else Color.WHITE)
	if ghost or selected:
		draw_circle(Vector2(0, footprint.y / 2 + 8), 3.0, Color("#dba844"))
	if using_item and data.kind == "wash":
		for i in 4:
			var phase := fmod(_time * 8 + i * 5, 20.0)
			draw_circle(Vector2(-9 + i * 6, -phase), 2.0, Color(0.65, 0.9, 1.0, 0.7))
