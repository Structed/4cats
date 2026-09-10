class_name HomeCatState
extends RefCounted

var position: Vector2 = HomeCatalog.world(HomeCatalog.ENTRY - Vector2i(0, 2))
var toilet_elapsed: float = 0.0
var task: String = "idle"
var target_id: String = ""
var path: PackedVector2Array = []
var elapsed: float = 0.0
var wait_time: float = 0.0
var motion: Vector2 = Vector2.ZERO

func clear_task() -> void:
	task = "idle"
	target_id = ""
	path.clear()
	elapsed = 0.0
	wait_time = 0.0
	motion = Vector2.ZERO

func to_dict() -> Dictionary:
	return {"position": [position.x, position.y], "toilet_elapsed": toilet_elapsed}

static func from_dict(raw: Dictionary) -> HomeCatState:
	var point: Variant = raw.get("position")
	var toilet: Variant = raw.get("toilet_elapsed")
	if point is not Array or point.size() != 2 or not (toilet is float or toilet is int):
		return null
	for coordinate: Variant in point:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return null
	if not is_finite(float(toilet)) or float(toilet) < 0.0:
		return null
	var state := HomeCatState.new()
	state.position = Vector2(float(point[0]), float(point[1]))
	state.toilet_elapsed = float(toilet)
	return state
