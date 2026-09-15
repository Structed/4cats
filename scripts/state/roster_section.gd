class_name RosterSection
extends SaveSection
## Die Katzen des Spielers: getragene und zu Hause lebende.

## Katzen, die der Spieler gerade traegt.
var carried: Array[CatData] = []

## Katzen, die zu Hause leben.
var at_home: Array[CatData] = []

var _pending_carried: Array[CatData] = []
var _pending_home: Array[CatData] = []


func reset(_mode: String) -> void:
	carried.clear()
	at_home.clear()


func write(data: Dictionary) -> void:
	var carried_data: Array = []
	for cat in carried:
		carried_data.append(cat.to_dict())
	var home_data: Array = []
	for cat in at_home:
		home_data.append(cat.to_dict())
	data["carried_cats"] = carried_data
	data["home_cats"] = home_data


func read(data: Dictionary) -> bool:
	_pending_carried.clear()
	_pending_home.clear()
	var cat_ids := {}
	for key in ["carried_cats", "home_cats"]:
		var entries: Variant = data.get(key, [])
		if entries is not Array:
			push_warning("Die gespeicherte Katzenliste ist beschädigt.")
			return false
		for entry: Variant in entries:
			if entry is not Dictionary:
				push_warning("Die gespeicherten Katzendaten sind beschädigt.")
				return false
			var cat := CatData.from_dict(entry)
			var expected := CatData.State.CARRIED if key == "carried_cats" else CatData.State.AT_HOME
			if cat == null or cat.id.is_empty() or cat_ids.has(cat.id) or cat.state != expected:
				push_warning("Ungültige oder doppelte Katze im Spielstand.")
				return false
			cat_ids[cat.id] = true
			if key == "carried_cats":
				_pending_carried.append(cat)
			else:
				_pending_home.append(cat)
	return true


func commit() -> void:
	# assign() statt Zuweisung: Simulation und Anzeige halten die Listen.
	carried.assign(_pending_carried)
	at_home.assign(_pending_home)
