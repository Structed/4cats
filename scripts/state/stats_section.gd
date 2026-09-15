class_name StatsSection
extends SaveSection
## Die lokale Spielstatistik.

var stats: GameplayStats = GameplayStats.new()

var _pending: GameplayStats = null


func reset(_mode: String) -> void:
	stats = GameplayStats.new()


func write(data: Dictionary) -> void:
	data["analytics"] = stats.to_dict()


func read(data: Dictionary) -> bool:
	var raw: Variant = data.get("analytics")
	if raw is not Dictionary:
		push_warning("Im Spielstand fehlt die lokale Statistik.")
		return false
	var loaded := GameplayStats.from_dict(raw)
	if loaded == null:
		push_warning("Die lokale Spielstatistik ist beschädigt.")
		return false
	_pending = loaded
	return true


func commit() -> void:
	stats = _pending
	_pending = null
