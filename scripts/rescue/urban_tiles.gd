## Kachel-Koordinaten im Kenney RPG Urban Pack (27 x 18 Kacheln a 16 px).
##
## Die Namen halten den Level-Generator lesbar -- sonst stuenden dort ueberall
## nur nackte Vector2i-Zahlenpaare.
class_name UrbanTiles
extends RefCounted

## Quelle 0 des Tilesets (es gibt nur diese eine).
const SOURCE := 0

# --- Boden ---
## Reines Gras (Mitte der grossen Grasflaeche im Atlas).
const GRASS := Vector2i(1, 1)
const GRASS_ALT := Vector2i(5, 0)
## Heller Steinbelag -- dient als Buergersteig.
const PAVEMENT := Vector2i(9, 1)
## Blaugrauer Belag fuer Vorplaetze vor den Haeusern.
const CONCRETE := Vector2i(9, 4)
const ASPHALT := Vector2i(8, 17)
const ASPHALT_ALT := Vector2i(9, 17)
const ROAD_LINE := Vector2i(1, 16)
const CROSSWALK := Vector2i(3, 16)
const WATER := Vector2i(9, 7)

# --- Aufbauten (mit Kollision) ---

## Hausfassaden bestehen aus drei Spalten (links, Mitte, rechts) und drei
## Zeilentypen (oben mit Dachkante, Koerper, unten mit Sockelleiste).
## Es gibt eine rote und eine orange Variante.
const FACADE_COLUMN_LEFT := 17
const FACADE_COLUMN_MIDDLE := 18
const FACADE_COLUMN_RIGHT := 19

const FACADE_RED := { "top": 0, "body": 2, "bottom": 3 }
const FACADE_ORANGE := { "top": 4, "body": 6, "bottom": 7 }

const FACADE_VARIANTS: Array[Dictionary] = [FACADE_RED, FACADE_ORANGE]

const TREE_GREEN := Vector2i(17, 10)
const TREE_ORANGE := Vector2i(17, 13)

## Fuer zufaellige Auswahl.
const GRASS_VARIANTS: Array[Vector2i] = [GRASS, GRASS_ALT]
const TREE_VARIANTS: Array[Vector2i] = [TREE_GREEN, TREE_ORANGE]


## Liefert die Fassadenkachel fuer eine Position innerhalb eines Hauses.
##
## `column_kind` und `row_kind` sind jeweils -1 (links/oben), 0 (Mitte/Koerper)
## oder 1 (rechts/unten).
static func facade_tile(variant: Dictionary, column_kind: int, row_kind: int) -> Vector2i:
	var column := FACADE_COLUMN_MIDDLE
	if column_kind < 0:
		column = FACADE_COLUMN_LEFT
	elif column_kind > 0:
		column = FACADE_COLUMN_RIGHT

	var row := int(variant["body"])
	if row_kind < 0:
		row = int(variant["top"])
	elif row_kind > 0:
		row = int(variant["bottom"])

	return Vector2i(column, row)

# --- Ausschnitte im Spritesheet fuer Sprites (nicht fuer die Tilemap) ---

## Der Spieler nutzt die erste Figurenreihe: Spalten 23..26 sind die
## Blickrichtungen links, unten, oben, rechts; Zeilen 0..2 sind Ruhe- und
## zwei Laufbilder.
const CHARACTER_COLUMNS := {
	"left": 23,
	"down": 24,
	"up": 25,
	"right": 26,
}
const CHARACTER_ROW_IDLE := 0
const CHARACTER_ROW_WALK_A := 1
const CHARACTER_ROW_WALK_B := 2

## Autos stehen ausserhalb des Kachelrasters, deshalb exakte Pixelrechtecke.
## Fuer senkrechte Strassen Front und Heck statt der breiten Seitenansichten.
const CAR_REGIONS_DOWN: Array[Rect2i] = [
	Rect2i(272, 235, 16, 21),  # orange, Frontansicht
	Rect2i(272, 267, 16, 21),  # rot, Frontansicht
]
const CAR_REGIONS_UP: Array[Rect2i] = [
	Rect2i(320, 235, 16, 21),  # orange, Heckansicht
	Rect2i(320, 267, 16, 21),  # rot, Heckansicht
]


## Rechteck eines Charakter-Einzelbildes im Spritesheet.
static func character_region(direction: String, row: int) -> Rect2i:
	var column: int = CHARACTER_COLUMNS.get(direction, CHARACTER_COLUMNS["down"])
	return Rect2i(column * 16, row * 16, 16, 16)
