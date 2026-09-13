## Baut die Nachbarschaft fuer ein Rettungs-Level auf.
##
## Der Aufbau ist bewusst prozedural: so entsteht bei jedem Ausflug ein etwas
## anderes Viertel, ohne dass riesige Kacheldaten in der Szenendatei liegen.
##
## Aufbau:
##   * Grundflaeche aus Gras
##   * senkrechte Strassen (die Fahrzeug-Sprites sind Frontansichten)
##   * Buergersteige laengs der Strassen
##   * Haeuserbloecke dazwischen
##   * Baeume auf den Restflaechen
class_name LevelGenerator
extends RefCounted

const TILE_SIZE := 16

## Abstand zwischen zwei Strassenmitten in Kacheln.
const BLOCK_WIDTH := 22

## Fahrbahnbreite in Kacheln.
const ROAD_WIDTH := 4

## Breite des Buergersteigs auf jeder Strassenseite.
const SIDEWALK_WIDTH := 1

## Schmaler darf ein Haeuserblock nicht sein, sonst wird er uebersprungen.
const MIN_BLOCK_DEPTH := 4

var width: int
var height: int
var rng: RandomNumberGenerator

## x-Kachelspalten, auf denen die Strassenmitte liegt.
var road_centers: Array[int] = []

## Alle Kacheln, auf denen etwas stehen darf (Gras/Buergersteig, kein Aufbau).
var walkable: Array[Vector2i] = []

## Kacheln auf der Fahrbahn -- dort laufen die Autos.
var road_tiles: Array[Vector2i] = []

## Mittelpunkt der Heimzone. Rund um sie herum wird nicht gebaut.
var home_cell: Vector2i = Vector2i.ZERO

## Halbe Kantenlaenge der freigehaltenen Flaeche um die Heimzone.
const HOME_CLEARANCE := 3

const SHOP_SIZE := Vector2i(7, 7)

## Bedienpunkt vor der Theke, offene Eingangskachel und Gebaeudegrundriss.
var shop_cell: Vector2i = Vector2i.ZERO
var shop_entry: Vector2i = Vector2i.ZERO
var shop_area: Rect2i = Rect2i()
var shop_counter: Rect2i = Rect2i()

var _blocked: Dictionary = {}
var _reserved: Dictionary = {}
var _spawn_cells: Array[Vector2i] = []


func _init(map_width: int = 60, map_height: int = 44, seed_value: int = 0) -> void:
	width = map_width
	height = map_height
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


## Erzeugt das Viertel in den beiden uebergebenen Ebenen.
func generate(ground: TileMapLayer, objects: TileMapLayer) -> void:
	ground.clear()
	objects.clear()
	walkable.clear()
	road_tiles.clear()
	road_centers.clear()
	_blocked.clear()
	_reserved.clear()
	_spawn_cells.clear()

	_fill_grass(ground)
	_carve_roads(ground)
	_reserve_home_area(ground)
	_reserve_shop_area(ground)
	_draw_shop(ground, objects)
	_place_buildings(ground, objects)
	_scatter_trees(objects)
	_collect_walkable()


## Sucht einen freien Platz fuer das Zuhause und haelt ihn von Bebauung frei.
func _reserve_home_area(ground: TileMapLayer) -> void:
	# Links der ersten Strasse, auf halber Hoehe -- gut erreichbar und
	# weit genug von den Fahrbahnen entfernt.
	var x := HOME_CLEARANCE + 1
	if not road_centers.is_empty():
		x = mini(x, road_centers[0] - ROAD_WIDTH / 2 - SIDEWALK_WIDTH - HOME_CLEARANCE - 1)
	home_cell = Vector2i(maxi(x, HOME_CLEARANCE + 1), height / 2)

	for dy in range(-HOME_CLEARANCE, HOME_CLEARANCE + 1):
		for dx in range(-HOME_CLEARANCE, HOME_CLEARANCE + 1):
			var cell := home_cell + Vector2i(dx, dy)
			if not _in_bounds(cell):
				continue
			_reserved[cell] = true
			# Ein gepflasterter Vorplatz macht die Zone auch optisch erkennbar.
			ground.set_cell(cell, UrbanTiles.SOURCE, UrbanTiles.CONCRETE)


