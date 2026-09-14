class_name HomeHUD
extends Control

const NEED_LABELS := {
	"hunger": "Hunger", "thirst": "Durst", "cleanliness": "Sauberkeit",
	"health": "Gesundheit", "enrichment": "Beschäftigung",
}
const CAT_STATUS_WIDTH := 220.0
const HINT_WIDTH := 240.0

signal furnish_requested()
signal shop_requested()
signal supplies_requested()
signal pause_requested()
signal close_requested()
signal menu_requested()
signal item_selected(id: String)
signal item_purchased(kind: String)
signal upgrade_requested(id: String)

var modal_kind: String = ""
var _modals: ModalHost
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
var _modal_notice: Label
var _furnish: Button
var _toast_time: float = 0.0
var _cat_panel: PanelContainer
var _cat_name: Label
var _cat_recovery: Label
var _cat_details: Label
var _cat_age: Label
var _cat_need_labels: Dictionary = {}
var _alerts: CareAlerts

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://resources/ui_theme.tres")
	var header := PanelContainer.new()
	header.name = "Header"
	add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 8
	header.offset_right = -8
	header.offset_top = 6
	header.offset_bottom = 66
	header.grow_vertical = Control.GROW_DIRECTION_END
	var header_style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	header_style.content_margin_top = 4
	header_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", header_style)
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	header.add_child(header_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header_box.add_child(row)
	row.add_child(_label("Zuhause", 15))
	_info = _label("", 10)
	_info.name = "HouseInfo"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.add_theme_color_override("font_color", Color("#c9dccb"))
	_info.add_theme_constant_override("outline_size", 1)
	row.add_child(_info)
	_coins = _label("", 12)
	row.add_child(_coins)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 6)
	header_box.add_child(navigation)
	_furnish = _button("Einrichten", "FurnishButton", navigation)
	_furnish.pressed.connect(func() -> void: furnish_requested.emit())
	var supplies := _button("Vorräte", "SupplyButton", navigation)
	supplies.tooltip_text = "Futter bestellen und Lieferungen ansehen"
	supplies.pressed.connect(func() -> void: supplies_requested.emit())
	_button("Ausbauen", "ShopButton", navigation).pressed.connect(func() -> void: shop_requested.emit())
	_button("Pause", "PauseButton", navigation).pressed.connect(func() -> void: pause_requested.emit())
	for button: Button in navigation.get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 30
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
	_hint_panel.offset_left = -HINT_WIDTH / 2.0
	_hint_panel.offset_right = HINT_WIDTH / 2.0
	_hint_panel.offset_top = -8
	_hint_panel.offset_bottom = -8
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", _compact_panel_style())
	_hint = _label("", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_build_cat_status()
	_alerts = CareAlerts.new()
	_alerts.name = "CareAlerts"
	add_child(_alerts)
	_alerts.offset_right = 340
	var alert_style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	alert_style.content_margin_top = 4
	alert_style.content_margin_bottom = 4
	alert_style.content_margin_left = 8
	alert_style.content_margin_right = 8
	_alerts.add_theme_stylebox_override("panel", alert_style)
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
	_modal_notice = _label("", 11)
	_modal_notice.name = "ModalMessage"
	_modal_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_notice.add_theme_color_override("font_color", Color("#ffd08a"))
	box.add_child(_modal_notice)
	_modal_notice.hide()
	_button("Schließen", "ModalCloseButton", box).pressed.connect(func() -> void: close_requested.emit())
	_modals = ModalHost.new(self)
	for kind in ["furnish", "supplies", "shop", "pause"]:
		_modals.register(kind, _panel, _dim)
	get_viewport().gui_focus_changed.connect(_modals.guard_focus)
	close_modal()
	refresh()

func _process(delta: float) -> void:
	if _modals.is_open():
		_modals.link_focus()
	_hint_panel.offset_top = -8.0 - _hint_panel.get_combined_minimum_size().y
	var bottom := _hint_panel.offset_top - 8.0 if _hint_panel.visible else -8.0
	_toast_panel.offset_bottom = bottom
	_toast_panel.offset_top = bottom - maxf(40.0, _toast_panel.get_combined_minimum_size().y)
	_cat_panel.offset_bottom = _cat_panel.offset_top + _cat_panel.get_combined_minimum_size().y
	if _toast_time > 0:
		_toast_time -= delta
		if _toast_time <= 0:
			_toast.text = ""
			_toast_panel.hide()
			_modal_notice.hide()

func _label(text: String, font_size: int) -> Label:
	return UiKit.label(text, font_size)


func _compact_panel_style() -> StyleBox:
	return UiKit.compact_panel_style(self)


func _button(text: String, node_name: String, parent: Node) -> Button:
	return UiKit.button(text, node_name, parent, 12, 28, self)

func _build_cat_status() -> void:
	_cat_panel = PanelContainer.new()
	_cat_panel.name = "CatStatus"
	_cat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cat_panel)
	_cat_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_cat_panel.offset_left = -CAT_STATUS_WIDTH - 8
	_cat_panel.offset_right = -8
	_cat_panel.offset_top = 70
	_cat_panel.offset_bottom = 70
	_cat_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cat_panel.grow_vertical = Control.GROW_DIRECTION_END
	_cat_panel.add_theme_stylebox_override("panel", _compact_panel_style())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_cat_panel.add_child(box)
	_cat_name = _label("", 11)
	_cat_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cat_name)
	var needs := GridContainer.new()
	needs.columns = 2
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	needs.add_theme_constant_override("h_separation", 4)
	needs.add_theme_constant_override("v_separation", 0)
	box.add_child(needs)
	for need_key: String in NEED_LABELS:
		var label := _label("", 10)
		needs.add_child(label)
		_cat_need_labels[need_key] = label
	_cat_age = _label("", 10)
	_cat_age.name = "CatAge"
	_cat_age.tooltip_text = "Altersgruppe"
	needs.add_child(_cat_age)
	_cat_recovery = _label("", 10)
	_cat_recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cat_recovery)
	_cat_details = _label("", 9)
	_cat_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cat_details)
	_cat_panel.hide()

