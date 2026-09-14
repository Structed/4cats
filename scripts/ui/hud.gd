## Anzeige waehrend der Rettungs-Phase.
##
## Zeigt Rettungskorb, Vorrat, Pflegewarnungen und den Heimweg; verwaltet
## ausserdem Pause und den nur an der Ladentheke erreichbaren Einkauf.
extends Control

const HINT_SECONDS := 3.5
const RELEASE_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down", "interact", "sprint",
]

@onready var _home_indicator: HomeIndicator = $HomeIndicator
@onready var _top_left: VBoxContainer = $TopLeft
@onready var _carry_label: Label = %CarryLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _hint_label: Label = %HintLabel
@onready var _pause_panel: PanelContainer = %PausePanel
@onready var _pause_dim: ColorRect = %PauseDim
@onready var _home_button: Button = %HomeButton
@onready var _resume_button: Button = %ResumeButton
@onready var _to_home_button: Button = %ToHomeButton
@onready var _to_menu_button: Button = %ToMenuButton
@onready var _shop_hint: Label = $ShopHint

var _hint_timer: float = 0.0
var _care_alerts: CareAlerts
var _player: Player
var _shop: FoodShop
var _touch: CanvasLayer
var _shop_dim: ColorRect
var _shop_panel: PanelContainer
var _shop_message: Label
var _shop_close: Button
var _supplies: SupplyPanel
var _modals: ModalHost
var _leaving: bool = false
var _physics_before_modal: bool = true
var _home_focus_before_modal: Control.FocusMode = Control.FOCUS_ALL
var _home_disabled_before_modal: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_modals = ModalHost.new(self)
	_hint_label.text = ""
	_care_alerts = CareAlerts.new()
	_care_alerts.name = "CareAlerts"
	add_child(_care_alerts)
	move_child(_care_alerts, _pause_dim.get_index())
	for scene_button: Button in [
		_home_button, _resume_button, _to_home_button, _to_menu_button,
	]:
		UiKit.decorate(scene_button)
	_build_shop_dialog()
	_modals.register("pause", _pause_panel, _pause_dim)
	_modals.register("shop", _shop_panel, _shop_dim)

	GameState.carried_changed.connect(_on_carried_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.cat_adopted.connect(_on_cat_adopted)
	GameState.cat_died.connect(_on_cat_died)
	SaveManager.save_failed.connect(set_hint)
	get_viewport().gui_focus_changed.connect(_modals.guard_focus)

	_home_button.pressed.connect(_on_home_pressed)
	_resume_button.pressed.connect(func() -> void: toggle_pause())
	_to_home_button.pressed.connect(_on_home_pressed)
	_to_menu_button.pressed.connect(_on_menu_pressed)

	_on_carried_changed(GameState.carried_cats.size(), GameState.carry_capacity())
	_on_coins_changed(GameState.coins)


func _process(delta: float) -> void:
	_layout_care_alerts()
	if _modals.is_open():
		_modals.link_focus()
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif _modals.is_open() and event.is_action("interact"):
		get_viewport().set_input_as_handled()


func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_timer = HINT_SECONDS


func _on_cat_adopted(cat: CatData, reward: int) -> void:
	set_hint("%s hat ein Zuhause gefunden! +%d Münzen" % [cat.cat_name, reward])


func _on_cat_died(cat: CatData) -> void:
	set_hint("%s ist gestorben. Die übrigen Katzen brauchen weiter Pflege." % cat.cat_name)
	_care_alerts.refresh()


func set_home_navigation(
		player: Node2D, home_zone: Node2D, extra_obstacles: Array[Control]) -> void:
	var obstacles: Array[Control] = [
		_top_left, _home_button, _hint_label, _shop_hint, _care_alerts,
	]
	obstacles.append_array(extra_obstacles)
	_home_indicator.configure(player, home_zone, obstacles)


func toggle_pause() -> void:
	if _leaving or bool(SceneRouter.get("_busy")):
		return
	if _modals.is_open():
		close_shop()
	elif not get_tree().paused:
		_open_modal("pause")
	AudioManager.play_sfx("ui_click")


func set_shop_context(player: Player, shop: FoodShop, touch: CanvasLayer) -> void:
	_player = player
	_shop = shop
	_touch = touch


func set_shop_reachable(reachable: bool) -> void:
	_shop_hint.text = "E / Aktion: Futter einkaufen" if reachable \
		else "Futterladen: oberhalb von Zuhause"


func open_shop() -> bool:
	if _leaving or _modals.is_open() or get_tree().paused \
			or bool(SceneRouter.get("_busy")) or not is_instance_valid(_shop) \
			or not _shop.can_interact(_player):
		return false
	_shop_message.text = ""
	_shop_message.hide()
	_supplies.refresh()
	_open_modal("shop")
	return true


func is_shop_open() -> bool:
	return _modals.kind == "shop"


func _build_shop_dialog() -> void:
	_shop_dim = ColorRect.new()
	_shop_dim.name = "ShopDim"
	_shop_dim.color = Color(0.03, 0.04, 0.05, 0.78)
	_shop_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_dim.z_index = 1
	add_child(_shop_dim)
	_shop_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_dim.hide()

	_shop_panel = PanelContainer.new()
	_shop_panel.name = "ShopPanel"
	_shop_panel.z_index = 2
	add_child(_shop_panel)
	_shop_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_shop_panel.offset_left = -332
	_shop_panel.offset_right = -8
	_shop_panel.offset_top = 20
	_shop_panel.offset_bottom = -20
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	_shop_panel.add_child(box)
	var title := Label.new()
	title.text = "Futterladen"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	box.add_child(scroll)
	_supplies = SupplyPanel.new()
	_supplies.name = "SupplyPanel"
	_supplies.delivery = false
	_supplies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_supplies.message.connect(_on_shop_message)
	scroll.add_child(_supplies)
	_shop_message = Label.new()
	_shop_message.name = "ShopMessage"
	_shop_message.add_theme_font_size_override("font_size", 11)
	_shop_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_shop_message)
	_shop_close = UiKit.button("Schließen · Esc", "CloseShopButton", box, 0, 32)
	_shop_close.pressed.connect(close_shop)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.TRANSPARENT
	ring.border_color = Color("#ffe5b4")
	ring.set_border_width_all(2)
	for button: Button in [
		_supplies.get_node("BuyFoodButton"), _supplies.get_node("EmergencyFoodButton"), _shop_close,
		_resume_button, _to_home_button, _to_menu_button,
	]:
		button.add_theme_stylebox_override("focus", ring)
	_shop_panel.hide()


