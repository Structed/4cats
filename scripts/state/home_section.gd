class_name HomeSection
extends SaveSection
## Das Haus mit seiner Einrichtung.

var house: HomeData = HomeData.starter()

var _pending: HomeData = null


func reset(_mode: String) -> void:
	house = HomeData.starter()


func write(data: Dictionary) -> void:
	data["home"] = house.to_dict()


func read(data: Dictionary) -> bool:
	var raw: Variant = data.get("home")
	if raw is not Dictionary:
		push_warning("Im Spielstand fehlen die Hausdaten.")
		return false
	var loaded := HomeData.from_dict(raw)
	if loaded == null:
		push_warning("Die gespeicherten Hausdaten sind beschaedigt.")
		return false
	var layout_error := HomeLayout.new(loaded).save_error()
	if not layout_error.is_empty():
		push_warning("Hausspielstand: %s" % layout_error)
		return false
	_pending = loaded
	return true


func commit() -> void:
	house = _pending
	_pending = null
