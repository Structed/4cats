## Eine Streunerkatze in der Rettungs-Phase.
##
## Verhalten in Kurzform: Die Katze streunt herum. Naehert sich der Spieler in
## normalem Gehtempo, fasst sie Vertrauen und laesst sich schliesslich aufheben.
## Nur wer sprintet, erschreckt sie -- dann laeuft sie ein Stueck weg, beruhigt
## sich aber wieder. Fliehen ist absichtlich langsamer als Gehen, damit man eine
## aufgeschreckte Katze immer wieder einholen kann.
class_name Cat
extends CharacterBody2D

signal trust_changed(trust: float)
signal picked_up(cat: Cat)

enum State { WANDER, ALERT, FLEE, TRUSTING }

const WANDER_SPEED := 18.0

## Bewusst unter Player.WALK_SPEED -- eine Katze muss einholbar bleiben.
const FLEE_SPEED := 44.0

## Ab dieser Naehe reagiert die Katze ueberhaupt auf den Spieler.
const NOTICE_RADIUS := 64.0

## So nah muss man sein, damit Vertrauen waechst.
const TRUST_RADIUS := 40.0

## Ueber dieser Geschwindigkeit gilt der Spieler als hektisch. Liegt zwischen
## Geh- und Sprinttempo: gemuetlich gehen ist immer in Ordnung.
const CALM_SPEED_LIMIT := 80.0

## So lange rennt eine aufgeschreckte Katze, danach beruhigt sie sich.
const FLEE_DURATION := 1.1

## Vertrauen ab diesem Wert reicht zum Aufheben.
const TRUST_THRESHOLD := 1.0

const TRUST_GAIN := 0.85
const TRUST_LOSS := 0.7

const FRAME_TIME := 0.22

## Spaltenreihenfolge im Katzen-Spritesheet.
const DIRECTION_COLUMNS := {"down": 0, "up": 1, "left": 2, "right": 3}

@onready var _sprite: Sprite2D = $Sprite
@onready var _trust_bar: Node2D = $TrustBar

var data: CatData

var state: State = State.WANDER
var trust: float = 0.0

var _player: Player
var _wander_target: Vector2
var _wander_timer: float = 0.0
var _flee_timer: float = 0.0
var _facing: String = "down"
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _atlas: AtlasTexture
var _bounds: Rect2 = Rect2()


func _ready() -> void:
	if data == null:
		data = CatData.create_random()

	_atlas = AtlasTexture.new()
	_atlas.atlas = load("res://assets/sprites/cats.png")
	_sprite.texture = _atlas
	_update_sprite_region()

	_wander_target = global_position
	add_to_group("cats")


## Begrenzt die Katze auf das Spielfeld, damit sie nicht ins Nichts flieht.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


func set_player(player: Player) -> void:
	_player = player


func _physics_process(delta: float) -> void:
	_update_state(delta)

	match state:
		State.FLEE:
			_do_flee(delta)
		State.ALERT, State.TRUSTING:
			velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		_:
			_do_wander(delta)

	move_and_slide()
	_clamp_to_bounds()
	_animate(delta)
	# Waehrend der Flucht bleibt der Balken sichtbar -- so sieht man, dass das
	# Vertrauen nicht komplett verloren ist und ein zweiter Versuch lohnt.
	_trust_bar.visible = trust > 0.05
	_trust_bar.queue_redraw()


