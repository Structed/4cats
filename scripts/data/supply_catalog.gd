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

## Wohin das Getragene gehoert.
static func cargo_destination(kind: String) -> String:
	match kind:
		"food": return "Zum Futternapf tragen; Reste am Schrank zurücklegen."
		"water": return "Zum Wassernapf tragen; Reste am Hahn zurückgeben."
		"package": return "Paket zuerst am Vorratsschrank einräumen."
	return ""

## Aufforderung, die Haende erst frei zu machen.
static func cargo_return_hint(kind: String) -> String:
	match kind:
		"food": return "Lege das Futter zuerst im Vorratsschrank zurück."
		"water": return "Gib das Wasser zuerst am Hahn zurück."
		"package": return "Räume das Paket zuerst im Vorratsschrank ein."
	return ""

static func is_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) == floorf(float(value)) \
		and float(value) <= 9007199254740991.0

