## Durchlauf durch die Rettungsszene samt Heimweg-Anzeige.
extends SmokeSuite

const NAVIGATION_ZOOMS: Array[Vector2] = [Vector2(2, 2), Vector2(1.5, 1.5)]


func run() -> void:
	await _test_rescue()

func _test_rescue() -> void:
	print("--- Rettungs-Level ---")
	GameState.reset()

	var level := await _load_scene("res://scenes/rescue/rescue_level.tscn")
	if level == null:
		return

	var player: Player = level.get_node("Player")
	var hud: Control = level.get_node("UI/HUD")
	var indicator := hud.get_node_or_null("HomeIndicator") as HomeIndicator
	_check(indicator != null, "Der Wegweiser ist Teil des Rettungs-HUD")
	if indicator != null:
		_check(indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Der Wegweiser faengt weder Maus noch Touch ab")
		_check(indicator.get_index() < hud.get_node("%PauseDim").get_index(),
			"Die Pausenabdunklung liegt ueber dem Wegweiser")
		_check_home_navigation(level, "ohne getragene Katze")
		await _test_home_navigation(level)

	# Pause auf und wieder zu.
	hud.call("toggle_pause")
	await _wait(0.2)
	_check(get_tree().paused, "Pause haelt das Spiel an")
	if indicator != null:
		_check_home_navigation(level, "in der Pause")
	hud.call("toggle_pause")
	await _wait(0.2)
	_check(not get_tree().paused, "Pause laesst sich wieder aufheben")

	# Aufheben ins Leere -- darf nicht knallen.
	level.call("_try_pick_up")
	await _wait(0.1)
	_check(true, "Aufheben ohne Katze in Reichweite bricht nichts")

	# Mit vollem Korb eine weitere Katze anfassen.
	while GameState.can_carry_more():
		GameState.pick_up_cat(CatData.create_random())
	level.call("_try_pick_up")
	await _wait(0.1)
	_check(true, "Aufheben mit vollem Korb bricht nichts")
	if indicator != null:
		_check_home_navigation(level, "mit vollem Korb")

	# Getragene Katzen erscheinen ueber dem Kopf.
	var carry_slot: Node2D = player.get_node("CarrySlot")
	_check(carry_slot.get_child_count() == GameState.carried_cats.size(),
		"Getragene Katzen werden angezeigt (%d)" % carry_slot.get_child_count())

	# Schreck: eine Katze entwischt und wird neu ausgesetzt.
	var before := GameState.carried_cats.size()
	var cats_before := get_tree().get_nodes_in_group("cats").size()
	var lost := player.startle()
	_check(lost != null, "Ein Schreck laesst eine Katze entwischen")
	if lost != null:
		level.call("on_cat_escaped", lost, player.global_position)
		await _wait(0.2)
		_check(GameState.carried_cats.size() == before - 1, "Der Korb enthaelt danach eine weniger")
		# Das Aussetzen laeuft verzoegert (Physik-Rueckruf) -- es muss trotzdem
		# tatsaechlich passieren.
		_check(get_tree().get_nodes_in_group("cats").size() == cats_before + 1,
			"Die entwischte Katze streunt wieder im Level")

	# Waehrend der Betaeubung darf ein zweiter Schreck nichts tun.
	var during_stun := player.startle()
	_check(during_stun == null, "Waehrend der Betaeubung erschrickt man nicht erneut")

	# Autos und Hunde einmal laufen lassen.
	await _wait(1.5)
	var cars := 0
	var dogs := 0
	for child in level.get_node("Entities").get_children():
		if child is Car:
			cars += 1
		elif child is Dog:
			dogs += 1
	_check(cars > 0, "Autos fahren im Level (%d)" % cars)
	_check(dogs > 0, "Hunde streunen im Level (%d)" % dogs)

	# Abliefern in der Heimzone.
	GameState.pick_up_cat(CatData.create_random())
	player.global_position = level.get_node("HomeZone").global_position
	await _wait(0.4)
	_check(GameState.carried_cats.is_empty(), "In der Heimzone werden Katzen abgegeben")
	if indicator != null:
		_check_home_navigation(level, "nach dem Abliefern")

	level.queue_free()
	await _wait(0.2)
	_check(not is_instance_valid(indicator), "Der Wegweiser endet mit der Rettungsszene")


func _test_home_navigation(level: Node) -> void:
	print("--- Wegweiser: Kamera, Fenster und Touch ---")
	var player: Player = level.get_node("Player")
	var camera: Camera2D = level.get_node("Player/Camera")
	var home_zone: Node2D = level.get_node("HomeZone")
	var touch: CanvasLayer = level.get_node("TouchControls")
	var window := get_tree().root
	var original_size := window.size
	var original_position := player.global_position
	var original_zoom := camera.zoom
	var original_smoothing := camera.position_smoothing_enabled
	var original_physics := player.is_physics_processing()
	var original_forced: bool = touch.call("is_forced")

	player.set_physics_process(false)
	camera.position_smoothing_enabled = false
	for window_size in UI_WINDOW_SIZES:
		window.size = window_size
		await _wait(0.1)
		_check(is_equal_approx(player.get_viewport_rect().size.aspect(), Vector2(window_size).aspect()),
			"Der Viewport uebernimmt das Fensterformat %s" % window_size)
		for zoom in NAVIGATION_ZOOMS:
			camera.zoom = zoom
			var positions: Array[Vector2] = [
				home_zone.global_position + Vector2(0, 32),
				Vector2(camera.limit_right - 32, 32),
				Vector2(camera.limit_right - 32, camera.limit_bottom - 32),
			]
			for position in positions:
				player.global_position = position
				camera.reset_smoothing()
				camera.force_update_scroll()
				touch.call("set_forced", false)
				await _wait(0.1)
				_check_home_navigation(level, "bei %s, Zoom %s" % [window_size, zoom])
				touch.call("set_forced", true)
				await _wait(0.1)
				_check_home_navigation(level, "mit Touch bei %s, Zoom %s" % [window_size, zoom])

	window.size = original_size
	camera.zoom = original_zoom
	player.global_position = original_position
	camera.force_update_scroll()
	camera.reset_smoothing()
	camera.position_smoothing_enabled = true
	await _wait(0.1)
	player.global_position += Vector2(150, 60)
	for i in 4:
		await _wait(0.03)
		_check_home_navigation(level, "waehrend der Kameranachfuehrung")

	player.global_position = original_position
	camera.position_smoothing_enabled = original_smoothing
	camera.reset_smoothing()
	camera.force_update_scroll()
	player.set_physics_process(original_physics)
	touch.call("set_forced", original_forced)
	await _wait(0.1)


func _check_home_navigation(level: Node, context: String) -> void:
	var hud: Control = level.get_node("UI/HUD")
	var indicator: HomeIndicator = hud.get_node("HomeIndicator")
	var home_zone: Node2D = level.get_node("HomeZone")
	_check(indicator.is_visible_in_tree() and indicator.is_processing()
		and bool(indicator.get("_has_target")), "Wegweiser bleibt sichtbar: %s" % context)

	var hud_inverse := indicator.get_global_transform_with_canvas().affine_inverse()
	var target: Vector2 = hud_inverse * home_zone.get_global_transform_with_canvas().origin
	var viewport_rect: Rect2 = hud_inverse * indicator.get_viewport_rect()
	var radius := Vector2.ONE * HomeIndicator.MARKER_RADIUS
	var marker_rect := Rect2(indicator.marker_position - radius, radius * 2.0)
	var direction := target - indicator.marker_position
	_check(indicator.marker_position.is_finite() and is_finite(indicator.marker_angle)
		and viewport_rect.encloses(marker_rect), "Pfeil bleibt vollstaendig im Bild: %s" % context)
	_check(direction.is_zero_approx()
		or Vector2.from_angle(indicator.marker_angle).dot(direction.normalized()) > 0.999,
		"Pfeil zeigt auf die tatsaechliche Bildschirmposition des Zuhauses: %s" % context)

	if viewport_rect.has_point(target):
		_check(indicator.marker_position.distance_to(target) < 160.0,
			"Sichtbares Zuhause wird direkt markiert: %s" % context)
	else:
		var bounds := viewport_rect.grow(-HomeIndicator.MARKER_RADIUS - HomeIndicator.EDGE_GAP)
		var position := indicator.marker_position
		_check(is_equal_approx(position.x, bounds.position.x)
			or is_equal_approx(position.x, bounds.end.x)
			or is_equal_approx(position.y, bounds.position.y)
			or is_equal_approx(position.y, bounds.end.y),
			"Nicht sichtbares Zuhause bekommt einen Randpfeil: %s" % context)

	var controls: Array[Control] = [
		hud.get_node("TopLeft"), hud.get_node("%HomeButton"), hud.get_node("%HintLabel"),
		level.get_node("HomeZone/Label"), level.get_node("TouchControls/Root/Joystick"),
		level.get_node("TouchControls/Root/ActionButton"), level.get_node("TouchControls/Root/SprintButton"),
	]
	var clear := true
	for control in controls:
		if control.is_visible_in_tree():
			var rect: Rect2 = (hud_inverse * control.get_global_transform_with_canvas()
				* Rect2(Vector2.ZERO, control.size))
			if marker_rect.intersects(rect.grow(HomeIndicator.UI_GAP - 0.01)):
				clear = false
	_check(clear, "Wegweiser laesst HUD, Beschriftung und Touch-Bedienung frei: %s" % context)

