## Ein Auto, das eine der senkrechten Strassen entlangfaehrt.
##
## Trifft es den Spieler, erschrickt der -- und eine getragene Katze entwischt.
## Es gibt keinen Schaden und kein Scheitern: das Spiel soll freundlich bleiben.
class_name Car
extends Area2D

const MIN_SPEED := 46.0
const MAX_SPEED := 78.0

## Faehrt das Auto nach unten (sonst nach oben)?
var driving_down: bool = true

var speed: float = 60.0

## Untere bzw. obere Grenze, ab der das Auto wieder oben/unten erscheint.
var travel_min: float = 0.0
var travel_max: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	speed = randf_range(MIN_SPEED, MAX_SPEED)
	_apply_look()
	body_entered.connect(_on_body_entered)


func _apply_look() -> void:
	var region: Rect2i = UrbanTiles.CAR_REGIONS[randi() % UrbanTiles.CAR_REGIONS.size()]
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/kenney/urban_tilemap.png")
	atlas.region = Rect2(region)
	_sprite.texture = atlas
	# Die Sprites zeigen die Front; nach oben fahrende Autos werden gedreht.
	_sprite.flip_v = not driving_down


func _physics_process(delta: float) -> void:
	var direction := 1.0 if driving_down else -1.0
	position.y += direction * speed * delta

	# Am Ende der Strasse wieder auf der anderen Seite einsetzen.
	if driving_down and position.y > travel_max:
		position.y = travel_min
	elif not driving_down and position.y < travel_min:
		position.y = travel_max


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	var player := body as Player
	if player.is_stunned():
		return
	var lost := player.startle()
	if lost != null:
		get_tree().call_group("rescue_level", "on_cat_escaped", lost, player.global_position)