func _on_shop_message(text: String) -> void:
	_shop_message.text = text
	_shop_message.visible = not text.is_empty()
	set_hint(text)


func _open_modal(kind: String) -> void:
	# Zuerst oeffnen: der Fokus muss gemerkt sein, bevor der Heimweg-Knopf
	# abgeschaltet wird -- sonst ist er schon verloren.
	if not _modals.open(kind):
		return
	_home_focus_before_modal = _home_button.focus_mode
	_home_disabled_before_modal = _home_button.disabled
	_home_button.focus_mode = Control.FOCUS_NONE
	_home_button.disabled = true
	if is_instance_valid(_player):
		_physics_before_modal = _player.is_physics_processing()
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(false)
	_release_controls()
	get_tree().paused = true
	AnalyticsManager.player_activity()
	# Die Warnungen bleiben links neben dem Kaufdialog ungedimmt lesbar.
	_care_alerts.z_index = 2 if kind == "shop" else 0
	_modals.focus_first.call_deferred()


func close_shop() -> void:
	if not _modals.is_open():
		return
	_modals.close()
	_care_alerts.z_index = 0
	_home_button.focus_mode = _home_focus_before_modal
	_home_button.disabled = _home_disabled_before_modal
	_release_controls()
	get_tree().paused = false
	AnalyticsManager.player_activity()
	if _leaving:
		_modals.forget_focus()
		return
	if is_instance_valid(_player):
		_player.set_physics_process(_physics_before_modal)
	if is_instance_valid(_touch):
		_touch.call("set_enabled", true)
	_modals.restore_focus()


func _release_controls() -> void:
	if is_instance_valid(_touch) and _touch.is_inside_tree():
		_touch.call("set_enabled", false)
	for action in RELEASE_ACTIONS:
		Input.action_release(action)
	if is_instance_valid(_player):
		_player.velocity = Vector2.ZERO


func _layout_care_alerts() -> void:
	_care_alerts.position.x = 8
	if not is_instance_valid(_touch) or not bool(_touch.call("is_touch_visible")):
		return
	var joystick: Control = _touch.get_node("Root/Joystick")
	var rect := joystick.get_global_rect()
	if _care_alerts.get_global_rect().intersects(rect.grow(8)):
		_care_alerts.position.x = rect.end.x + 8


func _on_carried_changed(carried: int, capacity: int) -> void:
	_carry_label.text = "Katzen dabei: %d / %d" % [carried, capacity]


func _on_coins_changed(amount: int) -> void:
	_coin_label.text = "Münzen: %d" % amount


func _on_home_pressed() -> void:
	if _leaving or _modals.kind == "shop":
		return
	AudioManager.play_sfx("ui_click")
	prepare_to_leave()
	SceneRouter.goto_home()


func _on_menu_pressed() -> void:
	if _leaving:
		return
	AudioManager.play_sfx("ui_back")
	prepare_to_leave()
	SceneRouter.goto_main_menu()


func prepare_to_leave() -> void:
	_leaving = true
	close_shop()
	_release_controls()


func _exit_tree() -> void:
	if _modals.is_open():
		get_tree().paused = false
	_release_controls()
