class_name AnalyticsConsent
extends Control

## Der Dienst wird hereingereicht statt als Autoload geholt, damit die Tests
## eine eigene Instanz mit eigener Datei benutzen koennen.
const AnalyticsService := preload("res://scripts/autoload/analytics_manager.gd")

const SUMMARY := (
	"Mit deiner Erlaubnis zählen wir Spielzeit und Spielaktionen, zum Beispiel Katzenrettungen. "
	+ "Das hilft uns, 4cats zu verbessern.\n\n"
	+ "Die Daten gehen an PostHog in der EU. Wir senden keine Namen. Eine zufällige Kennung "
	+ "erkennt diese Spielinstallation wieder - ganz anonym ist das also nicht.\n\n"
	+ "Du kannst auch ohne Freigabe alles spielen. Deine Wahl lässt sich später unter "
	+ "Optionen > Nutzungsanalyse ändern."
)

var _service: AnalyticsService
var _message: RichTextLabel
var _status: Label
var _details: Button
var _accept: Button
var _decline: Button
var _panel: PanelContainer
var _previous_focus: Control
var _show_details: bool = false


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
	title.text = "Dürfen wir Spielstatistiken sammeln?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	_message = RichTextLabel.new()
	_message.name = "PrivacyText"
	_message.custom_minimum_size = Vector2(0, 166)
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("normal_font_size", 12)
	_message.selection_enabled = true
	box.add_child(_message)
	_details = UiKit.button("", "PrivacyDetails", box, 12, 24)
	_details.flat = true
	_details.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details.pressed.connect(_toggle_details)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_accept = UiKit.button("", "Accept", buttons, 0, 30)
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline = UiKit.button("", "Decline", buttons, 0, 30)
	_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.pressed.connect(_choose.bind(true))
	_decline.pressed.connect(_decline_choice)
	hide()


func present(service: AnalyticsService) -> void:
	_service = service
	var available := service.is_available()
	var consent := service.has_consent()
	_show_details = false
	_refresh_message()
	_status.text = service.last_error
	if not available and _status.text.is_empty():
		_status.text = "In diesem Build ist die Nutzungsanalyse nicht verfügbar."
	_status.visible = not _status.text.is_empty()
	UiKit.set_button_text(_accept, "Weiter erlauben" if consent else "Ja, erlauben")
	_accept.disabled = not available
	UiKit.set_button_text(_decline,
		"Widerrufen" if consent else ("Nein danke" if available else "Schließen"))
	if not visible:
		_previous_focus = get_viewport().gui_get_focus_owner()
	_configure_focus(available)
	show()
	_panel.grab_focus()


func _toggle_details() -> void:
	_show_details = not _show_details
	_refresh_message()


func _refresh_message() -> void:
	_message.text = _service.privacy_text() if _show_details else SUMMARY
	_message.scroll_to_line(0)
	UiKit.set_button_text(_details,
		"Zurück zur Kurzfassung" if _show_details else "Mehr zum Datenschutz")


func _configure_focus(available: bool) -> void:
	var controls: Array[Control] = [_details]
	if available:
		controls.append(_accept)
	controls.append(_decline)
	for index in controls.size():
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
	_panel.focus_next = _panel.get_path_to(_details)
	_panel.focus_previous = _panel.get_path_to(_decline)


func dismiss() -> void:
	if _service != null and _service.needs_consent():
		_choose(false)
	else:
		_close()


func _decline_choice() -> void:
	if _service.is_available():
		_choose(false)
	else:
		_close()


func _choose(allow: bool) -> void:
	if allow and _service.has_consent():
		_close()
		return
	if _service.set_consent(allow):
		_close()
	else:
		_status.text = _service.last_error
		_status.show()
		_refresh_message()
		UiKit.set_button_text(_accept, "Ja, erlauben")
		UiKit.set_button_text(_decline, "Nein danke")


func _close() -> void:
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
