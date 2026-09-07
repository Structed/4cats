## Ein streunender Hund. Kein Gegner im klassischen Sinn -- er ist einfach
## aufgeregt und verscheucht Katzen in seiner Umgebung.
##
## Kommt der Spieler zu nah, erschrickt er ebenfalls und verliert eine
## getragene Katze.
class_name Dog
extends CharacterBody2D

const SPEED := 34.0
const SCARE_RADIUS := 52.0

## Der Hund bleibt in der Naehe seines Startpunktes.
const ROAM_RADIUS := 90.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _scare_area: Area2D = $ScareArea

var _home: Vector2
var _target: Vector2
var _timer: float = 0.0
var _facing: String = "down"
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _atlas: AtlasTexture


func _ready() -> void:
	_home = global_position
	_target = _home

	# Fuer den Hund wird eine der anderen Figuren aus dem Urban Pack benutzt --
	# er liest sich im Spiel als aufgeregter Nachbarshund mit Leine.
	_atlas = AtlasTexture.new()
	_atlas.atlas = load("res://assets/kenney/urban_tilemap.png")
	_sprite.texture = _atlas
	_sprite.scale = Vector2(0.8, 0.8)
	_update_region()

	_scare_area.body_entered.connect(_on_body_entered)
	add_to_group("dogs")


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.0, 2.6)
		_target = _home + Vector2(
			randf_range(-ROAM_RADIUS, ROAM_RADIUS),
			randf_range(-ROAM_RADIUS, ROAM_RADIUS))

	var to_target := _target - global_position
	if to_target.length() < 6.0:
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
	else:
		velocity = velocity.move_toward(to_target.normalized() * SPEED, 300.0 * delta)

	move_and_slide()
	_animate(delta)
	_scare_nearby_cats()


## Katzen in der Naehe werden nervoes und verlieren ihr Vertrauen.
func _scare_nearby_cats() -> void:
	for node in get_tree().get_nodes_in_group("cats"):
		var cat := node as Cat
		if cat == null:
			continue
		if cat.global_position.distance_to(global_position) < SCARE_RADIUS:
			cat.scatter_from(global_position)


func _animate(delta: float) -> void:
	if velocity.length() > 4.0:
		if absf(velocity.x) >= absf(velocity.y):
			_facing = "right" if velocity.x > 0.0 else "left"
		else:
			_facing = "down" if velocity.y > 0.0 else "up"
		_frame_timer += delta
		if _frame_timer >= 0.16:
			_frame_timer -= 0.16
			_frame_index = 1 - _frame_index
		_update_region(UrbanTiles.CHARACTER_ROW_WALK_A + _frame_index)
	else:
		_update_region(UrbanTiles.CHARACTER_ROW_IDLE)


func _update_region(row: int = UrbanTiles.CHARACTER_ROW_IDLE) -> void:
	if _atlas == null:
		return
	# Zeilen 15..17 im Spritesheet sind eine andere Figurenvariante.
	_atlas.region = Rect2(UrbanTiles.character_region(_facing, 15 + row))


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	var player := body as Player
	if player.is_stunned():
		return
	var lost := player.startle()
	if lost != null:
		get_tree().call_group("rescue_level", "on_cat_escaped", lost, player.global_position)
