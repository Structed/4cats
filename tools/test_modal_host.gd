## Regeln der gemeinsamen Modal-Steuerung.
##
## Wichtig ist hier vor allem der Fall, den es vor ModalHost nur im Rettungs-HUD
## gab: der Fokusring laeuft am Ende wieder von vorn los und verlaesst das
## Fenster nicht. Ausserdem der Sonderfall des Hauses, in dem sich mehrere
## Modale dasselbe Fenster teilen und nur den Inhalt tauschen.
extends RefCounted

var _failures: PackedStringArray = []


func run(tree: SceneTree) -> PackedStringArray:
	_test_visibility(tree)
	_test_shared_panel(tree)
	_test_button_ring(tree)
	_test_focus(tree)
	return _failures


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FEHLER", description])
	if not condition:
		_failures.append(description)


## Baut ein Fenster mit `count` Knoepfen und haengt es in den Baum.
func _make_owner(tree: SceneTree, count: int) -> Control:
	var owner := Control.new()
	owner.name = "ModalOwner"
	tree.root.add_child(owner)
	var dim := ColorRect.new()
	dim.name = "Dim"
	owner.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	owner.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	panel.add_child(box)
	for index in count:
		UiKit.button("Knopf %d" % index, "Knopf%d" % index, box, 0, 20)
	return owner


func _test_visibility(tree: SceneTree) -> void:
	print("--- Modale: Sichtbarkeit ---")
	var owner := _make_owner(tree, 2)
	var panel: Control = owner.get_node("Panel")
	var dim: Control = owner.get_node("Dim")
	panel.show()
	dim.show()
	var host := ModalHost.new(owner)
	host.register("pause", panel, dim)
	_check(not panel.visible and not dim.visible,
		"Ein angemeldetes Fenster startet geschlossen")
	_check(not host.is_open() and host.kind.is_empty(),
		"Ohne Aufruf ist kein Modal offen")

	var opened: Array[String] = []
	var closed: Array[String] = []
	host.opened.connect(func(kind: String) -> void: opened.append(kind))
	host.closed.connect(func(kind: String) -> void: closed.append(kind))

	_check(host.open("pause"), "Ein angemeldetes Modal laesst sich oeffnen")
	_check(panel.visible and dim.visible and host.kind == "pause",
		"Das offene Modal zeigt Fenster und Abdunklung")
	_check(host.panel() == panel, "Der Host kennt das Fenster des offenen Modals")
	host.close()
	_check(not panel.visible and not dim.visible and not host.is_open(),
		"Das geschlossene Modal blendet beides wieder aus")
	_check(opened == ["pause"] and closed == ["pause"],
		"Oeffnen und Schliessen melden sich genau einmal")
	closed.clear()
	host.close()
	_check(closed.is_empty(), "Ein zweites Schliessen bleibt folgenlos")
	owner.queue_free()


func _test_shared_panel(tree: SceneTree) -> void:
	print("--- Modale: gemeinsames Fenster ---")
	var owner := _make_owner(tree, 1)
	var panel: Control = owner.get_node("Panel")
	var dim: Control = owner.get_node("Dim")
	var host := ModalHost.new(owner)
	# Wie im Haus: vier Modale, ein Fenster, nur der Inhalt wechselt.
	for kind in ["furnish", "supplies", "shop", "pause"]:
		host.register(kind, panel, dim)
	_check(not panel.visible, "Auch das geteilte Fenster startet geschlossen")
	host.open("furnish")
	_check(panel.visible and dim.visible,
		"Das geteilte Fenster bleibt sichtbar, obwohl es mehrfach angemeldet ist")
	host.open("shop")
	_check(panel.visible and host.kind == "shop",
		"Ein Wechsel zwischen zwei Modalen laesst das Fenster stehen")
	host.close()
	_check(not panel.visible and not dim.visible,
		"Nach dem Schliessen ist das geteilte Fenster verschwunden")
	owner.queue_free()


func _test_button_ring(tree: SceneTree) -> void:
	print("--- Modale: Fokusring ---")
	var owner := _make_owner(tree, 3)
	var panel: Control = owner.get_node("Panel")
	var box: Control = owner.get_node("Panel/Box")
	var host := ModalHost.new(owner)
	host.register("pause", panel)
	_check(host.buttons().is_empty(), "Ohne offenes Modal gibt es keinen Fokusring")
	host.open("pause")

	var ring: Array[Button] = host.buttons()
	_check(ring.size() == 3, "Der Ring findet alle Knoepfe des Fensters (%d)" % ring.size())
	_check(ring.size() == 3 and ring[0].name == "Knopf0" and ring[2].name == "Knopf2",
		"Der Ring folgt der Anzeigereihenfolge")

	var disabled: Button = box.get_node("Knopf1")
	disabled.disabled = true
	var without: Array[Button] = host.buttons()
	_check(without.size() == 2 and without[1].name == "Knopf2",
		"Ein abgeschalteter Knopf faellt aus dem Ring")
	disabled.disabled = false

	host.link_focus()
	ring = host.buttons()
	var last: Button = ring[ring.size() - 1]
	var first: Button = ring[0]
	_check(last.get_node(last.focus_next) == first,
		"Hinter dem letzten Knopf geht es wieder beim ersten weiter")
	_check(first.get_node(first.focus_previous) == last,
		"Vor dem ersten Knopf steht der letzte")
	_check(first.get_node(first.focus_neighbor_bottom) == ring[1],
		"Auch das Steuerkreuz folgt dem Ring")
	owner.queue_free()


func _test_focus(tree: SceneTree) -> void:
	print("--- Modale: Fokus ---")
	var owner := _make_owner(tree, 2)
	var panel: Control = owner.get_node("Panel")
	var outside := UiKit.button("Draussen", "Draussen", owner, 0, 20)
	var host := ModalHost.new(owner)
	host.register("pause", panel)

	outside.grab_focus()
	_check(outside.has_focus(), "Der Ausgangsfokus liegt ausserhalb des Fensters")
	host.open("pause")
	host.focus_first()
	var inside: Button = host.buttons()[0]
	_check(inside.has_focus(), "Beim Oeffnen springt der Fokus auf den ersten Knopf")

	# Innerhalb des Fensters darf der Waechter den Fokus nicht anfassen.
	var second: Button = host.buttons()[1]
	second.grab_focus()
	host.guard_focus(second)
	_check(second.has_focus(), "Im Fenster laesst der Waechter den Fokus in Ruhe")

	host.close()
	host.restore_focus()
	_check(outside.has_focus(),
		"Nach dem Schliessen kehrt der Fokus dorthin zurueck, wo er herkam")

	# Beim Szenenwechsel waere ein zurueckspringender Fokus falsch.
	host.open("pause")
	host.close()
	host.forget_focus()
	host.restore_focus()
	_check(not outside.has_focus(),
		"Ein verworfener Fokus wird nicht mehr wiederhergestellt")

	host.guard_focus(outside)
	_check(true, "Der Waechter bleibt bei geschlossenem Fenster folgenlos")
	owner.queue_free()
