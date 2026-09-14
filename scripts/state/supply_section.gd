class_name SupplySection
extends SaveSection
## Vorraete, Ladung und laufende Lieferungen.

var state: SupplyState = SupplyState.new()

var _pending: SupplyState = null


func reset(_mode: String) -> void:
	state = SupplyState.new()


func write(data: Dictionary) -> void:
	data["supplies"] = state.to_dict()


func read(data: Dictionary) -> bool:
	var mode: Variant = data.get("difficulty_id")
	var raw: Variant = data.get("supplies")
	if mode is not String or not DifficultyRules.IDS.has(mode) or raw is not Dictionary:
		push_warning("Im Spielstand fehlen gültige Versorgungsregeln.")
		return false
	var loaded := SupplyState.from_dict(raw)
	if loaded == null:
		push_warning("Die gespeicherten Vorräte sind beschädigt.")
		return false
	for order in loaded.orders:
		if order.remaining > DifficultyRules.value(mode, "delivery_seconds"):
			push_warning("Die gespeicherte Lieferzeit ist ungültig.")
			return false
	_pending = loaded
	return true


func commit() -> void:
	state = _pending
	_pending = null
