class_name ProgressSection
extends SaveSection
## Fortschritt und Schwierigkeitsgrad: Muenzen, Zaehler, letzter Verlust.

var coins: int = 0
var rescued_total: int = 0
var adopted_total: int = 0
var deceased_total: int = 0
var last_loss_name: String = ""
var difficulty_id: String = DifficultyRules.DEFAULT

var _pending: Dictionary = {}


func reset(mode: String) -> void:
	coins = 0
	rescued_total = 0
	adopted_total = 0
	deceased_total = 0
	last_loss_name = ""
	difficulty_id = mode


func write(data: Dictionary) -> void:
	data["coins"] = coins
	data["rescued_total"] = rescued_total
	data["adopted_total"] = adopted_total
	data["deceased_total"] = deceased_total
	data["last_loss_name"] = last_loss_name
	data["difficulty_id"] = difficulty_id


func read(data: Dictionary) -> bool:
	var mode: Variant = data.get("difficulty_id")
	if mode is not String or not DifficultyRules.IDS.has(mode):
		push_warning("Im Spielstand fehlen gültige Versorgungsregeln.")
		return false
	if not SupplyCatalog.is_count(data.get("deceased_total")) \
			or data.get("last_loss_name") is not String:
		push_warning("Die gespeicherten Verlustdaten sind beschädigt.")
		return false
	for key in ["coins", "rescued_total", "adopted_total"]:
		if not SupplyCatalog.is_count(data.get(key, 0)):
			push_warning("Die gespeicherten Zähler sind beschädigt.")
			return false
	_pending = {
		"coins": int(data.get("coins", 0)),
		"rescued_total": int(data.get("rescued_total", 0)),
		"adopted_total": int(data.get("adopted_total", 0)),
		"deceased_total": int(data["deceased_total"]),
		"last_loss_name": String(data["last_loss_name"]),
		"difficulty_id": String(mode),
	}
	return true


func commit() -> void:
	coins = int(_pending["coins"])
	rescued_total = int(_pending["rescued_total"])
	adopted_total = int(_pending["adopted_total"])
	deceased_total = int(_pending["deceased_total"])
	last_loss_name = String(_pending["last_loss_name"])
	difficulty_id = String(_pending["difficulty_id"])
