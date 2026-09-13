class_name SupplyActions
extends RefCounted

var supplies: SupplyState
var home: HomeData
var simulation: HomeSimulation

func _init(stock: SupplyState, house: HomeData, cats: HomeSimulation) -> void:
	supplies = stock
	home = house
	simulation = cats

func free_hands_error() -> String:
	if not simulation.held_cat_id.is_empty():
		return "Setze zuerst die Katze ab."
	if not supplies.cargo_kind.is_empty():
		return "Räume zuerst deine Ladung ein oder gib sie zurück."
	return ""

func use_station(id: String) -> String:
	var item := home.item_by_id(id)
	if item == null or not item.placed or not SupplyCatalog.FIXTURES.has(item.kind):
		return "Diese Versorgungsstation ist nicht aufgestellt."
	if not simulation.held_cat_id.is_empty():
		return "Setze zuerst die Katze ab."
	if item.kind == "pantry":
		if supplies.cargo_kind in ["food", "package"]:
			supplies.food_stock += supplies.cargo_amount
			supplies.clear_cargo()
		elif not supplies.cargo_kind.is_empty():
			return "Wasser gehört zum Wassernapf oder zurück zum Hahn."
		elif supplies.food_stock <= 0:
			return "Der Schrank ist leer. Kaufe Futter im Laden oder bestelle Nachschub."
		else:
			supplies.cargo_kind = "food"
			supplies.cargo_amount = mini(supplies.food_stock, SupplyCatalog.cargo_capacity("food"))
			supplies.food_stock -= supplies.cargo_amount
	else:
		if supplies.cargo_kind == "water":
			supplies.clear_cargo()
		elif not supplies.cargo_kind.is_empty():
			return "Räume das Futter zuerst in den Vorratsschrank."
		else:
			supplies.cargo_kind = "water"
			supplies.cargo_amount = SupplyCatalog.cargo_capacity("water")
	return ""

func refill_bowl(id: String) -> String:
	var item := home.item_by_id(id)
	if item == null or not item.placed or item.kind not in ["food", "water"]:
		return "Dieser Napf ist nicht aufgestellt."
	if not simulation.held_cat_id.is_empty():
		return "Setze zuerst die Katze ab."
	var missing := HomeCatalog.capacity(item.kind) - item.stock
	if missing <= 0:
		return "Dieser Napf ist schon voll."
	if supplies.cargo_kind == "package":
		return "Räume das Paket zuerst in den Vorratsschrank."
	if supplies.cargo_kind != item.kind:
		return "Hole zuerst Futter am Vorratsschrank." if item.kind == "food" \
			else "Hole zuerst Wasser am Hahn."
	var amount := mini(missing, supplies.cargo_amount)
	item.stock += amount
	supplies.cargo_amount -= amount
	if supplies.cargo_amount == 0:
		supplies.clear_cargo()
	return ""

func collect_delivery(order_id: int = 0) -> String:
	var error := free_hands_error()
	if not error.is_empty():
		return error
	var ready: SupplyOrder
	for order in supplies.orders:
		if order.remaining <= 0.0 and (order_id == 0 or order.id == order_id):
			ready = order
			break
	if ready == null:
		return "Dieses Paket ist noch nicht da oder wurde schon abgeholt."
	supplies.cargo_kind = "package"
	supplies.cargo_amount = ready.units
	supplies.orders.erase(ready)
	return ""

func available_food() -> int:
	var amount := supplies.food_stock
	if supplies.cargo_kind in ["food", "package"]:
		amount += supplies.cargo_amount
	for item in home.items:
		if item.kind == "food":
			amount += item.stock
	for order in supplies.orders:
		if order.remaining <= 0.0:
			amount += order.units
	return amount

