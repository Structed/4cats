class_name SupplyOrder
extends RefCounted

var id: int = 0
var units: int = SupplyCatalog.PACKAGE_UNITS
var remaining: float = 0.0

func to_dict() -> Dictionary:
	return {"id": id, "units": units, "remaining": remaining}

static func from_dict(raw: Dictionary) -> SupplyOrder:
	if not SupplyCatalog.is_count(raw.get("id")) or int(raw["id"]) < 1 \
			or not SupplyCatalog.is_count(raw.get("units")) \
			or int(raw["units"]) != SupplyCatalog.PACKAGE_UNITS:
		return null
	var time: Variant = raw.get("remaining")
	if not (time is float or time is int) or not is_finite(float(time)) or float(time) < 0.0:
		return null
	var order := SupplyOrder.new()
	order.id = int(raw["id"])
	order.units = int(raw["units"])
	order.remaining = float(time)
	return order