func set_cat_status(cat: CatData) -> void:
	_cat_panel.visible = cat != null and modal_kind.is_empty()
	if cat == null:
		return
	_cat_name.text = "%s · Wohlbefinden: %d %%" % [cat.cat_name, roundi(cat.wellbeing())]
	_cat_age.text = cat.age_title()
	var needs: Dictionary = cat.needs()
	for need_key: String in NEED_LABELS:
		var value: float = needs[need_key]
		var label: Label = _cat_need_labels[need_key]
		var missing := value < CatData.RECOVERY_THRESHOLD
		label.text = "%s: %d%s" % [String(NEED_LABELS[need_key]), floori(value), "!" if missing else ""]
		label.add_theme_color_override("font_color",
			Color("#ffd18f") if missing else get_theme_color("font_color", "Label"))
	var progress := floori(cat.recovery_progress() * 100.0)
	var rule := "alle Werte ab %d" % int(CatData.RECOVERY_THRESHOLD)
	if not cat.all_needs_met():
		_cat_recovery.text = "Genesung: %d %% · sinkt" % progress \
			if cat.recovery_timer > 0 else "Pflege fehlt · Genesung: %d %%" % progress
		_cat_details.text = "! Pflege fehlt · Ziel: " + rule
	elif GameState.home_simulation.held_cat_id == cat.id:
		_cat_recovery.text = "Genesung abgeschlossen" if cat.recovery_timer >= CatData.RECOVERY_SECONDS \
			else "Genesung: %d %% · noch ca. %d s" % [
				progress, ceili(GameState.recovery_seconds_remaining(cat))]
		_cat_details.text = "Zum Vermitteln absetzen · " + rule
	else:
		_cat_recovery.text = "Genesung: %d %% · noch ca. %d s" % [
			progress, ceili(GameState.recovery_seconds_remaining(cat))]
		_cat_details.text = "Vermittlung automatisch · " + rule

func refresh() -> void:
	_coins.text = "%d Münzen" % GameState.coins
	_info.text = "%d Katzen zu Hause · %d vermittelt" % [
		GameState.home_cats.size(), GameState.adopted_total]
	var missing: PackedStringArray = _missing_fixtures()
	if not missing.is_empty():
		_info.text = "Kostenlos aufstellen: %s" % " / ".join(missing)
	_info.tooltip_text = fixture_hint()
	if not modal_kind.is_empty() and modal_kind != "supplies":
		_populate()

