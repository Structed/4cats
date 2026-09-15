## Deterministischer Abgleich von Ladenwegen, Spawnflaechen und Tile-Kollisionen.
extends RefCounted

const MAP_SIZES: Array[Vector2i] = [
	Vector2i(22, 24), Vector2i(44, 32), Vector2i(60, 44), Vector2i(82, 58),
]
const SEEDS: Array[int] = [11, 42, 2026, 170701, 9876543]

var _failures: PackedStringArray = []


func run(_tree: SceneTree) -> PackedStringArray:
	_failures.clear()
	print("--- Laden: Generator und Erreichbarkeit ---")
	var tileset: TileSet = load("res://resources/urban_tileset.tres")
	for size in MAP_SIZES:
		for seed_value in SEEDS:
			_test_map(size, seed_value, tileset)
	return _failures


func _test_map(size: Vector2i, seed_value: int, tileset: TileSet) -> void:
	var prefix := "%s / Seed %d: " % [size, seed_value]
	var ground := TileMapLayer.new()
	var objects := TileMapLayer.new()
	ground.tile_set = tileset
	objects.tile_set = tileset
	var generator := LevelGenerator.new(size.x, size.y, seed_value)
	generator.generate(ground, objects)
	var home_area := Rect2i(generator.home_cell - Vector2i.ONE * LevelGenerator.HOME_CLEARANCE,
		Vector2i.ONE * (LevelGenerator.HOME_CLEARANCE * 2 + 1))
	_check(Rect2i(Vector2i.ZERO, size).encloses(generator.shop_area),
		prefix + "Der Laden liegt ganz innerhalb der Karte.")
	_check(not home_area.intersects(generator.shop_area),
		prefix + "Laden und Heimfreizone überschneiden sich nicht.")
	var free_home := true
	for y in range(home_area.position.y, home_area.end.y):
		for x in range(home_area.position.x, home_area.end.x):
			var cell := Vector2i(x, y)
			if generator.is_blocked(cell) or objects.get_cell_source_id(cell) != -1 \
					or ground.get_cell_atlas_coords(cell) != UrbanTiles.CONCRETE:
				free_home = false
	_check(free_home, prefix + "Die komplette Heimzone bleibt frei und unverändert gepflastert.")

	var mismatches := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var collision: bool = _collides(ground, cell) or _collides(objects, cell)
			if collision != generator.is_blocked(cell):
				mismatches += 1
	_check(mismatches == 0, prefix + "Wegfindung und tatsächliche Tile-Kollisionen stimmen überall überein.")
	_check(generator.shop_counter.has_point(generator.shop_cell + Vector2i.UP)
		and _collides(objects, generator.shop_cell + Vector2i.UP),
		prefix + "Die sichtbare Theke hat eine feste Kollision vor dem Bedienpunkt.")
	for dx in range(-1, 2):
		var entry_cell := generator.shop_entry + Vector2i(dx, 0)
		_check(not _collides(objects, entry_cell) and not generator.is_blocked(entry_cell),
			prefix + "Der dreifach breite Eingang ist offen: %s." % entry_cell)
	var free_access := true
	for y in range(generator.shop_entry.y + 1, generator.home_cell.y + 1):
		for dx in range(-1, 2):
			var cell := Vector2i(generator.home_cell.x + dx, y)
			if generator.is_blocked(cell) or not generator.is_spawn_reserved(cell):
				free_access = false
	_check(free_access, prefix + "Der durchgehende Heimweg ist vor Bäumen, Häusern und Spawns reserviert.")

	var astar := _pathfinder(generator)
	var spawn := generator.home_cell + Vector2i(0, 2)
	_check_route(astar, spawn, generator.shop_entry, ground, objects, prefix + "Spielerstart → Eingang")
	_check_route(astar, generator.shop_entry, generator.shop_cell, ground, objects,
		prefix + "Eingang → Theke")
	_check_route(astar, generator.shop_cell, generator.home_cell, ground, objects,
		prefix + "Theke → Zuhause")
	var sidewalk := Vector2i(generator.road_centers[0] - LevelGenerator.ROAD_WIDTH / 2 - 1,
		generator.shop_entry.y + 1)
	_check_route(astar, sidewalk, generator.shop_entry, ground, objects,
		prefix + "Öffentlicher Bürgersteig → Eingang")

	var safe_spawns := true
	for sample in 256:
		var cell: Vector2i = generator.random_walkable(
			LevelGenerator.cell_to_world(generator.home_cell), 140.0)
		if generator.is_spawn_reserved(cell) or generator.is_blocked(cell) \
				or not generator.walkable.has(cell):
			safe_spawns = false
	_check(safe_spawns, prefix + "Auch die Spawn-Rückfallauswahl stellt keinen Zugang zu.")
	_check(not generator.walkable.is_empty() and not generator.road_tiles.is_empty(),
		prefix + "Normale Rettungs- und Straßenflächen bleiben vorhanden.")
	_test_repeatable(generator, ground, objects, tileset, size, seed_value, prefix)
	ground.free()
	objects.free()


func _pathfinder(generator: LevelGenerator) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, generator.width, generator.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in generator.height:
		for x in generator.width:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, generator.is_blocked(cell))
	return astar


func _check_route(astar: AStarGrid2D, from: Vector2i, to: Vector2i,
		ground: TileMapLayer, objects: TileMapLayer, description: String) -> void:
	var path: Array[Vector2i] = astar.get_id_path(from, to)
	var clear: bool = not path.is_empty() and path[0] == from and path[-1] == to
	var previous: Vector2i = from
	for cell in path:
		var step := cell - previous
		if _collides(ground, cell) or _collides(objects, cell) \
				or absi(step.x) + absi(step.y) > 1:
			clear = false
		previous = cell
	_check(clear, description + " ist ohne Diagonalen und ohne freigeschaltete Hindernisse begehbar.")


func _collides(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data: TileData = layer.get_cell_tile_data(cell)
	if data == null or not layer.collision_enabled:
		return false
	for index in layer.tile_set.get_physics_layers_count():
		if layer.tile_set.get_physics_layer_collision_layer(index) & 1 \
				and data.get_collision_polygons_count(index) > 0:
			return true
	return false


func _test_repeatable(generator: LevelGenerator, ground: TileMapLayer, objects: TileMapLayer,
		tileset: TileSet, size: Vector2i, seed_value: int, prefix: String) -> void:
	var other_ground := TileMapLayer.new()
	var other_objects := TileMapLayer.new()
	other_ground.tile_set = tileset
	other_objects.tile_set = tileset
	var other := LevelGenerator.new(size.x, size.y, seed_value)
	other.generate(other_ground, other_objects)
	var identical: bool = other.home_cell == generator.home_cell \
		and other.shop_area == generator.shop_area and other.shop_entry == generator.shop_entry \
		and other.shop_cell == generator.shop_cell
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if other_ground.get_cell_atlas_coords(cell) != ground.get_cell_atlas_coords(cell) \
					or other_objects.get_cell_atlas_coords(cell) != objects.get_cell_atlas_coords(cell):
				identical = false
	_check(identical, prefix + "Derselbe Seed liefert denselben Laden und dasselbe Viertel.")
	other_ground.free()
	other_objects.free()


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures.append(description)
		printerr("  [FEHLER] ", description)
