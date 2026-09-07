## Entwicklungshilfe: erzeugt eine Uebersicht eines Rettungs-Levels als PNG.
##
## Aufruf:
##   godot --headless --path . --script res://tools/preview_level.gd -- --out=C:/temp/level.png
##
## Das laesst sich ohne Fenster ausfuehren und zeigt sofort, ob Strassen,
## Haeuser und Freiflaechen sinnvoll verteilt sind. Die Kacheln werden dabei
## direkt aus dem Atlas gelesen, es ist also ein echtes Abbild der Karte.
extends SceneTree

const TILE := 16
const ATLAS_PATH := "res://assets/kenney/urban_tilemap.png"


func _initialize() -> void:
	var output := _argument_value("--out=")
	if output.is_empty():
		printerr("Bitte --out=<pfad.png> angeben.")
		quit(1)
		return

	var width := int(_argument_value("--width=", "60"))
	var height := int(_argument_value("--height=", "44"))

	var ground := TileMapLayer.new()
	var objects := TileMapLayer.new()
	var tileset: TileSet = load("res://resources/urban_tileset.tres")
	ground.tile_set = tileset
	objects.tile_set = tileset
	root.add_child(ground)
	root.add_child(objects)

	var generator := LevelGenerator.new(width, height)
	generator.generate(ground, objects)

	print("Karte %d x %d Kacheln" % [width, height])
	print("  Strassenmitten : %s" % str(generator.road_centers))
	print("  Fahrbahnfelder : %d" % generator.road_tiles.size())
	print("  begehbar       : %d" % generator.walkable.size())

	var atlas_image := _load_atlas()
	if atlas_image == null:
		quit(1)
		return

	var canvas := Image.create(width * TILE, height * TILE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.1, 0.1, 0.12))

	_blit_layer(canvas, ground, atlas_image, width, height)
	_blit_layer(canvas, objects, atlas_image, width, height)

	var error := canvas.save_png(output)
	if error != OK:
		printerr("Konnte Bild nicht speichern: %s" % error_string(error))
		quit(1)
		return

	print("Uebersicht gespeichert: %s" % output)
	quit(0)


func _load_atlas() -> Image:
	var texture: Texture2D = load(ATLAS_PATH)
	if texture == null:
		printerr("Atlas nicht gefunden: %s" % ATLAS_PATH)
		return null
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _blit_layer(canvas: Image, layer: TileMapLayer, atlas: Image, width: int, height: int) -> void:
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var coords := layer.get_cell_atlas_coords(cell)
			if coords == Vector2i(-1, -1):
				continue
			var source := Rect2i(coords * TILE, Vector2i(TILE, TILE))
			canvas.blend_rect(atlas, source, cell * TILE)


func _argument_value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback
