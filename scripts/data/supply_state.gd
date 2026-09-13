class_name SupplyState
extends RefCounted

var food_stock: int = SupplyCatalog.START_FOOD
var cargo_kind: String = ""
var cargo_amount: int = 0
var orders: Array[SupplyOrder] = []
var next_order: int = 1

func step(delta: float) -> bool:
	var arrived := false
	for order in orders:
		if order.remaining <= 0.0:
			continue
		order.remaining = maxf(0.0, order.remaining - delta)
		arrived = arrived or order.remaining <= 0.0
	return arrived

func ready_count() -> int:
	var count := 0
	for order in orders:
		if order.remaining <= 0.0:
			count += 1
	return count

func next_arrival() -> float:
	var soonest := INF
	for order in orders:
		if order.remaining > 0.0:
			soonest = minf(soonest, order.remaining)
	return soonest

func clear_cargo() -> void:
	cargo_kind = ""
	cargo_amount = 0

func cargo_text() -> String:
	match cargo_kind:
		"food": return "Futter: %d Portionen" % cargo_amount
		"water": return "Wasser: %d Portionen" % cargo_amount
		"package": return "Futterpaket: %d Portionen" % cargo_amount
	return "Hände frei"

func to_dict() -> Dictionary:
	var stored: Array[Dictionary] = []
	for order in orders:
		stored.append(order.to_dict())
	return {"food_stock": food_stock, "cargo_kind": cargo_kind,
		"cargo_amount": cargo_amount, "orders": stored, "next_order": next_order}

static func from_dict(raw: Dictionary) -> SupplyState:
	for key in ["food_stock", "cargo_amount", "next_order"]:
		if not SupplyCatalog.is_count(raw.get(key)):
			return null
	var kind: Variant = raw.get("cargo_kind")
	if kind is not String or not SupplyCatalog.CARGO_KINDS.has(kind) \
			or raw.get("orders") is not Array:
		return null
	var amount := int(raw["cargo_amount"])
	if amount > SupplyCatalog.cargo_capacity(kind) \
			or (kind.is_empty() != (amount == 0)):
		return null
	var state := SupplyState.new()
	state.food_stock = int(raw["food_stock"])
	state.cargo_kind = kind
	state.cargo_amount = amount
	state.next_order = int(raw["next_order"])
	if state.next_order < 1:
		return null
	var ids := {}
	for entry: Variant in raw["orders"]:
		if entry is not Dictionary:
			return null
		var order := SupplyOrder.from_dict(entry)
		if order == null or ids.has(order.id) or order.id >= state.next_order:
			return null
		ids[order.id] = true
		state.orders.append(order)
	return state