func _reserve_shop_area(ground: TileMapLayer) -> void:
	# Derselbe Buergersteig wie das Zuhause, aber im noerdlichen Abschnitt.
	# Die kleinste vorgesehene Karte (22 x 24) laesst die ganze Heimzone frei.
	shop_area = Rect2i(Vector2i(home_cell.x - 3, 2), SHOP_SIZE)
	shop_entry = Vector2i(home_cell.x, shop_area.end.y - 1)
	shop_counter = Rect2i(shop_area.position + Vector2i(1, 1), Vector2i(5, 1))
	shop_cell = Vector2i(home_cell.x, shop_counter.end.y)
	for y in range(shop_area.position.y - 1, shop_area.end.y + 1):
		for x in range(shop_area.position.x - 1, shop_area.end.x + 1):
			_reserve_path_cell(ground, Vector2i(x, y))

	# Drei Kacheln breit: auch mit der echten Spielerform bleibt der Weg frei.
	for y in range(shop_entry.y + 1, home_cell.y + 1):
		for x in range(home_cell.x - 1, home_cell.x + 2):
			_reserve_path_cell(ground, Vector2i(x, y))
	if not road_centers.is_empty():
		var sidewalk_x: int = road_centers[0] - ROAD_WIDTH / 2 - SIDEWALK_WIDTH
		for y in range(shop_entry.y + 1, shop_entry.y + 3):
			for x in range(home_cell.x - 1, sidewalk_x + 1):
				_reserve_path_cell(ground, Vector2i(x, y))


