## Die Rettungs-Phase: ein prozedural erzeugtes Viertel voller Streunerkatzen.
##
## Es gibt kein Zeitlimit. Man sucht in Ruhe, naehert sich vorsichtig, hebt die
## Katzen auf und bringt sie zur Heimzone. Autos und Hunde koennen einem eine
## getragene Katze wieder entwischen lassen -- mehr passiert nicht.
extends Node2D

const CAT_SCENE := preload("res://scenes/rescue/cat.tscn")
const CAR_SCENE := preload("res://scenes/rescue/hazards/car.tscn")
const DOG_SCENE := preload("res://scenes/rescue/hazards/dog.tscn")

const MAP_WIDTH := 60
const MAP_HEIGHT := 44

const CAT_COUNT := 7
const CARS_PER_ROAD := 3
const DOG_COUNT := 3

@onready var _ground: TileMapLayer = $Ground
@onready var _objects: TileMapLayer = $Objects
@onready var _player: Player = $Player
@onready var _entities: Node2D = $Entities
@onready var _home_zone: Area2D = $HomeZone
@onready var _camera: Camera2D = $Player/Camera
@onready var _hud: Control = $UI/HUD
@onready var _touch_controls: CanvasLayer = $TouchControls

var _generator: LevelGenerator
var _home_cell: Vector2i


func _ready() -> void:
	GameState.simulation_active = true
	add_to_group("rescue_level")

	_generator = LevelGenerator.new(MAP_WIDTH, MAP_HEIGHT)
	_generator.generate(_ground, _objects)

	_setup_home_zone()
	_place_player()
	_setup_camera()
	_spawn_cats()
	_spawn_cars()
	_spawn_dogs()

	_home_zone.body_entered.connect(_on_home_zone_entered)
	# Der Touch-Aktionsknopf setzt nur den Aktionszustand, erzeugt aber kein
	# Eingabeereignis -- deshalb hier zusaetzlich direkt verbinden.
	_touch_controls.connect("action_pressed", _try_pick_up)
	_hud.call("set_hint", "Geh zu einer Katze und warte kurz – nur Rennen verschreckt sie.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_pick_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_hud.call("toggle_pause")
		get_viewport().set_input_as_handled()


## Wird auch vom Aktionsknopf der Touch-Steuerung aufgerufen.
func _try_pick_up() -> void:
	var reachable := _player.cats_in_reach()
	if reachable.is_empty():
		return
	if not GameState.can_carry_more():
		_hud.call("set_hint", "Dein Tragekorb ist voll – bring sie erst nach Hause.")
		return
	reachable[0].pick_up()


# --- Aufbau ------------------------------------------------------------------

func _setup_home_zone() -> void:
	# Der Generator haelt rund um diese Kachel eine freie Flaeche vor.
	_home_cell = _generator.home_cell
	_home_zone.position = LevelGenerator.cell_to_world(_home_cell)


func _place_player() -> void:
	_player.global_position = LevelGenerator.cell_to_world(_home_cell + Vector2i(0, 2))


func _setup_camera() -> void:
	var world := _generator.world_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(world.x)
	_camera.limit_bottom = int(world.y)


func _spawn_cats() -> void:
	var home_world := LevelGenerator.cell_to_world(_home_cell)
	var bounds := Rect2(Vector2(8, 8), _generator.world_size() - Vector2(16, 16))

	for i in CAT_COUNT:
		var cell := _generator.random_walkable(home_world, 140.0)
		var cat: Cat = CAT_SCENE.instantiate()
		cat.data = CatData.create_random()
		cat.position = LevelGenerator.cell_to_world(cell)
		_entities.add_child(cat)
		cat.set_player(_player)
		cat.set_bounds(bounds)


func _spawn_cars() -> void:
	var world := _generator.world_size()
	for center in _generator.road_centers:
		for i in CARS_PER_ROAD:
			var car: Car = CAR_SCENE.instantiate()
			# Je Fahrbahnhaelfte eine Fahrtrichtung, wie im echten Verkehr.
			var down := i % 2 == 0
			var lane_offset := -1 if down else 1
			car.driving_down = down
			car.travel_min = -32.0
			car.travel_max = world.y + 32.0
			car.position = Vector2(
				float(center) * LevelGenerator.TILE_SIZE + 8.0 + float(lane_offset) * 9.0,
				randf_range(0.0, world.y))
			_entities.add_child(car)


func _spawn_dogs() -> void:
	var home_world := LevelGenerator.cell_to_world(_home_cell)
	for i in DOG_COUNT:
		var cell := _generator.random_walkable(home_world, 200.0)
		var dog: Dog = DOG_SCENE.instantiate()
		dog.position = LevelGenerator.cell_to_world(cell)
		_entities.add_child(dog)


# --- Ereignisse --------------------------------------------------------------

func _on_home_zone_entered(body: Node2D) -> void:
	if body is not Player:
		return
	var delivered := GameState.deliver_carried_cats()
	if delivered <= 0:
		return
	AudioManager.play_sfx("deliver")
	_hud.call("set_hint", "%d Katze(n) sicher zu Hause!" % delivered)
	SaveManager.save_game()


## Eine getragene Katze ist entwischt und streunt wieder im Level.
##
## Aufrufer sind Auto und Hund, also Kollisionsrueckrufe. Waehrend Godot die
## Physikabfragen abarbeitet, darf kein Koerper in den Raum eingehaengt werden
## ("Can't change this state while flushing queries") -- das Aussetzen wartet
## deshalb bis zum Ende des Physikschritts.
func on_cat_escaped(data: CatData, origin: Vector2) -> void:
	_spawn_escaped_cat.call_deferred(data, origin)
	_hud.call("set_hint", "Oje, %s ist erschrocken und weggelaufen!" % data.cat_name)


func _spawn_escaped_cat(data: CatData, origin: Vector2) -> void:
	var cat: Cat = CAT_SCENE.instantiate()
	cat.data = data
	cat.position = origin + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	_entities.add_child(cat)
	cat.set_player(_player)
	cat.set_bounds(Rect2(Vector2(8, 8), _generator.world_size() - Vector2(16, 16)))
	cat.scatter_from(origin)


## Wird vom HUD-Knopf „Nach Hause“ genutzt.
func return_home() -> void:
	SaveManager.save_game()
	SceneRouter.goto_home()
