## Entwicklungshilfe: fuellt den Spielstand mit Beispieldaten.
##
## Wird ueber `--demo` eingeschaltet und dient dazu, das Zuhause und die
## Pflegekarten ohne vorheriges Spielen ansehen und testen zu koennen.
extends Node

const PRESETS: Array[Dictionary] = [
	{"name": "Mimi", "fur": 0, "hunger": 22.0, "thirst": 15.0, "clean": 8.0, "health": 40.0},
	{"name": "Balu", "fur": 1, "hunger": 84.0, "thirst": 90.0, "clean": 72.0, "health": 66.0},
	{"name": "Momo", "fur": 2, "hunger": 95.0, "thirst": 92.0, "clean": 88.0, "health": 91.0},
	{"name": "Keks", "fur": 3, "hunger": 48.0, "thirst": 55.0, "clean": 30.0, "health": 52.0},
]


func _ready() -> void:
	populate()
	queue_free()


## Legt eine Handvoll Katzen in unterschiedlichen Zustaenden zu Hause ab.
static func populate() -> void:
	GameState.reset()
	GameState.add_coins(180)

	for preset in PRESETS:
		var cat := CatData.create_random()
		cat.cat_name = String(preset["name"])
		cat.fur_variant = int(preset["fur"])
		cat.hunger = float(preset["hunger"])
		cat.thirst = float(preset["thirst"])
		cat.cleanliness = float(preset["clean"])
		cat.health = float(preset["health"])
		cat.state = CatData.State.AT_HOME
		GameState.home_cats.append(cat)

	GameState.rescued_total = PRESETS.size()
	GameState.home_cats_changed.emit()