func _missing_fixtures() -> PackedStringArray:
	var missing: PackedStringArray = []
	for kind in SupplyCatalog.FIXTURES:
		var placed := false
		for item in GameState.home.items:
			if item.kind == kind and item.placed:
				placed = true
				break
		if not placed:
			missing.append(HomeCatalog.title(kind))
	return missing

func fixture_hint() -> String:
	var missing: PackedStringArray = _missing_fixtures()
	if missing.is_empty():
		return ""
	return "%s fehlt im Raum. Unter „Einrichten“ kostenlos aufstellen." % " / ".join(missing)

func set_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = not text.is_empty() and modal_kind.is_empty()

func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 5.0
	_toast_panel.visible = modal_kind.is_empty()
	_modal_notice.text = text
	_modal_notice.visible = not modal_kind.is_empty()

func set_building(building: bool) -> void:
	UiKit.set_button_text(_furnish, "Abbrechen" if building else "Einrichten")
	UiKit.apply_icon(_furnish, "FurnishButton", "close" if building else "furnish")
	set_hint("")
	if building:
		_cat_panel.hide()
		_toast_time = 0.0
		_toast_panel.hide()

func open_modal(kind: String) -> void:
	if not _modals.open(kind):
		return
	modal_kind = kind
	_cat_panel.hide()
	_toast_panel.hide()
	_modal_notice.hide()
	_hint_panel.hide()
	_populate()
	_modals.focus_first()

func close_modal() -> void:
	modal_kind = ""
	_modals.close()
	_modal_notice.hide()
	_toast_panel.visible = _toast_time > 0.0
	set_hint("")

func _populate() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if modal_kind == "furnish":
		_title.text = "Einrichten · %d Münzen" % GameState.coins
		var fixture_text := fixture_hint()
		if not fixture_text.is_empty():
			var notice := _label(fixture_text, 11)
			notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(notice)
		_content.add_child(_label("Vorhandene Einrichtung", 13))
		for item in GameState.home.items:
			var caption := "%s · %s" % [HomeCatalog.title(item.kind),
				"versetzen" if item.placed else "aufstellen"]
			var select := _button(caption, "Select_" + item.id, _content)
			# Der Knotenname traegt die Gegenstands-Id, nicht die Art -- das
			# Symbol muss deshalb ausdruecklich mitgegeben werden.
			UiKit.apply_icon(select, select.name, item.kind)
			select.disabled = GameState.home_simulation.item_in_use(item.id)
			select.pressed.connect(func() -> void: item_selected.emit(item.id))
		_content.add_child(_label("Zusätzliche Einrichtung", 13))
		for kind in HomeCatalog.KINDS:
			var price := HomeCatalog.price(kind)
			var caption := "%s – %s" % [HomeCatalog.title(kind),
				"kostenlos" if price == 0 else "%d Münzen" % price]
			var buy := _button(caption, "Buy_" + kind, _content)
			buy.disabled = GameState.coins < HomeCatalog.price(kind)
			buy.pressed.connect(func() -> void: item_purchased.emit(kind))
	elif modal_kind == "supplies":
		_title.text = "Futter bestellen"
		var supplies := SupplyPanel.new()
		supplies.name = "SupplyPanel"
		supplies.delivery = true
		supplies.message.connect(show_toast)
		_content.add_child(supplies)
		supplies.owner = self
		supplies.unique_name_in_owner = true
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
		_title.text = "Pause · " + DifficultyRules.title(GameState.difficulty_id)
		var help := _label("Gehen: WASD / Pfeiltasten\nInteraktion: E / Leertaste\nEinrichten: B · Drehen: R · Einlagern: X\nAbbrechen / Pause: Esc\n\n%s\n\nFutter am Schrank, Wasser am Hahn holen.\nPakete vor dem Nachfüllen im Schrank einräumen.\nWasser, Waschen, Behandlung und Katzenklo-Reinigung bleiben kostenlos." % DifficultyRules.description(
			GameState.difficulty_id), 12)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(help)
		_button("Weiterspielen", "ResumeButton", _content).pressed.connect(func() -> void: close_requested.emit())
		_button("Hauptmenü", "MenuButton", _content).pressed.connect(func() -> void: menu_requested.emit())
