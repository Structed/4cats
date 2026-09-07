## Datensatz einer einzelnen Katze.
##
## Haelt sowohl die Werte fuer die Rettungs-Phase (Scheu, Fellfarbe) als auch
## die vier Pflege-Beduerfnisse fuer die Heim-Phase.
class_name CatData
extends Resource

enum State {
	WILD,     ## Streunt noch im Level herum
	CARRIED,  ## Wird gerade getragen
	AT_HOME,  ## Liegt zu Hause im Koerbchen und wird gepflegt
	ADOPTED,  ## Genesen und vermittelt
}

## Beduerfnisse laufen immer von 0 (ganz schlecht) bis 100 (bestens).
const NEED_MAX := 100.0

## Ab diesem Wert gilt ein Beduerfnis als erfuellt.
const RECOVERY_THRESHOLD := 80.0

## So lange muessen *alle* vier Werte oben bleiben, bis die Katze genesen ist.
const RECOVERY_SECONDS := 30.0

## Anzahl der verfuegbaren Fellvarianten.
const FUR_VARIANTS := 4

const NAMES: PackedStringArray = [
	"Mimi", "Schnurrli", "Pfoetchen", "Luna", "Mausi", "Balu", "Kiwi", "Nala",
	"Socke", "Momo", "Fussel", "Tiger", "Wolke", "Keks", "Minka", "Rocky",
	"Struppi", "Emma", "Paul", "Zimt", "Hexe", "Bommel", "Nelli", "Oskar",
]

@export var id: String = ""
@export var cat_name: String = ""
@export_range(0, FUR_VARIANTS - 1) var fur_variant: int = 0
@export var state: State = State.WILD

## 0.0 = laeuft dir direkt zu, 1.0 = sehr schreckhaft.
@export_range(0.0, 1.0) var shyness: float = 0.5

@export_range(0.0, NEED_MAX) var hunger: float = 50.0
@export_range(0.0, NEED_MAX) var thirst: float = 50.0
@export_range(0.0, NEED_MAX) var cleanliness: float = 50.0
@export_range(0.0, NEED_MAX) var health: float = 50.0

## Wie lange alle Beduerfnisse schon ueber der Schwelle liegen.
@export var recovery_timer: float = 0.0


## Erzeugt eine zufaellige Streunerkatze in schlechtem Zustand.
static func create_random() -> CatData:
	var cat := CatData.new()
	cat.id = "cat_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
	cat.cat_name = NAMES[randi() % NAMES.size()]
	cat.fur_variant = randi() % FUR_VARIANTS
	cat.shyness = randf_range(0.15, 0.95)
	cat.state = State.WILD
	# Streuner sind hungrig, durstig und verdreckt -- aber nie voellig am Ende.
	cat.hunger = randf_range(10.0, 40.0)
	cat.thirst = randf_range(10.0, 40.0)
	cat.cleanliness = randf_range(5.0, 30.0)
	cat.health = randf_range(25.0, 55.0)
	cat.recovery_timer = 0.0
	return cat


## Alle vier Beduerfnisse als Dictionary -- praktisch fuer UI-Schleifen.
func needs() -> Dictionary:
	return {
		"hunger": hunger,
		"thirst": thirst,
		"cleanliness": cleanliness,
		"health": health,
	}


## Durchschnitt der vier Werte, z.B. fuer eine Gesamtanzeige.
func wellbeing() -> float:
	return (hunger + thirst + cleanliness + health) * 0.25


## Liegen alle vier Werte ueber der Genesungsschwelle?
func all_needs_met() -> bool:
	return hunger >= RECOVERY_THRESHOLD \
		and thirst >= RECOVERY_THRESHOLD \
		and cleanliness >= RECOVERY_THRESHOLD \
		and health >= RECOVERY_THRESHOLD


## Fortschritt Richtung Adoption, 0.0 bis 1.0.
func recovery_progress() -> float:
	return clampf(recovery_timer / RECOVERY_SECONDS, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"cat_name": cat_name,
		"fur_variant": fur_variant,
		"state": int(state),
		"shyness": shyness,
		"hunger": hunger,
		"thirst": thirst,
		"cleanliness": cleanliness,
		"health": health,
		"recovery_timer": recovery_timer,
	}


static func from_dict(data: Dictionary) -> CatData:
	var cat := CatData.new()
	cat.id = String(data.get("id", ""))
	cat.cat_name = String(data.get("cat_name", "Katze"))
	cat.fur_variant = clampi(int(data.get("fur_variant", 0)), 0, FUR_VARIANTS - 1)
	cat.state = int(data.get("state", State.AT_HOME)) as State
	cat.shyness = clampf(float(data.get("shyness", 0.5)), 0.0, 1.0)
	cat.hunger = clampf(float(data.get("hunger", 50.0)), 0.0, NEED_MAX)
	cat.thirst = clampf(float(data.get("thirst", 50.0)), 0.0, NEED_MAX)
	cat.cleanliness = clampf(float(data.get("cleanliness", 50.0)), 0.0, NEED_MAX)
	cat.health = clampf(float(data.get("health", 50.0)), 0.0, NEED_MAX)
	cat.recovery_timer = maxf(float(data.get("recovery_timer", 0.0)), 0.0)
	return cat
