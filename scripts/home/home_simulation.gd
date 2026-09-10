class_name HomeSimulation
extends RefCounted

signal care_finished(cat_id: String, kind: String)

const WALK_SPEED := 22.0
const CARE_SECONDS := 2.2
const TOILET_INTERVAL := 42.0
const TOILET_OVERDUE := 65.0
const DECAY_ENRICHMENT := 0.22
const DURATIONS := {"food": 1.6, "water": 1.3, "toy": 3.0, "litter": 2.0}
const TASK_NEEDS := {"food": "hunger", "water": "thirst", "toy": "enrichment"}

var data: HomeData
var layout: HomeLayout
var held_cat_id: String = ""
var _cats: Array[CatData]
var _reservations: Dictionary = {}
var _wander_sequence: int = 0

func _init(home: HomeData, cats: Array[CatData]) -> void:
	data = home
	_cats = cats
	layout = HomeLayout.new(home)
	sync_cats()

func sync_cats() -> void:
	var alive := {}
	for cat in _cats:
		alive[cat.id] = true
		if not data.cats.has(cat.id):
			var state := HomeCatState.new()
			state.position = layout.free_position(data.cats.size())
			state.wait_time = float(data.cats.size()) * 0.15
			data.cats[cat.id] = state
	for id: String in data.cats.keys():
		if not alive.has(id):
			_release_reservation(id)
			data.cats.erase(id)
			if held_cat_id == id:
				held_cat_id = ""

func cat_by_id(id: String) -> CatData:
	for cat in _cats:
		if cat.id == id:
			return cat
	return null

func is_caring() -> bool:
	if held_cat_id.is_empty() or not data.cats.has(held_cat_id):
		return false
	var state: HomeCatState = data.cats[held_cat_id]
	return state.task == "wash" or state.task == "vet"

func item_in_use(id: String) -> bool:
	if not _reservations.has(id):
		return false
	var cat_id: String = _reservations[id]
	if not data.cats.has(cat_id):
		return false
	var state: HomeCatState = data.cats[cat_id]
	return state.path.is_empty()

func rebuild_layout() -> void:
	layout.rebuild()
	_reservations.clear()
	for id: String in data.cats:
		var state: HomeCatState = data.cats[id]
		if id != held_cat_id:
			state.clear_task()
	if is_caring():
		var held: HomeCatState = data.cats[held_cat_id]
		_reservations[held.target_id] = held_cat_id

func pick_up(id: String) -> bool:
	if not held_cat_id.is_empty() or not data.cats.has(id):
		return false
	_release_reservation(id)
	var state: HomeCatState = data.cats[id]
	state.clear_task()
	state.task = "held"
	held_cat_id = id
	return true

func drop(position: Vector2) -> bool:
	if held_cat_id.is_empty() or layout.blocked(HomeCatalog.cell(position)):
		return false
	cancel_care()
	var state: HomeCatState = data.cats[held_cat_id]
	state.position = HomeCatalog.world(HomeCatalog.cell(position))
	state.clear_task()
	held_cat_id = ""
	return true

func begin_care(item: HomeItemData) -> bool:
	if held_cat_id.is_empty() or is_caring() or not item.placed \
			or item.kind not in ["wash", "vet"] or _reservations.has(item.id):
		return false
	var state: HomeCatState = data.cats[held_cat_id]
	state.task = item.kind
	state.target_id = item.id
	state.elapsed = 0.0
	_reservations[item.id] = held_cat_id
	return true

func cancel_care() -> void:
	if not is_caring():
		return
	_release_reservation(held_cat_id)
	var state: HomeCatState = data.cats[held_cat_id]
	state.clear_task()
	state.task = "held"

func step(delta: float) -> void:
	sync_cats()
	var ordered: Array[CatData] = _cats.duplicate()
	ordered.sort_custom(func(a: CatData, b: CatData) -> bool:
		var first: HomeCatState = data.cats[a.id]
		var second: HomeCatState = data.cats[b.id]
		return first.wait_time > second.wait_time)
	for cat in ordered:
		var state: HomeCatState = data.cats[cat.id]
		state.motion = Vector2.ZERO
		state.toilet_elapsed += delta
		if state.toilet_elapsed >= TOILET_OVERDUE:
			cat.cleanliness = maxf(0.0, cat.cleanliness - delta * 0.9)
		if state.task in ["wash", "vet"]:
			state.elapsed += delta
			if state.elapsed >= CARE_SECONDS:
				var kind := state.task
				if kind == "wash":
					cat.cleanliness = CatData.NEED_MAX
				else:
					cat.health = CatData.NEED_MAX
				_release_reservation(cat.id)
				state.clear_task()
				state.task = "held"
				care_finished.emit(cat.id, kind)
			continue
		if state.task == "held":
			continue
		if not state.path.is_empty():
			_move(state, delta)
			continue
		if not state.target_id.is_empty():
			_use(cat, state, delta)
			continue
		state.wait_time += delta
		state.elapsed -= delta
		if state.elapsed <= 0.0:
			_choose_task(cat, state)

