## Aggregierte Spielstatistik im Spielstand, ohne Kennungen, Ereignisprotokoll oder Netzverkehr.
class_name GameplayStats
extends RefCounted

const VERSION := 1
const EVENT_KEYS: PackedStringArray = [
	"food_taken", "food_returned", "water_drawn", "water_returned",
	"food_refilled", "water_refilled", "food_package_bought", "food_ordered",
	"food_arrived", "parcel_collected", "food_unpacked", "emergency_claimed",
	"cat_delivered", "cat_became_critical", "cat_recovered_from_critical",
	"cat_adopted", "cat_died",
]
const AMOUNT_KEYS: PackedStringArray = [
	"food_taken_units", "food_returned_units", "water_drawn_units", "water_returned_units",
	"food_refilled_units", "water_refilled_units", "food_purchased_units",
	"food_arrived_units", "food_unpacked_units", "emergency_food_units",
	"food_consumed_units", "water_consumed_units", "coins_spent_food", "coins_spent_delivery",
]
const NEED_KEYS: PackedStringArray = ["hunger", "thirst", "cleanliness", "health", "enrichment"]

var events: Dictionary = {}
var amounts: Dictionary = {}
var need_low_seconds: Dictionary = {}
var active_play_seconds: float = 0.0
var adopted_by_age: Array[int] = [0, 0, 0]
var deceased_by_age: Array[int] = [0, 0, 0]

func _init() -> void:
	for key in EVENT_KEYS:
		events[key] = 0
	for key in AMOUNT_KEYS:
		amounts[key] = 0
	for key in NEED_KEYS:
		need_low_seconds[key] = 0.0

func record(event: String, count: int = 1) -> void:
	if not EVENT_KEYS.has(event) or count < 0:
		push_error("Ungültiges lokales Statistikereignis: %s" % event)
		return
	events[event] = int(events[event]) + count

func add_amount(key: String, amount: int) -> void:
	if not AMOUNT_KEYS.has(key) or amount < 0:
		push_error("Ungültiger lokaler Statistikwert: %s" % key)
		return
	amounts[key] = int(amounts[key]) + amount

func tick(delta: float, cats: Array[CatData]) -> void:
	active_play_seconds += delta
	for cat in cats:
		var needs := cat.needs()
		for key in NEED_KEYS:
			if float(needs[key]) < CatData.RECOVERY_THRESHOLD:
				need_low_seconds[key] = float(need_low_seconds[key]) + delta

func to_dict() -> Dictionary:
	return {"version": VERSION, "events": events.duplicate(), "amounts": amounts.duplicate(),
		"need_low_seconds": need_low_seconds.duplicate(), "active_play_seconds": active_play_seconds,
		"adopted_by_age": adopted_by_age.duplicate(), "deceased_by_age": deceased_by_age.duplicate()}

static func from_dict(raw: Dictionary) -> GameplayStats:
	if not SupplyCatalog.is_count(raw.get("version")) or int(raw["version"]) != VERSION:
		return null
	var active: Variant = raw.get("active_play_seconds")
	if not (active is float or active is int) or not is_finite(float(active)) or float(active) < 0.0:
		return null
	var stats := GameplayStats.new()
	stats.events = _read_values(raw.get("events"), EVENT_KEYS, true)
	stats.amounts = _read_values(raw.get("amounts"), AMOUNT_KEYS, true)
	stats.need_low_seconds = _read_values(raw.get("need_low_seconds"), NEED_KEYS, false)
	if stats.events.is_empty() or stats.amounts.is_empty() or stats.need_low_seconds.is_empty():
		return null
	for key in ["adopted_by_age", "deceased_by_age"]:
		var ages: Variant = raw.get(key)
		if ages is not Array or ages.size() != CatData.AGE_NAMES.size():
			return null
		var parsed: Array[int] = []
		for count: Variant in ages:
			if not SupplyCatalog.is_count(count):
				return null
			parsed.append(int(count))
		if key == "adopted_by_age":
			stats.adopted_by_age = parsed
		else:
			stats.deceased_by_age = parsed
	if _total(stats.adopted_by_age) != int(stats.events["cat_adopted"]) \
			or _total(stats.deceased_by_age) != int(stats.events["cat_died"]):
		return null
	stats.active_play_seconds = float(active)
	return stats

static func _read_values(raw: Variant, keys: PackedStringArray, whole: bool) -> Dictionary:
	if raw is not Dictionary or raw.size() != keys.size():
		return {}
	var values := {}
	for key in keys:
		var value: Variant = raw.get(key)
		if whole:
			if not SupplyCatalog.is_count(value):
				return {}
			values[key] = int(value)
		else:
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
				return {}
			values[key] = float(value)
	return values

static func _total(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
