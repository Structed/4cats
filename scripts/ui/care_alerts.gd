class_name CareAlerts
extends PanelContainer

var _mode: Label
var _stock: Label
var _cargo: Label
var _warning: Label
var _loss: Label
var _refresh_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 8
	offset_top = 72
	offset_right = 288
	offset_bottom = 72
	grow_vertical = Control.GROW_DIRECTION_END
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_mode = _label(box, 11)
	_stock = _label(box, 10)
	_cargo = _label(box, 10)
	_warning = _label(box, 10)
	_warning.add_theme_color_override("font_color", Color("#ffd08a"))
	_loss = _label(box, 10)
	GameState.supplies_changed.connect(refresh)
	GameState.home_cats_changed.connect(refresh)
	refresh()

func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	_refresh_time -= delta
	if _refresh_time <= 0.0:
		_refresh_time = 0.1
		refresh()

func refresh() -> void:
	if not is_node_ready():
		return
	_mode.text = DifficultyRules.title(GameState.difficulty_id)
	var ready := GameState.supplies.ready_count()
	var incoming := GameState.supplies.orders.size() - ready
	_stock.text = "Futtervorrat: %d · Pakete: %d bereit, %d unterwegs" % [
		GameState.supplies.food_stock, ready, incoming]
	var arrival := GameState.supplies.next_arrival()
	if is_finite(arrival):
		_stock.text += " (%d s)" % ceili(arrival)
	_cargo.text = GameState.supplies.cargo_text()
	var first: CatData
	var count := 0
	for cat in GameState.home_cats:
		if GameState.care_warning(cat).is_empty():
			continue
		count += 1
		if first == null or cat.critical_elapsed > first.critical_elapsed \
				or (is_equal_approx(cat.critical_elapsed, first.critical_elapsed) and cat.health < first.health):
			first = cat
	_warning.text = GameState.care_warning(first) if first != null else ""
	if count > 1:
		_warning.text += "\n%d weitere Katze(n) brauchen Pflege." % (count - 1)
	if first == null and GameState.supplies.food_stock == 0:
		_warning.text = "Schrank leer: Futter im Laden holen oder bestellen."
	_warning.visible = not _warning.text.is_empty()
	_loss.text = "%s ist gestorben. Verluste: %d" % [GameState.last_loss_name, GameState.deceased_total]
	_loss.visible = GameState.deceased_total > 0

