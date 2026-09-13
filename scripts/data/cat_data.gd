## Datensatz einer einzelnen Katze.
##
## Haelt sowohl die Werte fuer die Rettungs-Phase (Scheu, Fellfarbe) als auch
## die fuenf Pflege-Beduerfnisse fuer die Heim-Phase.
class_name CatData
extends Resource

enum State {
	WILD,     ## Streunt noch im Level herum
	CARRIED,  ## Wird gerade getragen
	AT_HOME,  ## Lebt und wird zu Hause gepflegt
	ADOPTED,  ## Genesen und vermittelt
	DEAD,     ## Durch Vernachlaessigung gestorben
}

enum Age { YOUNG, ADULT, SENIOR }
const AGE_NAMES: PackedStringArray = ["Jungtier", "Erwachsen", "Senior"]
const NUMERIC_DEFAULTS := {
	"shyness": 0.5, "hunger": 50.0, "thirst": 50.0, "cleanliness": 50.0,
	"health": 50.0, "enrichment": 100.0, "recovery_timer": 0.0,
}

## Beduerfnisse laufen immer von 0 (ganz schlecht) bis 100 (bestens).
const NEED_MAX := 100.0

## Ab diesem Wert gilt ein Beduerfnis als erfuellt.
const RECOVERY_THRESHOLD := 80.0

## Benoetigter Genesungsfortschritt in Sekunden ohne Tierarzt-Ausbau.
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
@export var age_group: Age = Age.ADULT
@export var critical_elapsed: float = 0.0

## 0.0 = laeuft dir direkt zu, 1.0 = sehr schreckhaft.
@export_range(0.0, 1.0) var shyness: float = 0.5

@export_range(0.0, NEED_MAX) var hunger: float = 50.0
@export_range(0.0, NEED_MAX) var thirst: float = 50.0
@export_range(0.0, NEED_MAX) var cleanliness: float = 50.0
@export_range(0.0, NEED_MAX) var health: float = 50.0
@export_range(0.0, NEED_MAX) var enrichment: float = 100.0

## Gesammelter Genesungsfortschritt, der bei fehlender Pflege wieder sinkt.
@export var recovery_timer: float = 0.0


## Erzeugt eine zufaellige Streunerkatze in schlechtem Zustand.
static func create_random() -> CatData:
	var cat := CatData.new()
	cat.id = "cat_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
	cat.cat_name = NAMES[randi() % NAMES.size()]
	cat.fur_variant = randi() % FUR_VARIANTS
	cat.shyness = randf_range(0.15, 0.95)
	cat.state = State.WILD
	cat.age_group = randi_range(Age.YOUNG, Age.SENIOR) as Age
	# Streuner sind hungrig, durstig und verdreckt -- aber nie voellig am Ende.
	cat.hunger = randf_range(10.0, 40.0)
	cat.thirst = randf_range(10.0, 40.0)
	cat.cleanliness = randf_range(5.0, 30.0)
	cat.health = randf_range(25.0, 55.0)
	cat.enrichment = randf_range(20.0, 45.0)
	cat.recovery_timer = 0.0
	return cat


## Alle fuenf Beduerfnisse als Dictionary.
func needs() -> Dictionary:
	return {
		"hunger": hunger,
		"thirst": thirst,
		"cleanliness": cleanliness,
		"health": health,
		"enrichment": enrichment,
	}


## Durchschnitt der fuenf Werte.
func wellbeing() -> float:
	return (hunger + thirst + cleanliness + health + enrichment) / 5.0


## Erreichen alle fuenf Beduerfnisse die Genesungsschwelle?
func all_needs_met() -> bool:
	return hunger >= RECOVERY_THRESHOLD \
		and thirst >= RECOVERY_THRESHOLD \
		and cleanliness >= RECOVERY_THRESHOLD \
		and health >= RECOVERY_THRESHOLD \
		and enrichment >= RECOVERY_THRESHOLD


## Fortschritt Richtung Adoption, 0.0 bis 1.0.
func recovery_progress() -> float:
	return clampf(recovery_timer / RECOVERY_SECONDS, 0.0, 1.0)

func is_starving() -> bool:
	return is_zero_approx(hunger) or is_zero_approx(thirst)

func age_title() -> String:
	return AGE_NAMES[age_group]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"cat_name": cat_name,
		"fur_variant": fur_variant,
		"state": int(state),
		"age_group": int(age_group),
		"critical_elapsed": critical_elapsed,
		"shyness": shyness,
		"hunger": hunger,
		"thirst": thirst,
		"cleanliness": cleanliness,
		"health": health,
		"enrichment": enrichment,
		"recovery_timer": recovery_timer,
	}


static func from_dict(data: Dictionary) -> CatData:
	var age: Variant = data.get("age_group", Age.ADULT)
	var critical: Variant = data.get("critical_elapsed", 0.0)
	var stored_state: Variant = data.get("state", State.AT_HOME)
	if not SupplyCatalog.is_count(age) or int(age) > Age.SENIOR \
			or not SupplyCatalog.is_count(stored_state) or int(stored_state) > State.DEAD \
			or not (critical is float or critical is int) \
			or not is_finite(float(critical)) or float(critical) < 0.0:
		return null
	for key: String in NUMERIC_DEFAULTS:
		var value: Variant = data.get(key, NUMERIC_DEFAULTS[key])
		if not (value is float or value is int) or not is_finite(float(value)):
			return null
	if data.get("id", "") is not String or data.get("cat_name", "") is not String \
			or not SupplyCatalog.is_count(data.get("fur_variant", 0)):
		return null
	var cat := CatData.new()
	cat.id = String(data.get("id", ""))
	cat.cat_name = String(data.get("cat_name", "Katze"))
	cat.fur_variant = clampi(int(data.get("fur_variant", 0)), 0, FUR_VARIANTS - 1)
	cat.state = int(stored_state) as State
	cat.age_group = int(age) as Age
	cat.critical_elapsed = float(critical)
	cat.shyness = clampf(float(data.get("shyness", 0.5)), 0.0, 1.0)
	cat.hunger = clampf(float(data.get("hunger", 50.0)), 0.0, NEED_MAX)
	cat.thirst = clampf(float(data.get("thirst", 50.0)), 0.0, NEED_MAX)
	cat.cleanliness = clampf(float(data.get("cleanliness", 50.0)), 0.0, NEED_MAX)
	cat.health = clampf(float(data.get("health", 50.0)), 0.0, NEED_MAX)
	cat.enrichment = clampf(float(data.get("enrichment", NEED_MAX)), 0.0, NEED_MAX)
	cat.recovery_timer = maxf(float(data.get("recovery_timer", 0.0)), 0.0)
	return cat
