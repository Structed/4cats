class_name HomeCatalog
extends RefCounted

const TILE := 16
const ROOM_SIZE := Vector2i(30, 20)
const ENTRY := Vector2i(15, 18)
const ENTRANCE_CLEARANCE := Rect2i(14, 17, 3, 2)
const KINDS: PackedStringArray = ["food", "water", "wash", "vet", "toy", "litter", "pantry", "faucet"]
const DEFINITIONS := {
	"food": {"name": "Futternapf", "cost": 25, "size": Vector2i(2, 2), "capacity": 12},
	"water": {"name": "Wassernapf", "cost": 25, "size": Vector2i(2, 2), "capacity": 16},
	"wash": {"name": "Waschplatz", "cost": 50, "size": Vector2i(2, 2), "capacity": 0},
	"vet": {"name": "Behandlungsstation", "cost": 60, "size": Vector2i(2, 2), "capacity": 0},
	"toy": {"name": "Spielball", "cost": 20, "size": Vector2i(1, 1), "capacity": 0},
	"litter": {"name": "Katzenklo", "cost": 30, "size": Vector2i(2, 2), "capacity": 6},
	"pantry": {"name": "Vorratsschrank", "cost": 0, "size": Vector2i(2, 2), "capacity": 0},
	"faucet": {"name": "Wasserhahn", "cost": 0, "size": Vector2i(2, 2), "capacity": 0},
}
const START_CELLS: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(7, 3), Vector2i(12, 3),
	Vector2i(18, 3), Vector2i(7, 12), Vector2i(24, 3),
	Vector2i(12, 12), Vector2i(18, 12),
]

static func title(kind: String) -> String:
	return String(DEFINITIONS[kind]["name"])

static func price(kind: String) -> int:
	return int(DEFINITIONS[kind]["cost"])

static func capacity(kind: String) -> int:
	return int(DEFINITIONS[kind]["capacity"])

static func footprint(kind: String, turns: int = 0) -> Vector2i:
	var size: Vector2i = DEFINITIONS[kind]["size"]
	return Vector2i(size.y, size.x) if turns % 2 else size

static func world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2.ONE * (TILE / 2.0)

static func cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

static func inside(cell_position: Vector2i) -> bool:
	return Rect2i(Vector2i.ONE, ROOM_SIZE - Vector2i(2, 2)).has_point(cell_position)

## Pflichtmoebel, die noch nicht im Raum stehen.
static func missing_fixtures() -> PackedStringArray:
	var missing: PackedStringArray = []
	for kind in SupplyCatalog.FIXTURES:
		var placed := false
		for item in GameState.home.items:
			if item.kind == kind and item.placed:
				placed = true
				break
		if not placed:
			missing.append(title(kind))
	return missing

## Hinweis auf fehlende Pflichtmoebel, oder "" wenn der Raum vollstaendig ist.
static func fixture_hint() -> String:
	var missing: PackedStringArray = missing_fixtures()
	if missing.is_empty():
		return ""
	return "%s fehlt im Raum. Unter „Einrichten“ kostenlos aufstellen." % " / ".join(missing)
