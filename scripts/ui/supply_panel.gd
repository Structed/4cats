class_name SupplyPanel
extends VBoxContainer

signal message(text: String)

var delivery: bool = true
var _price: Label
var _status: Label
var _buy: Button
var _emergency: Button
var _refresh_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 8)
	_price = _label("")
	add_child(_price)
	_buy = _button("OrderFoodButton" if delivery else "BuyFoodButton")
	_buy.pressed.connect(_purchase)
	add_child(_buy)
	if not delivery:
		_emergency = _button("EmergencyFoodButton")
		UiKit.set_button_text(_emergency, "Kleine Notration abholen · kostenlos")
		_emergency.pressed.connect(_claim_emergency)
		add_child(_emergency)
	_status = _label("")
	_status.name = "DeliveryStatus"
	add_child(_status)
	GameState.coins_changed.connect(func(_coins: int) -> void: refresh())
	GameState.supplies_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	_refresh_time -= delta
	if _refresh_time <= 0.0:
		_refresh_time = 0.1
		refresh()

func _label(text: String) -> Label:
	var label := UiKit.label(text, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(node_name: String) -> Button:
	return UiKit.button("", node_name, null, 12, 32)

func refresh() -> void:
	if not is_node_ready():
		return
	var cost := GameState.food_price() + (GameState.delivery_fee() if delivery else 0)
	_price.text = "Futterpaket · %d Portionen\nFutter: %d Münzen%s\nDu hast %d Münzen." % [
		SupplyCatalog.PACKAGE_UNITS, GameState.food_price(),
		" · Lieferung: %d Münzen" % GameState.delivery_fee() if delivery else "", GameState.coins]
	UiKit.set_button_text(_buy, "Bestellen · %d Münzen" % cost if delivery \
		else "Paket mitnehmen · %d Münzen" % cost)
	_buy.disabled = GameState.coins < cost or (
		not delivery and not GameState.supply_actions.free_hands_error().is_empty())
	if _emergency != null:
		_emergency.disabled = not GameState.can_claim_emergency() \
			or not GameState.supply_actions.free_hands_error().is_empty()
	var lines: PackedStringArray = []
	lines.append("Pakete am Vorratsschrank einräumen. Wasser gibt es kostenlos am Hahn.")
	if not delivery and not GameState.supply_actions.free_hands_error().is_empty():
		lines.append(GameState.supply_actions.free_hands_error())
	if delivery:
		lines.append("Lieferzeit: %d s aktives Spielen. Menüs und Pause halten die Lieferung an." % int(
			DifficultyRules.value(GameState.difficulty_id, "delivery_seconds")))
		lines.append("Mehrere Bestellungen sind möglich. Pakete an der Haustür abholen.")
	for order in GameState.supplies.orders:
		lines.append("Paket %d: %s" % [order.id,
			"an der Haustür" if order.remaining <= 0 else "noch %d s" % ceili(order.remaining)])
	_status.text = "\n".join(lines)

func _purchase() -> void:
	var error := GameState.order_food() if delivery else GameState.buy_food_package()
	_finish(error, "Futter bestellt. Die Lieferzeit läuft beim Weiterspielen." if delivery \
		else "Paket gekauft. Bring es zum Vorratsschrank.")

func _claim_emergency() -> void:
	_finish(GameState.buy_food_package(true), "Notration erhalten. Bring sie zum Vorratsschrank.")

func _finish(error: String, success: String) -> void:
	if not error.is_empty():
		message.emit(error)
		return
	refresh()
	if SaveManager.save_game():
		AudioManager.play_sfx("coins")
		message.emit(success)
