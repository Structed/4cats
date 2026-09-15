class_name UpgradeSection
extends SaveSection
## Gekaufte Ausbaustufen. Welche Ausbauten es gibt, steht im UpgradeCatalog.

## Ausbau-Id -> gekaufte Stufe (0 = nicht gekauft).
var levels: Dictionary = {}

var _pending: Dictionary = {}


func reset(_mode: String) -> void:
	levels.clear()
	for key: String in UpgradeCatalog.ENTRIES:
		levels[key] = 0


func write(data: Dictionary) -> void:
	data["upgrade_levels"] = levels.duplicate()


func read(data: Dictionary) -> bool:
	var stored: Variant = data.get("upgrade_levels", {})
	if stored is not Dictionary:
		push_warning("Die gespeicherten Ausbauten sind beschädigt.")
		return false
	for key: String in UpgradeCatalog.ENTRIES:
		if not SupplyCatalog.is_count(stored.get(key, 0)):
			push_warning("Die gespeicherten Ausbaustufen sind beschädigt.")
			return false
	# Unbekannte Ausbau-Ids aus alten Staenden werden verworfen.
	_pending.clear()
	for key: String in UpgradeCatalog.ENTRIES:
		_pending[key] = clampi(int(stored.get(key, 0)), 0, UpgradeCatalog.max_level(key))
	return true


func commit() -> void:
	levels = _pending.duplicate()


func level(upgrade_id: String) -> int:
	return int(levels.get(upgrade_id, 0))


## Preis der naechsten Stufe, oder -1 wenn bereits voll ausgebaut.
func cost(upgrade_id: String) -> int:
	return UpgradeCatalog.cost_at(upgrade_id, level(upgrade_id))


func can_afford(upgrade_id: String, coins: int) -> bool:
	var price := cost(upgrade_id)
	return price >= 0 and coins >= price


## Bucht eine Stufe. Die Muenzen zieht der Spielzustand ab.
func purchase(upgrade_id: String) -> int:
	var next := level(upgrade_id) + 1
	levels[upgrade_id] = next
	return next


## Wirkung eines Ausbaus: jede Stufe multipliziert den Wert mit `per_level`.
func effect(upgrade_id: String, per_level: float) -> float:
	return pow(per_level, float(level(upgrade_id)))
