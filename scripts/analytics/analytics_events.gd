class_name AnalyticsEvents
extends RefCounted

const SCHEMA_VERSION := 1
const FIELDS := {
	"play_session_started": {},
	"playtime": {"duration_seconds": TYPE_FLOAT, "scene": TYPE_STRING},
	"game_started": {"kind": TYPE_STRING},
	"scene_entered": {"scene": TYPE_STRING},
	"cat_picked_up": {"pickup_location": TYPE_STRING},
	"cat_rescued": {},
	"cat_adopted": {"reward": TYPE_INT},
	"upgrade_purchased": {"upgrade_id": TYPE_STRING, "level": TYPE_INT, "price": TYPE_INT},
	"home_item_purchased": {"kind": TYPE_STRING, "price": TYPE_INT},
}
const COMMON_FIELDS := [
	"event_id", "distinct_id", "schema_version", "app_version", "platform",
	"$process_person_profile", "game_session_id",
]

static var _uuid_pattern := RegEx.create_from_string(
	"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
static var _timestamp_pattern := RegEx.create_from_string(
	"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z$")


static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]


static func valid_uuid(value: Variant) -> bool:
	if value is not String:
		return false
	return _uuid_pattern.search(value) != null


static func timestamp(utc_ms: int) -> String:
	return "%s.%03dZ" % [
		Time.get_datetime_string_from_unix_time(int(utc_ms / 1000.0)), posmod(utc_ms, 1000),
	]


static func valid_properties(event: String, properties: Dictionary) -> bool:
	if not FIELDS.has(event):
		return false
	var fields: Dictionary = FIELDS[event]
	if properties.size() != fields.size():
		return false
	for key: String in fields:
		var expected: int = fields[key]
		if not properties.has(key) or typeof(properties[key]) != expected:
			return false
		if expected == TYPE_STRING and String(properties[key]).length() > 80:
			return false
	match event:
		"playtime":
			var seconds: float = properties["duration_seconds"]
			return is_finite(seconds) and seconds > 0.0 and seconds <= 60.0 \
				and properties["scene"] in ["home", "rescue"]
		"scene_entered":
			return properties["scene"] in ["home", "rescue"]
		"game_started":
			return properties["kind"] in ["new", "continue"]
		"cat_picked_up":
			return properties["pickup_location"] in ["indoor", "outdoor"]
		"cat_adopted":
			return int(properties["reward"]) >= 0
		"upgrade_purchased":
			return properties["upgrade_id"] in ["carry_capacity", "treats", "comfort", "vet"] \
				and int(properties["level"]) in [1, 2, 3] and int(properties["price"]) >= 0
		"home_item_purchased":
			return HomeCatalog.KINDS.has(properties["kind"]) and int(properties["price"]) >= 0
	return true


static func valid_payload(payload: Dictionary, distinct_id: String) -> bool:
	if payload.size() != 3 or payload.get("event") is not String \
			or payload.get("timestamp") is not String or payload.get("properties") is not Dictionary:
		return false
	var event: String = payload["event"]
	var time: String = payload["timestamp"]
	if not FIELDS.has(event) or _timestamp_pattern.search(time) == null:
		return false
	var properties: Dictionary = payload["properties"]
	for key: String in COMMON_FIELDS:
		if not properties.has(key):
			return false
	if properties["distinct_id"] != distinct_id or not valid_uuid(properties["event_id"]) \
			or not valid_uuid(properties["game_session_id"]) \
			or properties["schema_version"] != SCHEMA_VERSION \
			or properties["$process_person_profile"] is not bool \
			or properties["$process_person_profile"] != false \
			or properties["platform"] not in ["Windows", "Android"] \
			or properties["app_version"] is not String \
			or String(properties["app_version"]).length() > 40:
		return false
	var specific := properties.duplicate()
	for key: String in COMMON_FIELDS:
		specific.erase(key)
	# JSON parses all numbers as floats.
	var fields: Dictionary = FIELDS[event]
	for key: String in fields:
		if fields[key] == TYPE_INT and specific.get(key) is float:
			var number: float = specific[key]
			if not is_finite(number) or number != floor(number) or absf(number) > 1000000000:
				return false
			specific[key] = int(number)
	return valid_properties(event, specific)
