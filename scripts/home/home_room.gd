## Baut den Raum des Zuhauses: Boden, Waende, Ausgang, Paketablage.
##
## Steckt bewusst nicht in home_scene.gd: der Aufbau laeuft einmal beim Start
## und hat mit dem Spielgeschehen nichts zu tun. Wer die Optik des Raums
## aendert, fasst damit keine Datei an, in der auch Interaktionen stehen.
class_name HomeRoom
extends RefCounted

const WALL_THICKNESS := 16.0
const PARCEL_STACK := 3
const PAD_IDLE := Color("#a17c5c")
const PAD_FOCUS := Color("#e4b255")
const INK := Color("#382c31")

var _parcel_pad: Polygon2D
var _parcel_count: Label
var _parcel_sprites: Array[Sprite2D] = []


## Legt Boden, Waende und Paketablage unter `parent` an.
func build(parent: Node2D, floor_tiles: TileMapLayer) -> void:
	for y in HomeCatalog.ROOM_SIZE.y:
		for x in HomeCatalog.ROOM_SIZE.x:
			var cell := Vector2i(x, y)
			var tile := (x + y) % 2 if HomeCatalog.inside(cell) else 2
			if cell == HomeCatalog.ENTRY + Vector2i.DOWN:
				tile = 3
			floor_tiles.set_cell(cell, 0, Vector2i(tile, 0))
	var width := float(HomeCatalog.ROOM_SIZE.x * HomeCatalog.TILE)
	var height := float(HomeCatalog.ROOM_SIZE.y * HomeCatalog.TILE)
	var half := WALL_THICKNESS / 2.0
	_wall(parent, Vector2(width / 2, half), Vector2(width, WALL_THICKNESS))
	_wall(parent, Vector2(width / 2, height - half), Vector2(width, WALL_THICKNESS))
	_wall(parent, Vector2(half, height / 2), Vector2(WALL_THICKNESS, height))
	_wall(parent, Vector2(width - half, height / 2), Vector2(WALL_THICKNESS, height))
	var exit_label := Label.new()
	exit_label.text = "Rausgehen"
	exit_label.add_theme_font_size_override("font_size", 10)
	exit_label.add_theme_color_override("font_color", INK)
	exit_label.position = HomeCatalog.world(HomeCatalog.ENTRY) + Vector2(-27, 1)
	exit_label.z_index = -1
	parent.add_child(exit_label)
	_build_parcel_spot(parent)


## Bringt die Paketablage auf den Stand des Spielstands.
##
## `focused` faerbt die Ablage ein, wenn der Spieler sie gerade anvisiert.
func update_parcels(focused: bool) -> void:
	if _parcel_count == null:
		return
	var ready := GameState.supplies.ready_count()
	_parcel_count.text = "Pakete\n%d" % ready
	for index in _parcel_sprites.size():
		_parcel_sprites[index].visible = index < ready
	_parcel_pad.color = PAD_FOCUS if focused else PAD_IDLE


func _build_parcel_spot(parent: Node2D) -> void:
	var spot := Node2D.new()
	spot.name = "ParcelSpot"
	spot.position = HomeCatalog.world(SupplyCatalog.PARCEL_CELL)
	spot.z_index = -1
	parent.add_child(spot)
	_parcel_pad = Polygon2D.new()
	_parcel_pad.name = "ParcelPad"
	_parcel_pad.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(8, -8), Vector2(8, 18), Vector2(-12, 18),
	])
	spot.add_child(_parcel_pad)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/supply_cargo.png")
	atlas.region = Rect2(32, 0, 16, 16)
	for index in PARCEL_STACK:
		var parcel := Sprite2D.new()
		parcel.texture = atlas
		parcel.position = Vector2(index * 2 - 4, 8 - index * 4)
		spot.add_child(parcel)
		_parcel_sprites.append(parcel)
	_parcel_count = Label.new()
	_parcel_count.name = "ParcelCount"
	_parcel_count.position = Vector2(-40, -7)
	_parcel_count.add_theme_font_size_override("font_size", 8)
	_parcel_count.add_theme_color_override("font_color", INK)
	_parcel_count.add_theme_color_override("font_outline_color", Color("#fff0cb"))
	_parcel_count.add_theme_constant_override("outline_size", 2)
	_parcel_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.add_child(_parcel_count)
	update_parcels(false)


func _wall(parent: Node2D, center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	parent.add_child(wall)