func _move(state: HomeCatState, delta: float) -> void:
	var budget := WALK_SPEED * delta
	var start := state.position
	while budget > 0.0 and not state.path.is_empty():
		var target := state.path[0]
		var distance := state.position.distance_to(target)
		if distance <= budget:
			state.position = target
			state.path.remove_at(0)
			budget -= distance
		else:
			state.position = state.position.move_toward(target, budget)
			budget = 0.0
	state.motion = state.position - start

func _choose_task(cat: CatData, state: HomeCatState) -> void:
	var requests: Array[String] = []
	if state.toilet_elapsed >= TOILET_INTERVAL:
		requests.append("litter")
	var needs: Array[String] = ["food", "water", "toy"]
	needs.sort_custom(func(a: String, b: String) -> bool:
		return _need(cat, a) < _need(cat, b))
	for kind in needs:
		if _need(cat, kind) < 90.0:
			requests.append(kind)
	for kind in requests:
		if _find_station(cat.id, state, kind):
			return
	# Kurze Wartewege statt jeden Frame erfolglos alle Stationen abzufragen.
	state.task = "wander"
	state.elapsed = 0.7 + float(_wander_sequence % 4) * 0.2
	_wander_sequence += 1
	var target := layout.free_position(_wander_sequence)
	if state.wait_time < 2.0 or requests.is_empty():
		state.path = layout.path(state.position, HomeCatalog.cell(target))

func _find_station(cat_id: String, state: HomeCatState, kind: String) -> bool:
	var best: HomeItemData
	var best_path := PackedVector2Array()
	var shortest := INF
	for item in data.items:
		if not item.placed or item.kind != kind or _reservations.has(item.id):
			continue
		if kind in ["food", "water"] and item.stock <= 0:
			continue
		if kind == "litter" and item.dirt >= HomeCatalog.capacity(kind):
			continue
		var route := layout.path(state.position, item.port())
		if not route.is_empty() and route.size() < shortest:
			best = item
			best_path = route
			shortest = route.size()
	if best == null:
		return false
	state.task = kind
	state.target_id = best.id
	state.path = best_path
	state.elapsed = 0.0
	state.wait_time = 0.0
	_reservations[best.id] = cat_id
	return true

func _use(cat: CatData, state: HomeCatState, delta: float) -> void:
	var item := data.item_by_id(state.target_id)
	if item == null or not item.placed:
		_release_reservation(cat.id)
		state.clear_task()
		return
	state.elapsed += delta
	var duration: float = DURATIONS[state.task]
	if state.elapsed < duration:
		return
	match state.task:
		"food":
			if item.stock > 0:
				item.stock -= 1
				cat.hunger = minf(CatData.NEED_MAX, cat.hunger + 45.0)
		"water":
			if item.stock > 0:
				item.stock -= 1
				cat.thirst = minf(CatData.NEED_MAX, cat.thirst + 45.0)
		"toy":
			cat.enrichment = CatData.NEED_MAX
		"litter":
			item.dirt = mini(item.dirt + 1, HomeCatalog.capacity("litter"))
			state.toilet_elapsed = 0.0
	# Eine Mahlzeit darf mehrere Portionen brauchen. Halb satt wieder quer
	# durchs Haus zu laufen benachteiligt Katzen, die lange anstehen mussten.
	if state.task in ["food", "water"] and item.stock > 0 and _need(cat, state.task) < 98.0:
		state.elapsed = 0.0
		return
	_release_reservation(cat.id)
	state.clear_task()

func _release_reservation(cat_id: String) -> void:
	for id: String in _reservations.keys():
		if _reservations[id] == cat_id:
			_reservations.erase(id)

func _need(cat: CatData, kind: String) -> float:
	var key: String = TASK_NEEDS[kind]
	return float(cat.get(key))
