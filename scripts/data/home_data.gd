class_name HomeData
extends Resource

var items: Array[HomeItemData] = []
var cats: Dictionary = {}
var next_item: int = 1
var player_position: Vector2 = HomeCatalog.world(HomeCatalog.ENTRY - Vector2i(0, 1))

static func starter() -> HomeData:
	var home := HomeData.new()
	for i in HomeCatalog.KINDS.size():
		var item := HomeItemData.new()
		item.id = "starter_%s" % HomeCatalog.KINDS[i]
		item.kind = HomeCatalog.KINDS[i]
		item.cell = HomeCatalog.START_CELLS[i]
		home.items.append(item)
	return home

func item_by_id(id: String) -> HomeItemData:
	for item in items:
		if item.id == id:
			return item
	return null

func to_dict() -> Dictionary:
	var stored_items: Array = []
	for item in items:
		stored_items.append(item.to_dict())
	var stored_cats := {}
	for id: String in cats:
		var state: HomeCatState = cats[id]
		stored_cats[id] = state.to_dict()
	return {"items": stored_items, "cats": stored_cats, "next_item": next_item,
		"player_position": [player_position.x, player_position.y]}

static func from_dict(raw: Dictionary) -> HomeData:
	if raw.get("items") is not Array or raw.get("cats") is not Dictionary:
		return null
	var home := HomeData.new()
	var ids := {}
	for entry: Variant in raw["items"]:
		if entry is not Dictionary:
			return null
		var item := HomeItemData.from_dict(entry)
		if item == null or ids.has(item.id):
			return null
		ids[item.id] = true
		home.items.append(item)
	var raw_cats: Dictionary = raw["cats"]
	for id: String in raw_cats:
		if raw_cats[id] is not Dictionary:
			return null
		var state := HomeCatState.from_dict(raw_cats[id])
		if state == null:
			return null
		home.cats[id] = state
	var raw_next: Variant = raw.get("next_item")
	if not (raw_next is float or raw_next is int) or not is_finite(float(raw_next)):
		return null
	home.next_item = maxi(int(raw_next), 1)
	var player := HomeCatState.from_dict({
		"position": raw.get("player_position"), "toilet_elapsed": 0.0})
	if player == null:
		return null
	home.player_position = player.position
	return home
