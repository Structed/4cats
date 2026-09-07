## Das Zuhause: Ueberblick ueber alle geretteten Katzen, Pflege und Upgrades.
extends Control

const CAT_CARD := preload("res://scenes/home/cat_card.tscn")

@onready var _cat_list: VBoxContainer = %CatList
@onready var _empty_label: Label = %EmptyLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _rescue_button: Button = %RescueButton
@onready var _shop_button: Button = %ShopButton
@onready var _menu_button: Button = %MenuButton
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _shop_dim: ColorRect = %ShopDim
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _shop_close: Button = %ShopCloseButton
@onready var _toast: Label = %Toast

var _cards: Dictionary = {}
var _toast_timer: float = 0.0


func _ready() -> void:
	_set_shop_visible(false)
	_toast.text = ""

	GameState.coins_changed.connect(_on_coins_changed)
	GameState.home_cats_changed.connect(_rebuild_cards)
	GameState.cat_adopted.connect(_on_cat_adopted)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)

	_rescue_button.pressed.connect(_on_rescue_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_shop_close.pressed.connect(_on_shop_close_pressed)

	_rebuild_cards()
	_on_coins_changed(GameState.coins)
	_build_shop()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.text = ""
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _shop_panel.visible:
		_on_shop_close_pressed()
		get_viewport().set_input_as_handled()


## Blendet Abdunklung und Laden gemeinsam ein oder aus.
func _set_shop_visible(shown: bool) -> void:
	_shop_panel.visible = shown
	_shop_dim.visible = shown


# --- Katzenliste -------------------------------------------------------------

func _rebuild_cards() -> void:
	for child in _cat_list.get_children():
		child.queue_free()
	_cards.clear()

	for cat in GameState.home_cats:
		var card := CAT_CARD.instantiate()
		card.set("cat", cat)
		_cat_list.add_child(card)
		_cards[cat.id] = card

	_empty_label.visible = GameState.home_cats.is_empty()


func _update_stats() -> void:
	_stats_label.text = "Gerettet: %d   ·   Vermittelt: %d   ·   Tragekorb: %d" % [
		GameState.rescued_total, GameState.adopted_total, GameState.carry_capacity()
	]


func _on_coins_changed(amount: int) -> void:
	_coin_label.text = "Münzen: %d" % amount
	_refresh_shop_buttons()


func _on_cat_adopted(cat: CatData, reward: int) -> void:
	AudioManager.play_sfx("adopt")
	_show_toast("%s ist gesund und hat ein Zuhause gefunden! +%d Münzen" % [cat.cat_name, reward])


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_timer = 4.5


# --- Laden -------------------------------------------------------------------

func _build_shop() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	for upgrade_id: String in GameState.UPGRADES:
		var info: Dictionary = GameState.UPGRADES[upgrade_id]

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var title := Label.new()
		title.name = "Title"
		title.text = String(info["name"])
		title.add_theme_font_size_override("font_size", 14)
		row.add_child(title)

		var description := Label.new()
		description.text = String(info["description"])
		description.add_theme_font_size_override("font_size", 10)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(260.0, 0.0)
		row.add_child(description)

		var button := Button.new()
		button.name = "Buy"
		button.set_meta("upgrade_id", upgrade_id)
		button.pressed.connect(_on_buy_pressed.bind(upgrade_id))
		row.add_child(button)

		_shop_list.add_child(row)

	_refresh_shop_buttons()


func _refresh_shop_buttons() -> void:
	if not is_instance_valid(_shop_list):
		return
	for row in _shop_list.get_children():
		var button := row.get_node_or_null("Buy") as Button
		var title := row.get_node_or_null("Title") as Label
		if button == null:
			continue
		var upgrade_id := String(button.get_meta("upgrade_id"))
		var level := GameState.upgrade_level(upgrade_id)
		var max_level := GameState.upgrade_max_level(upgrade_id)
		var cost := GameState.upgrade_cost(upgrade_id)

		if title != null:
			title.text = "%s  (Stufe %d/%d)" % [
				String(GameState.UPGRADES[upgrade_id]["name"]), level, max_level
			]

		if cost < 0:
			button.text = "Voll ausgebaut"
			button.disabled = true
		else:
			button.text = "Ausbauen – %d Münzen" % cost
			button.disabled = not GameState.can_afford_upgrade(upgrade_id)


func _on_buy_pressed(upgrade_id: String) -> void:
	if GameState.purchase_upgrade(upgrade_id):
		AudioManager.play_sfx("coins")
	else:
		AudioManager.play_sfx("ui_back")


func _on_upgrade_purchased(upgrade_id: String, level: int) -> void:
	_show_toast("%s auf Stufe %d ausgebaut." % [String(GameState.UPGRADES[upgrade_id]["name"]), level])
	_refresh_shop_buttons()
	SaveManager.save_game()


# --- Knoepfe -----------------------------------------------------------------

func _on_rescue_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	SaveManager.save_game()
	SceneRouter.goto_rescue()


func _on_shop_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	_set_shop_visible(true)
	_refresh_shop_buttons()


func _on_shop_close_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	_set_shop_visible(false)


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	SaveManager.save_game()
	SceneRouter.goto_main_menu()