func _update_state(delta: float) -> void:
	if _player == null:
		state = State.WANDER
		return

	# Eine aufgeschreckte Katze rennt erst ihre Panik ab. Ohne diesen Timer
	# bliebe sie im Fluchtzustand, solange der Spieler in der Naehe ist --
	# und liefe damit bis ans Levelende.
	if _flee_timer > 0.0:
		_flee_timer -= delta
		state = State.FLEE
		return

	var distance := global_position.distance_to(_player.global_position)
	var startling := _player.velocity.length() > CALM_SPEED_LIMIT

	if distance > NOTICE_RADIUS:
		state = State.WANDER
		trust = maxf(trust - TRUST_LOSS * 0.25 * delta, 0.0)
		trust_changed.emit(trust)
		return

	if startling and distance < TRUST_RADIUS:
		# Zu hektisch -- die Katze nimmt kurz Reissaus.
		_flee_timer = FLEE_DURATION
		state = State.FLEE
		# Vertrauen faellt spuerbar, aber nicht auf null: die Muehe bleibt.
		trust = maxf(trust - 0.35, 0.0)
		trust_changed.emit(trust)
		return

	if distance <= TRUST_RADIUS and not startling:
		var gain := TRUST_GAIN * (1.0 - 0.6 * _effective_shyness()) * delta
		trust = minf(trust + gain, TRUST_THRESHOLD)
		state = State.TRUSTING if is_catchable() else State.ALERT
		trust_changed.emit(trust)
		return

	state = State.ALERT


## Leckerli-Upgrades machen alle Katzen zutraulicher.
func _effective_shyness() -> float:
	return clampf(data.shyness * GameState.shyness_multiplier(), 0.0, 1.0)


func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.2, 3.4)
		if randf() < 0.45:
			_wander_target = global_position
		else:
			_wander_target = global_position + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))

	var to_target := _wander_target - global_position
	if to_target.length() < 4.0:
		velocity = velocity.move_toward(Vector2.ZERO, 120.0 * delta)
	else:
		velocity = velocity.move_toward(to_target.normalized() * WANDER_SPEED, 240.0 * delta)


func _do_flee(delta: float) -> void:
	if _player == null:
		return
	var away := (global_position - _player.global_position)
	if away.is_zero_approx():
		away = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = velocity.move_toward(away.normalized() * FLEE_SPEED, 400.0 * delta)


func _clamp_to_bounds() -> void:
	if _bounds.size.is_zero_approx():
		return
	global_position = global_position.clamp(_bounds.position, _bounds.end)


func is_catchable() -> bool:
	return trust >= TRUST_THRESHOLD


## Wird von der Level-Szene aufgerufen, wenn der Spieler die Katze aufnimmt.
func pick_up() -> bool:
	if not is_catchable():
		return false
	if not GameState.pick_up_cat(data):
		return false
	picked_up.emit(self)
	AudioManager.play_sfx_varied("pickup")
	AudioManager.play_sfx_varied("meow", 0.2)
	queue_free()
	return true


## Setzt eine erschrockene Katze in Bewegung, weg von `origin`.
## Wird von Hunden und von entwischten Katzen genutzt.
func scatter_from(origin: Vector2) -> void:
	# Nicht bei jedem Frame neu erschrecken -- sonst haelt ein danebenstehender
	# Hund die Katze dauerhaft auf Vertrauen null.
	if _flee_timer > 0.0:
		return
	trust = maxf(trust - 0.5, 0.0)
	trust_changed.emit(trust)
	_flee_timer = FLEE_DURATION
	state = State.FLEE
	var away := (global_position - origin)
	if away.is_zero_approx():
		away = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = away.normalized() * FLEE_SPEED


func _animate(delta: float) -> void:
	if velocity.length() > 4.0:
		if absf(velocity.x) >= absf(velocity.y):
			_facing = "right" if velocity.x > 0.0 else "left"
		else:
			_facing = "down" if velocity.y > 0.0 else "up"
		_frame_timer += delta
		if _frame_timer >= FRAME_TIME:
			_frame_timer -= FRAME_TIME
			_frame_index = 1 - _frame_index
	else:
		_frame_index = 0
	_update_sprite_region()


func _update_sprite_region() -> void:
	if _atlas == null or data == null:
		return
	# Je Richtung zwei Bilder: unten, oben, links, rechts.
	var direction_index: int = DIRECTION_COLUMNS.get(_facing, 0)
	var column := direction_index * 2 + _frame_index
	_atlas.region = Rect2(column * 16, data.fur_variant * 16, 16, 16)