func _reserve_path_cell(ground: TileMapLayer, cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	_reserved[cell] = true
	ground.set_cell(cell, UrbanTiles.SOURCE, UrbanTiles.CONCRETE)


func _draw_shop(ground: TileMapLayer, objects: TileMapLayer) -> void:
	for y in range(shop_area.position.y, shop_area.end.y):
		for x in range(shop_area.position.x, shop_area.end.x):
			var cell := Vector2i(x, y)
			ground.set_cell(cell, UrbanTiles.SOURCE, UrbanTiles.PAVEMENT)
			var top: bool = y == shop_area.position.y
			var side: bool = x == shop_area.position.x or x == shop_area.end.x - 1
			var front: bool = y == shop_entry.y and absi(x - shop_entry.x) > 1
			if not top and not side and not front and not shop_counter.has_point(cell):
				continue
			var column: int = -1 if x == shop_area.position.x else (
				1 if x == shop_area.end.x - 1 else 0)
			var row: int = -1 if top else (1 if front or shop_counter.has_point(cell) else 0)
			objects.set_cell(cell, UrbanTiles.SOURCE,
				UrbanTiles.facade_tile(UrbanTiles.FACADE_ORANGE, column, row))
			_blocked[cell] = true


func _fill_grass(ground: TileMapLayer) -> void:
	for y in height:
		for x in width:
			var tile: Vector2i = UrbanTiles.GRASS
			if rng.randf() < 0.12:
				tile = UrbanTiles.GRASS_VARIANTS[rng.randi() % UrbanTiles.GRASS_VARIANTS.size()]
			ground.set_cell(Vector2i(x, y), UrbanTiles.SOURCE, tile)


func _carve_roads(ground: TileMapLayer) -> void:
	var x := BLOCK_WIDTH / 2
	while x < width - 2:
		road_centers.append(x)
		var road_start := x - ROAD_WIDTH / 2
		var road_end := road_start + ROAD_WIDTH - 1

		for y in height:
			# Buergersteig links und rechts der Fahrbahn
			for offset in SIDEWALK_WIDTH:
				_set_ground(ground, road_start - 1 - offset, y, UrbanTiles.PAVEMENT)
				_set_ground(ground, road_end + 1 + offset, y, UrbanTiles.PAVEMENT)

			for lane_x in range(road_start, road_end + 1):
				_set_ground(ground, lane_x, y, UrbanTiles.ASPHALT)
				road_tiles.append(Vector2i(lane_x, y))

			# Mittellinie gestrichelt
			if y % 3 != 0:
				_set_ground(ground, road_start + ROAD_WIDTH / 2 - 1, y, UrbanTiles.ROAD_LINE)

		# Zebrastreifen quer ueber die Fahrbahn
		var crossings := maxi(height / 14, 1)
		for i in crossings:
			var cy := int(float(height) * (float(i) + 0.5) / float(crossings))
			for lane_x in range(road_start, road_end + 1):
				_set_ground(ground, lane_x, cy, UrbanTiles.CROSSWALK)

		x += BLOCK_WIDTH


func _place_buildings(ground: TileMapLayer, objects: TileMapLayer) -> void:
	if road_centers.is_empty():
		return

	# Zwischen je zwei Strassen entsteht ein Block mit mehreren Haeusern.
	# Links der ersten und rechts der letzten Strasse wird ebenfalls gebaut,
	# damit die Karte an den Raendern nicht kahl wirkt.
	var lanes: Array[int] = []
	lanes.append(road_centers[0] - BLOCK_WIDTH)
	lanes.append_array(road_centers)
	lanes.append(road_centers[road_centers.size() - 1] + BLOCK_WIDTH)

	var margin := ROAD_WIDTH / 2 + SIDEWALK_WIDTH + 1

	for i in range(lanes.size() - 1):
		var left := maxi(lanes[i] + margin, 1)
		var right := mini(lanes[i + 1] - margin, width - 2)
		var depth := right - left + 1
		if depth < MIN_BLOCK_DEPTH:
			continue

		var y := 2
		while y < height - 7:
			var house_w := rng.randi_range(MIN_BLOCK_DEPTH, mini(8, depth))
			var house_h := rng.randi_range(3, 5)
			var house_x := rng.randi_range(left, maxi(left, right - house_w + 1))
			_draw_house(ground, objects, house_x, y, house_w, house_h)
			y += house_h + rng.randi_range(3, 5)


## Zeichnet ein einzelnes Haus samt Vorplatz. Reservierte Flaechen (etwa die
## Heimzone) bleiben frei -- passt das Haus dort nicht hin, entfaellt es.
func _draw_house(ground: TileMapLayer, objects: TileMapLayer, house_x: int, house_y: int,
		house_w: int, house_h: int) -> void:
	for by in range(-1, house_h + 1):
		for bx in range(-1, house_w + 1):
			if _reserved.has(Vector2i(house_x + bx, house_y + by)):
				return

	var variant: Dictionary = UrbanTiles.FACADE_VARIANTS[rng.randi() % UrbanTiles.FACADE_VARIANTS.size()]

	for by in house_h:
		# -1 = Dachkante, 0 = Koerper, 1 = Sockelleiste
		var row_kind := 0
		if by == 0:
			row_kind = -1
		elif by == house_h - 1:
			row_kind = 1

		for bx in house_w:
			var column_kind := 0
			if bx == 0:
				column_kind = -1
			elif bx == house_w - 1:
				column_kind = 1

			var cell := Vector2i(house_x + bx, house_y + by)
			if not _in_bounds(cell):
				continue
			objects.set_cell(cell, UrbanTiles.SOURCE, UrbanTiles.facade_tile(variant, column_kind, row_kind))
			_blocked[cell] = true

	# Vorplatz aus Beton, damit die Haeuser nicht im Gras schweben.
	for bx in range(house_x - 1, house_x + house_w + 1):
		_set_ground(ground, bx, house_y + house_h, UrbanTiles.CONCRETE)


func _scatter_trees(objects: TileMapLayer) -> void:
	var attempts := int(float(width * height) * 0.04)
	for i in attempts:
		var cell := Vector2i(rng.randi_range(1, width - 2), rng.randi_range(1, height - 2))
		if _blocked.has(cell) or _reserved.has(cell) or _is_road(cell):
			continue
		# Nicht direkt neben der Fahrbahn pflanzen, sonst sieht man nichts.
		if _is_road(cell + Vector2i.LEFT) or _is_road(cell + Vector2i.RIGHT):
			continue
		var tree: Vector2i = UrbanTiles.TREE_VARIANTS[rng.randi() % UrbanTiles.TREE_VARIANTS.size()]
		objects.set_cell(cell, UrbanTiles.SOURCE, tree)
		_blocked[cell] = true


func _collect_walkable() -> void:
	var road_lookup: Dictionary = {}
	for cell in road_tiles:
		road_lookup[cell] = true
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _blocked.has(cell) or road_lookup.has(cell):
				continue
			walkable.append(cell)
			if not _reserved.has(cell):
				_spawn_cells.append(cell)


func _set_ground(ground: TileMapLayer, x: int, y: int, tile: Vector2i) -> void:
	var cell := Vector2i(x, y)
	if not _in_bounds(cell):
		return
	ground.set_cell(cell, UrbanTiles.SOURCE, tile)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _is_road(cell: Vector2i) -> bool:
	for center in road_centers:
		if absi(cell.x - center) <= ROAD_WIDTH / 2:
			return true
	return false


## Ob auf dieser Kachel etwas Festes steht (Haus, Laden oder Baum), das den Weg
## versperrt. Genutzt von der Wegfindung des Spieltests.
func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## Freie Laufwege bleiben begehbar, sind aber keine zufaelligen Spawnplaetze.
func is_spawn_reserved(cell: Vector2i) -> bool:
	return _reserved.has(cell)


# --- Hilfen fuer die Level-Szene ---------------------------------------------

## Mittelpunkt einer Kachel in Weltkoordinaten.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


static func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / float(TILE_SIZE)), floori(position.y / float(TILE_SIZE)))


## Gesamtgroesse der Karte in Pixeln.
func world_size() -> Vector2:
	return Vector2(width, height) * float(TILE_SIZE)


## Liefert eine zufaellige begehbare Kachel mit Mindestabstand zu `away_from`.
func random_walkable(away_from: Vector2 = Vector2.INF, min_distance: float = 0.0) -> Vector2i:
	if _spawn_cells.is_empty():
		return Vector2i(width / 2, height / 2)
	for attempt in 40:
		var cell: Vector2i = _spawn_cells[rng.randi() % _spawn_cells.size()]
		if away_from == Vector2.INF:
			return cell
		if cell_to_world(cell).distance_to(away_from) >= min_distance:
			return cell
	return _spawn_cells[rng.randi() % _spawn_cells.size()]
