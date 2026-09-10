## Szenenwechsel mit weichem Ein-/Ausblenden.
##
## Autoload -- ueberall als `SceneRouter` erreichbar. Als CanvasLayer mit hoher
## Ebene angelegt, damit die Blende immer ueber allem anderen liegt.
extends CanvasLayer

signal scene_changed(path: String)

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const HOME := "res://scenes/home/home_scene.tscn"
const RESCUE := "res://scenes/rescue/rescue_level.tscn"

const FADE_DURATION := 0.25

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.06, 0.08, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	add_child(_fade)


func goto_main_menu() -> void:
	goto_scene(MAIN_MENU)


func goto_home() -> void:
	goto_scene(HOME)


func goto_rescue() -> void:
	goto_scene(RESCUE)


func goto_scene(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("Szene nicht gefunden: %s" % path)
		return
	_busy = true
	_change_scene_async(path)


func _change_scene_async(path: String) -> void:
	var current := get_tree().current_scene
	if current != null and current.has_method("prepare_to_leave"):
		current.call("prepare_to_leave")
	var was_active := GameState.simulation_active
	GameState.simulation_active = false
	await _fade_to(1.0)

	# Vor jedem Wechsel sichern, damit nichts verloren geht.
	SaveManager.save_game()

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		GameState.simulation_active = was_active
		push_error("Szenenwechsel fehlgeschlagen (%s): %s" % [path, error_string(err)])
	else:
		GameState.simulation_active = path in [HOME, RESCUE]
		# Einen Frame warten, damit die neue Szene wirklich im Baum haengt.
		await get_tree().process_frame
		scene_changed.emit(path)

	await _fade_to(0.0)
	_busy = false


func _fade_to(target_alpha: float) -> void:
	_fade.visible = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "modulate:a", target_alpha, FADE_DURATION)
	await tween.finished
	if is_zero_approx(target_alpha):
		_fade.visible = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
