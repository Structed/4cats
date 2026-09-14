## Prueft die Fenster des Hauses.
##
## Aufruf ueber tools/test_gameplay.gd (`--test`).
##
## Der Kern ist die letzte Pruefung: jede Aktion, die ein Fenster melden kann,
## muss in `HomeScene._on_hud_action` auch behandelt werden. Weil Aktionen
## StringNames sind, faellt ein Tippfehler sonst erst beim Klicken auf.
extends RefCounted

const HOME_SCENE_PATH := "res://scripts/home/home_scene.gd"

var _failures: PackedStringArray = []
var _actions: Dictionary = {}


func run(tree: SceneTree) -> PackedStringArray:
	_failures = []
	_actions = {}
	if GameState.home_simulation == null:
		_failures.append("Fenster-Test: GameState ist nicht eingerichtet.")
		return _failures
	_test_registry()
	for kind: String in HomeHUD.PANELS:
		_test_panel(tree, kind)
	_test_actions_handled()
	return _failures


func _test_registry() -> void:
	for kind: String in HomeHUD.PANELS:
		var script: GDScript = HomeHUD.PANELS[kind]
		_check(script != null and script.can_instantiate(),
			"Fenster „%s“ laesst sich nicht laden." % kind)
		var panel: Object = script.new()
		_check(panel is HomePanel, "Fenster „%s“ ist kein HomePanel." % kind)
		_check(not (panel as HomePanel).title().is_empty(),
			"Fenster „%s“ hat keine Ueberschrift." % kind)
	for kind in ["furnish", "supplies", "shop", "pause"]:
		_check(HomeHUD.PANELS.has(kind), "Fenster „%s“ fehlt in der Liste." % kind)


func _test_panel(tree: SceneTree, kind: String) -> void:
	var host := Control.new()
	var content := VBoxContainer.new()
	host.add_child(content)
	tree.root.add_child(host)
	content.owner = host
	var script: GDScript = HomeHUD.PANELS[kind]
	var panel: HomePanel = script.new()
	panel.build(PanelBuilder.new(content, host, _record))
	_check(content.get_child_count() > 0, "Fenster „%s“ bleibt leer." % kind)
	var buttons: Array[Button] = []
	for child in content.get_children():
		if child is Button:
			buttons.append(child as Button)
	for button in buttons:
		_check(host.get_node_or_null("%%%s" % button.name) == button,
			"Knopf „%s“ ist nicht ueber %%Name auffindbar." % button.name)
		button.pressed.emit()
	match kind:
		"furnish":
			_check_names(buttons, "Buy_", HomeCatalog.KINDS.size(), kind)
		"shop":
			_check_names(buttons, "Upgrade_", GameState.UPGRADES.size(), kind)
		"pause":
			_check(_has_name(buttons, "ResumeButton") and _has_name(buttons, "MenuButton"),
				"Pause-Fenster ohne Weiterspielen/Hauptmenue.")
		"supplies":
			_check(host.get_node_or_null("%SupplyPanel") != null,
				"Vorrats-Fenster ohne SupplyPanel.")
	host.queue_free()


func _check_names(buttons: Array[Button], prefix: String, expected: int, kind: String) -> void:
	var found := 0
	for button in buttons:
		if button.name.begins_with(prefix):
			found += 1
	_check(found == expected,
		"Fenster „%s“ zeigt %d statt %d Knoepfe mit „%s“." % [kind, found, expected, prefix])


func _has_name(buttons: Array[Button], node_name: String) -> bool:
	for button in buttons:
		if button.name == node_name:
			return true
	return false


## Jede gemeldete Aktion muss in home_scene.gd einen Zweig haben.
func _test_actions_handled() -> void:
	var source := FileAccess.get_file_as_string(HOME_SCENE_PATH)
	_check(not source.is_empty(), "home_scene.gd laesst sich nicht lesen.")
	_check(_actions.size() > 0, "Kein Fenster meldet eine Aktion.")
	for action: StringName in _actions:
		_check(source.contains("&\"%s\"" % action),
			"Aktion „%s“ wird in home_scene.gd nicht behandelt." % action)


func _record(action: StringName, _payload: Variant = null) -> void:
	_actions[action] = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
