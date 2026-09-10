## Karte einer Katze zu Hause: Zustand anzeigen und pflegen.
##
## Jede Pflegeaktion hat eine kurze Abklingzeit, damit man nicht einfach alles
## in einer Sekunde hochtippt.
extends PanelContainer

const COOLDOWN := 2.5

## Aktions-Id -> (Beduerfnis, Menge, Beschriftung)
const ACTIONS := {
	"feed": { "need": "hunger", "amount": 30.0, "label": "Füttern" },
	"water": { "need": "thirst", "amount": 30.0, "label": "Tränken" },
	"wash": { "need": "cleanliness", "amount": 34.0, "label": "Waschen" },
	"heal": { "need": "health", "amount": 22.0, "label": "Verarzten" },
}

const NEED_LABELS := {
	"hunger": "Hunger",
	"thirst": "Durst",
	"cleanliness": "Sauberkeit",
	"health": "Gesundheit",
}

const NEED_COLORS := {
	"hunger": Color(0.94, 0.72, 0.35),
	"thirst": Color(0.42, 0.72, 0.95),
	"cleanliness": Color(0.68, 0.85, 0.92),
	"health": Color(0.55, 0.86, 0.55),
}

@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _needs_box: GridContainer = %NeedsBox
@onready var _buttons_box: HBoxContainer = %ButtonsBox
@onready var _recovery_bar: ProgressBar = %RecoveryBar
@onready var _recovery_label: Label = %RecoveryLabel
@onready var _recovery_details: Label = %RecoveryDetails

var cat: CatData

var _bars: Dictionary = {}
var _need_labels: Dictionary = {}
var _buttons: Dictionary = {}
var _cooldowns: Dictionary = {}


func _ready() -> void:
	_build_needs()
	_build_buttons()
	_apply_portrait()
	refresh()


func _process(delta: float) -> void:
	var changed := false
	for key: String in _cooldowns.keys():
		var remaining: float = _cooldowns[key]
		if remaining > 0.0:
			_cooldowns[key] = maxf(remaining - delta, 0.0)
			changed = true
	if changed:
		_update_buttons()
	refresh()


func _apply_portrait() -> void:
	if cat == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/cats.png")
	atlas.region = Rect2(0, cat.fur_variant * 16, 16, 16)
	_portrait.texture = atlas


func _build_needs() -> void:
	# Vier Beduerfnisse in zwei Spalten -- so bleibt die Karte auch auf
	# Handys im Querformat flach genug.
	for need_key: String in NEED_LABELS:
		var label := Label.new()
		label.name = "%sValue" % need_key.capitalize()
		label.text = String(NEED_LABELS[need_key])
		label.custom_minimum_size = Vector2(64.0, 0.0)
		label.add_theme_font_size_override("font_size", 10)
		_needs_box.add_child(label)
		_need_labels[need_key] = label

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = CatData.NEED_MAX
		bar.step = 0.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(90.0, 9.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var color: Color = NEED_COLORS[need_key]
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)

		_needs_box.add_child(bar)
		_bars[need_key] = bar


func _build_buttons() -> void:
	for action_id: String in ACTIONS:
		var button := Button.new()
		button.text = String(ACTIONS[action_id]["label"])
		button.add_theme_font_size_override("font_size", 10)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action.bind(action_id))
		_buttons_box.add_child(button)
		_buttons[action_id] = button
		_cooldowns[action_id] = 0.0


func _on_action(action_id: String) -> void:
	if cat == null or _cooldowns.get(action_id, 0.0) > 0.0:
		return
	var action: Dictionary = ACTIONS[action_id]
	var need: String = action["need"]
	var amount: float = action["amount"]

	match need:
		"hunger": cat.hunger = minf(cat.hunger + amount, CatData.NEED_MAX)
		"thirst": cat.thirst = minf(cat.thirst + amount, CatData.NEED_MAX)
		"cleanliness": cat.cleanliness = minf(cat.cleanliness + amount, CatData.NEED_MAX)
		"health": cat.health = minf(cat.health + amount, CatData.NEED_MAX)

	_cooldowns[action_id] = COOLDOWN
	AudioManager.play_sfx_varied("care")
	_update_buttons()
	refresh()


func refresh() -> void:
	if cat == null:
		return
	_name_label.text = "%s  ·  Wohlbefinden: %d %%" % [cat.cat_name, int(round(cat.wellbeing()))]
	var needs: Dictionary = cat.needs()
	var missing_needs: PackedStringArray = []
	for need_key: String in _bars:
		var value: float = needs[need_key]
		(_bars[need_key] as ProgressBar).value = value
		var label: Label = _need_labels[need_key]
		label.text = "%s: %d/%d" % [
			String(NEED_LABELS[need_key]), floori(value), int(CatData.NEED_MAX)
		]
		if value < CatData.RECOVERY_THRESHOLD:
			missing_needs.append(String(NEED_LABELS[need_key]))

	_recovery_bar.value = cat.recovery_progress() * 100.0
	var progress := floori(cat.recovery_progress() * 100.0)
	var threshold := int(CatData.RECOVERY_THRESHOLD)
	if cat.all_needs_met():
		_recovery_label.text = "Genesung: %d %% · Automatische Vermittlung in ca. %d s" % [
			progress, ceili(GameState.recovery_seconds_remaining(cat))
		]
		_recovery_details.text = "Alle vier Werte mindestens %d halten." % threshold
	elif cat.recovery_timer > 0.0:
		_recovery_label.text = "Genesung unterbrochen · %d %%" % progress
		_recovery_details.text = "Fehlt: %s. Fortschritt sinkt.\nAlle vier Werte mindestens %d." % [
			", ".join(missing_needs), threshold
		]
	else:
		_recovery_label.text = "Pflege fehlt · Genesung: %d %%" % progress
		_recovery_details.text = "Fehlt: %s.\nAlle vier Werte mindestens %d." % [
			", ".join(missing_needs), threshold
		]


func _update_buttons() -> void:
	for action_id: String in _buttons:
		var button: Button = _buttons[action_id]
		var remaining: float = _cooldowns.get(action_id, 0.0)
		button.disabled = remaining > 0.0
		if remaining > 0.0:
			button.text = "%.1f s" % remaining
		else:
			button.text = String(ACTIONS[action_id]["label"])
