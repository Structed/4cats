## Der Spielcharakter in der Rettungs-Phase.
##
## Bewegt sich in vier Richtungen, sammelt Katzen ein und traegt sie sichtbar
## ueber dem Kopf. Die Eingabe kommt immer aus der InputMap -- Tastatur und
## virtueller Joystick landen dort gleichermassen.
##
## Normales Gehen ist ruhig genug, dass Katzen Vertrauen fassen. Wer schneller
## vorankommen will, sprintet -- das verschreckt sie aber. So bleibt die Wahl
## beim Spieler, statt ihn zu zwingen, den Joystick millimetergenau zu halten.
class_name Player
extends CharacterBody2D

signal carry_visual_changed()

## Gehtempo. Muss unter Cat.CALM_SPEED_LIMIT liegen, sonst fliehen alle Katzen.
const WALK_SPEED := 62.0

## Sprinttempo. Deutlich ueber dem Ruhe-Limit -- das schreckt Katzen auf.
const SPRINT_SPEED := 108.0

const ACCELERATION := 900.0
const FRICTION := 1100.0

## Sekunden pro Laufbild beim Gehen; beim Sprinten entsprechend schneller.
const FRAME_TIME := 0.14

## So lange ist der Spieler nach einem Schreck unverwundbar.
const STUN_TIME := 0.9

@onready var _sprite: Sprite2D = $Sprite
@onready var _carry_slot: Node2D = $CarrySlot
@onready var _interaction_area: Area2D = $InteractionArea

var _facing: String = "down"
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _stun_timer: float = 0.0
var _sprinting: bool = false

var _atlas: AtlasTexture


func _ready() -> void:
	_atlas = AtlasTexture.new()
	_atlas.atlas = load("res://assets/kenney/urban_tilemap.png")
	_sprite.texture = _atlas
	_update_sprite_region()

	GameState.carried_changed.connect(_on_carried_changed)
	_rebuild_carry_visual()


func _physics_process(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer -= delta
		_sprite.modulate.a = 0.45 + 0.55 * absf(sin(_stun_timer * 22.0))
		if _stun_timer <= 0.0:
			_sprite.modulate.a = 1.0

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 1.0:
		input = input.normalized()

	_sprinting = Input.is_action_pressed("sprint") and not input.is_zero_approx()

	if input.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(input * current_speed(), ACCELERATION * delta)

	move_and_slide()
	_animate(delta, input)


## Aktuelles Hoechsttempo -- je nachdem, ob gesprintet wird.
func current_speed() -> float:
	return SPRINT_SPEED if _sprinting else WALK_SPEED


## Sprintet der Spieler gerade? Katzen lesen daran ab, ob sie erschrecken.
func is_sprinting() -> bool:
	return _sprinting


func _animate(delta: float, input: Vector2) -> void:
	if not input.is_zero_approx():
		# Waagerechte Bewegung gewinnt, das wirkt bei Diagonalen ruhiger.
		if absf(input.x) >= absf(input.y):
			_facing = "right" if input.x > 0.0 else "left"
		else:
			_facing = "down" if input.y > 0.0 else "up"

		_frame_timer += delta
		# Beim Sprinten schneller trippeln -- das macht den Zustand sichtbar.
		var frame_time := FRAME_TIME * 0.6 if _sprinting else FRAME_TIME
		if _frame_timer >= frame_time:
			_frame_timer -= frame_time
			_frame_index = 1 - _frame_index
		_update_sprite_region(UrbanTiles.CHARACTER_ROW_WALK_A + _frame_index)
	else:
		_frame_timer = 0.0
		_frame_index = 0
		_update_sprite_region(UrbanTiles.CHARACTER_ROW_IDLE)


func _update_sprite_region(row: int = UrbanTiles.CHARACTER_ROW_IDLE) -> void:
	if _atlas == null:
		return
	_atlas.region = Rect2(UrbanTiles.character_region(_facing, row))


## Alle Katzen in Reichweite, sortiert nach Entfernung.
func cats_in_reach() -> Array[Cat]:
	var found: Array[Cat] = []
	for body in _interaction_area.get_overlapping_bodies():
		if body is Cat and (body as Cat).is_catchable():
			found.append(body)
	found.sort_custom(func(a: Cat, b: Cat) -> bool:
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	return found


func is_stunned() -> bool:
	return _stun_timer > 0.0


## Schreck: der Spieler wird kurz benommen und verliert eine getragene Katze.
func startle() -> CatData:
	if is_stunned():
		return null
	_stun_timer = STUN_TIME
	AudioManager.play_sfx("scare")
	return GameState.lose_carried_cat()


func _on_carried_changed(_carried: int, _capacity: int) -> void:
	_rebuild_carry_visual()


## Zeigt die getragenen Katzen als kleine Sprites ueber dem Kopf.
func _rebuild_carry_visual() -> void:
	if _carry_slot == null:
		return
	for child in _carry_slot.get_children():
		child.queue_free()

	var texture: Texture2D = load("res://assets/sprites/cats.png")
	for i in GameState.carried_cats.size():
		var cat: CatData = GameState.carried_cats[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		# Spalte 0 ist die Ansicht von unten im Ruhebild.
		atlas.region = Rect2(0, cat.fur_variant * 16, 16, 16)

		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.scale = Vector2(0.7, 0.7)
		sprite.position = Vector2(0.0, -6.0 * float(i))
		_carry_slot.add_child(sprite)

	carry_visual_changed.emit()
