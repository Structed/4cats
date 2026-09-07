## Kleiner Vertrauensbalken ueber einer Katze.
##
## Zeichnet sich selbst, damit dafuer kein zusaetzliches Bildmaterial noetig ist.
extends Node2D

const WIDTH := 14.0
const HEIGHT := 3.0

const BACKGROUND := Color(0.08, 0.09, 0.12, 0.75)
const LOW := Color(0.90, 0.45, 0.35)
const HIGH := Color(0.45, 0.85, 0.45)

@onready var _cat: Cat = get_parent() as Cat


func _draw() -> void:
	if _cat == null:
		return
	var progress := clampf(_cat.trust / Cat.TRUST_THRESHOLD, 0.0, 1.0)
	var origin := Vector2(-WIDTH * 0.5, 0.0)

	draw_rect(Rect2(origin - Vector2.ONE, Vector2(WIDTH, HEIGHT) + Vector2.ONE * 2.0), BACKGROUND)
	draw_rect(Rect2(origin, Vector2(WIDTH * progress, HEIGHT)), LOW.lerp(HIGH, progress))
