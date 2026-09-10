class_name HomeLayout
extends RefCounted

const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var data: HomeData
var _astar := AStarGrid2D.new()

func _init(home: HomeData) -> void:
	data = home
	rebuild()

func rebuild() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, HomeCatalog.ROOM_SIZE)
	_astar.cell_size = Vector2.ONE * HomeCatalog.TILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in HomeCatalog.ROOM_SIZE.y:
		for x in HomeCatalog.ROOM_SIZE.x:
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, not HomeCatalog.inside(cell))
	for item in data.items:
		if item.placed:
			for cell in cells_in(item.rect()):
				if _astar.is_in_boundsv(cell):
					_astar.set_point_solid(cell, true)

static func cells_in(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result

func blocked(cell: Vector2i) -> bool:
	return not _astar.is_in_boundsv(cell) or _astar.is_point_solid(cell)

func path(from: Vector2, to: Vector2i) -> PackedVector2Array:
	var start := HomeCatalog.cell(from)
	var points := PackedVector2Array()
	if blocked(start) or blocked(to):
		return points
	for cell in _astar.get_id_path(start, to):
		points.append(HomeCatalog.world(cell))
	return points

func free_position(index: int = 0) -> Vector2:
	var cells: Array[Vector2i] = []
	for y in range(7, HomeCatalog.ROOM_SIZE.y - 3):
		for x in range(2, HomeCatalog.ROOM_SIZE.x - 2):
			var cell := Vector2i(x, y)
			if not blocked(cell):
				cells.append(cell)
	return HomeCatalog.world(cells[posmod(index * 7, cells.size())]) \
		if not cells.is_empty() else HomeCatalog.world(HomeCatalog.ENTRY)

func placement_error(item_id: String, cell: Vector2i, turns: int,
		occupants: Array[Vector2]) -> String:
	var original := data.item_by_id(item_id)
	if original == null:
		return "Dieser Gegenstand ist nicht im Inventar."
	var candidate := HomeItemData.from_dict(original.to_dict())
	candidate.cell = cell
	candidate.turns = posmod(turns, 4)
	candidate.placed = true
	var proposed: Array[HomeItemData] = []
	for item in data.items:
		proposed.append(candidate if item.id == item_id else item)
	var error := inspect(proposed)
	if not error.is_empty():
		return error
	var bounds := Rect2(Vector2(cell * HomeCatalog.TILE),
		Vector2(candidate.rect().size * HomeCatalog.TILE)).grow(7.0)
	for point in occupants:
		if bounds.has_point(point):
			return "Hier steht gerade eine Katze oder die Spielfigur."
	return ""

func inspect(items: Array[HomeItemData]) -> String:
	var occupied := {}
	for item in items:
		if not item.placed:
			continue
		if item.rect().intersects(HomeCatalog.ENTRANCE_CLEARANCE):
			return "Der Zugang zur Haustür muss frei bleiben."
		for cell in cells_in(item.rect()):
			if not HomeCatalog.inside(cell):
				return "Bitte innerhalb des Hauses platzieren."
			if occupied.has(cell):
				return "Hier steht schon ein Gegenstand."
			occupied[cell] = true
	var reachable := {HomeCatalog.ENTRY: true}
	var pending: Array[Vector2i] = [HomeCatalog.ENTRY]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for offset in NEIGHBORS:
			var next := current + offset
			if HomeCatalog.inside(next) and not occupied.has(next) and not reachable.has(next):
				reachable[next] = true
				pending.append(next)
	for item in items:
		if item.placed and not reachable.has(item.port()):
			return "Die Bedienseite von „%s“ ist nicht erreichbar." % HomeCatalog.title(item.kind)
	var interior_count := (HomeCatalog.ROOM_SIZE.x - 2) * (HomeCatalog.ROOM_SIZE.y - 2)
	if reachable.size() != interior_count - occupied.size():
		return "Das würde einen Teil des Raums einschließen."
	return ""

func save_error() -> String:
	var error := inspect(data.items)
	if not error.is_empty():
		return error
	if blocked(HomeCatalog.cell(data.player_position)):
		return "Ungültige Spielerposition im Hausspielstand."
	for id: String in data.cats:
		var state: HomeCatState = data.cats[id]
		if blocked(HomeCatalog.cell(state.position)):
			return "Ungültige Katzenposition im Hausspielstand."
	return ""
