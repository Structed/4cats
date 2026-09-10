class_name HomeHUD
extends Control

signal furnish_requested()
signal shop_requested()
signal pause_requested()
signal close_requested()
signal menu_requested()
signal item_selected(id: String)
signal item_purchased(kind: String)
signal upgrade_requested(id: String)

var modal_kind: String = ""
var _coins: Label
var _info: Label
var _hint: Label
var _hint_panel: PanelContainer
var _toast: Label
var _toast_panel: PanelContainer
var _dim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _title: Label
var _furnish: Button
var _toast_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://resources/ui_theme.tres")
	var header := PanelContainer.new()
	add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 8
	header.offset_right = -8
	header.offset_top = 6
	header.offset_bottom = 62
	header.grow_vertical = Control.GROW_DIRECTION_END
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	row.add_child(heading)
	heading.add_child(_label("Zuhause", 18))
	_info = _label("", 10)
	_info.add_theme_color_override("font_color", Color("#c9dccb"))
	_info.add_theme_constant_override("outline_size", 1)
	heading.add_child(_info)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_coins = _label("", 12)
	row.add_child(_coins)
	_furnish = _button("Einrichten", "FurnishButton", row)
	_furnish.pressed.connect(func() -> void: furnish_requested.emit())
	_button("Ausbauen", "ShopButton", row).pressed.connect(func() -> void: shop_requested.emit())
	_button("Pause", "PauseButton", row).pressed.connect(func() -> void: pause_requested.emit())
	_toast_panel = PanelContainer.new()
	add_child(_toast_panel)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.offset_left = -170
	_toast_panel.offset_right = 170
	_toast_panel.offset_top = -111
	_toast_panel.offset_bottom = -72
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast = _label("", 11)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast)
	_toast_panel.hide()
	_hint_panel = PanelContainer.new()
	add_child(_hint_panel)
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.offset_left = -130
	_hint_panel.offset_right = 130
	_hint_panel.offset_top = -64
	_hint_panel.offset_bottom = -8
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = _label("", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_dim = ColorRect.new()
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.04, 0.06, 0.75)
	_panel = PanelContainer.new()
	_panel.name = "ModalPanel"
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -190
	_panel.offset_right = 190
	_panel.offset_top = -154
	_panel.offset_bottom = 154
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_title = _label("", 17)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_content)
	_button("Schließen", "ModalCloseButton", box).pressed.connect(func() -> void: close_requested.emit())
	close_modal()
	refresh()

func _process(delta: float) -> void:
	var bottom := -16.0 - _hint_panel.size.y
	_toast_panel.offset_bottom = bottom
	_toast_panel.offset_top = bottom - maxf(40.0, _toast_panel.get_combined_minimum_size().y)
	if _toast_time > 0:
		_toast_time -= delta
		if _toast_time <= 0:
			_toast.text = ""
			_toast_panel.hide()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, node_name: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.name = node_name
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size.y = 28
	parent.add_child(button)
	button.owner = self
	button.unique_name_in_owner = true
	return button

func refresh() -> void:
	_coins.text = "%d Münzen" % GameState.coins
	_info.text = "%d Katzen zu Hause · %d vermittelt" % [
		GameState.home_cats.size(), GameState.adopted_total]
	if not modal_kind.is_empty():
		_populate()

func set_hint(text: String) -> void:
	_hint.text = text

func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 5.0
	_toast_panel.show()

func set_building(building: bool) -> void:
	_furnish.text = "Abbrechen" if building else "Einrichten"
	if building:
		_toast_time = 0.0
		_toast_panel.hide()

func open_modal(kind: String) -> void:
	modal_kind = kind
	_dim.show()
	_panel.show()
	_populate()
	var first := _content.find_next_valid_focus()
	if first != null:
		first.grab_focus()

func close_modal() -> void:
	modal_kind = ""
	_dim.hide()
	_panel.hide()

func _populate() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if modal_kind == "furnish":
		_title.text = "Einrichten · %d Münzen" % GameState.coins
		_content.add_child(_label("Vorhandene Einrichtung", 13))
		for item in GameState.home.items:
			var caption := "%s · %s" % [HomeCatalog.title(item.kind),
				"versetzen" if item.placed else "aufstellen"]
			var select := _button(caption, "Select_" + item.id, _content)
			select.disabled = GameState.home_simulation.item_in_use(item.id)
			select.pressed.connect(func() -> void: item_selected.emit(item.id))
		_content.add_child(_label("Zusätzliche Einrichtung kaufen", 13))
		for kind in HomeCatalog.KINDS:
			var buy := _button("%s – %d Münzen" % [HomeCatalog.title(kind), HomeCatalog.price(kind)],
				"Buy_" + kind, _content)
			buy.disabled = GameState.coins < HomeCatalog.price(kind)
			buy.pressed.connect(func() -> void: item_purchased.emit(kind))
	elif modal_kind == "shop":
		_title.text = "Ausbauen · %d Münzen" % GameState.coins
		for id: String in GameState.UPGRADES:
			var info: Dictionary = GameState.UPGRADES[id]
			var cost := GameState.upgrade_cost(id)
			var title := _label("%s · Stufe %d/%d" % [
				String(info["name"]), GameState.upgrade_level(id), GameState.upgrade_max_level(id)], 14)
			_content.add_child(title)
			var description := _label(String(info["description"]), 11)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(description)
			var buy := _button("Voll ausgebaut" if cost < 0 else "Ausbauen – %d Münzen" % cost,
				"Upgrade_" + id, _content)
			buy.disabled = not GameState.can_afford_upgrade(id)
			buy.pressed.connect(func() -> void: upgrade_requested.emit(id))
	else:
		_title.text = "Pause"
		var help := _label("Gehen: WASD / Pfeiltasten\nInteraktion: E / Leertaste\nEinrichten: B · Drehen: R · Einlagern: X\nAbbrechen / Pause: Esc\n\nFutter, Wasser und Pflege sind kostenlos.", 13)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(help)
		_button("Weiterspielen", "ResumeButton", _content).pressed.connect(func() -> void: close_requested.emit())
		_button("Hauptmenü", "MenuButton", _content).pressed.connect(func() -> void: menu_requested.emit())
