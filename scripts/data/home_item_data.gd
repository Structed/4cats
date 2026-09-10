class_name HomeItemData
extends Resource

var id: String = ""
var kind: String = "food"
var cell: Vector2i = Vector2i.ZERO
var turns: int = 0
var placed: bool = true
var stock: int = 0
var dirt: int = 0

func rect() -> Rect2i:
	return Rect2i(cell, HomeCatalog.footprint(kind, turns))

func center() -> Vector2:
	return Vector2(cell * HomeCatalog.TILE) + Vector2(rect().size) * (HomeCatalog.TILE / 2.0)

func port() -> Vector2i:
	var size := rect().size
	match turns:
		1: return cell + Vector2i(-1, size.y / 2)
		2: return cell + Vector2i(size.x / 2, -1)
		3: return cell + Vector2i(size.x, size.y / 2)
	return cell + Vector2i(size.x / 2, size.y)

func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "cell": [cell.x, cell.y], "turns": turns,
		"placed": placed, "stock": stock, "dirt": dirt}

static func from_dict(raw: Dictionary) -> HomeItemData:
	var raw_cell: Variant = raw.get("cell")
	if raw.get("id") is not String or String(raw["id"]).is_empty() \
			or raw.get("kind") is not String or not HomeCatalog.KINDS.has(raw["kind"]):
		return null
	if raw_cell is not Array or raw_cell.size() != 2:
		return null
	for value: Variant in raw_cell:
		if not (value is float or value is int) or not is_finite(float(value)):
			return null
	for key in ["turns", "stock", "dirt"]:
		var value: Variant = raw.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return null
	if raw.get("placed") is not bool:
		return null
	var item := HomeItemData.new()
	item.id = raw["id"]
	item.kind = raw["kind"]
	item.cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	item.turns = int(raw["turns"])
	item.placed = raw["placed"]
	item.stock = int(raw["stock"])
	item.dirt = int(raw["dirt"])
	if item.turns < 0 or item.turns > 3 or item.stock < 0 or item.dirt < 0 \
			or item.stock > HomeCatalog.capacity(item.kind) \
			or item.dirt > HomeCatalog.capacity(item.kind):
		return null
	return item
