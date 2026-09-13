class_name AnalyticsConsent
extends Control

var _service: Node
var _message: RichTextLabel
var _status: Label
var _accept: Button
var _decline: Button
var _panel: PanelContainer
var _previous_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.focus_mode = Control.FOCUS_ALL
	_panel.custom_minimum_size = Vector2(540, 316)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Freiwillige Nutzungsanalyse"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	_message = RichTextLabel.new()
	_message.name = "PrivacyText"
	_message.custom_minimum_size = Vector2(0, 186)
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("normal_font_size", 12)
	_message.selection_enabled = true
	box.add_child(_message)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_accept = Button.new()
	_accept.name = "Accept"
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.custom_minimum_size.y = 30
	buttons.add_child(_accept)
	_decline = Button.new()
	_decline.name = "Decline"
	_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline.custom_minimum_size.y = 30
	buttons.add_child(_decline)
	_accept.pressed.connect(_choose.bind(true))
	_decline.pressed.connect(_decline_choice)
	_accept.focus_next = _accept.get_path_to(_decline)
	_accept.focus_previous = _accept.get_path_to(_decline)
	_decline.focus_next = _decline.get_path_to(_accept)
	_decline.focus_previous = _decline.get_path_to(_accept)
	_panel.focus_previous = _panel.get_path_to(_decline)
	hide()


func present(service: Node) -> void:
	_service = service
	var available: bool = service.call("is_available")
	var consent: bool = service.call("has_consent")
	_message.text = String(service.call("privacy_text"))
	_status.text = String(service.get("last_error"))
	if not available and _status.text.is_empty():
		_status.text = "In diesem Build ist die Nutzungsanalyse nicht verfügbar."
	_accept.text = "Weiter erlauben" if consent else "Zustimmen"
	_accept.disabled = not available
	_decline.text = "Widerrufen" if consent else ("Nein danke" if available else "Schließen")
	if not visible:
		_previous_focus = get_viewport().gui_get_focus_owner()
	_panel.focus_next = _panel.get_path_to(_accept if available else _decline)
	_decline.focus_next = _decline.get_path_to(_accept if available else _panel)
	_decline.focus_previous = _decline.focus_next
	show()
	_panel.grab_focus()


func dismiss() -> void:
	if _service != null and bool(_service.call("needs_consent")):
		_choose(false)
	else:
		_close()


func _decline_choice() -> void:
	if bool(_service.call("is_available")):
		_choose(false)
	else:
		_close()


func _choose(allow: bool) -> void:
	if allow and bool(_service.call("has_consent")):
		_close()
		return
	if bool(_service.call("set_consent", allow)):
		_close()
	else:
		_status.text = String(_service.get("last_error"))
		_message.text = String(_service.call("privacy_text"))
		_accept.text = "Zustimmen"
		_decline.text = "Nein danke"


func _close() -> void:
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
