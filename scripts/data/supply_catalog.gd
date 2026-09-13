class_name SupplyCatalog
extends RefCounted

const PACKAGE_UNITS := 24
const START_FOOD := PACKAGE_UNITS
const EMERGENCY_UNITS := 6
const CARGO_KINDS: PackedStringArray = ["", "food", "water", "package"]
const FIXTURES: PackedStringArray = ["pantry", "faucet"]
const PARCEL_CELL := Vector2i(16, 17)

static func cargo_capacity(kind: String) -> int:
	if kind == "package":
		return PACKAGE_UNITS
	if kind in ["food", "water"]:
		return HomeCatalog.capacity(kind)
	return 0

static func is_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) == floorf(float(value)) \
		and float(value) <= 9007199254740991.0

