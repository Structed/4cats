class_name NeedsSimulation
extends RefCounted
## Wie Beduerfnisse, Gesundheit und Genesung der Hauskatzen ueber die Zeit laufen.
##
## Eigene Datei, weil hier die Pflegeregeln stehen: Abbauraten, Lebensgefahr,
## Schonfrist und Vermittlung. Wer an diesen Regeln schraubt, fasst nur diese
## Datei an -- der Spielzustand meldet die Ergebnisse nur noch weiter.

## Abbau pro Sekunde bei Upgrade-Stufe 0.
const DECAY_HUNGER := 0.30
const DECAY_THIRST := 0.40
const DECAY_CLEANLINESS := 0.15

## Zusatzschaden auf die Gesundheit, wenn Hunger oder Durst bei 0 stehen.
const HEALTH_DECAY_WHEN_STARVING := 0.5

## Katzen, die im letzten step() vermittelt wurden.
var adopted: Array[CatData] = []

## Katzen, die im letzten step() gestorben sind.
var deceased: Array[CatData] = []

## true, wenn eine Katze in Lebensgefahr geriet oder sich wieder erholt hat.
var care_event: bool = false

## Katzen-Id -> steht in Lebensgefahr.
var _critical: Dictionary = {}


## Merkt sich, welche Katzen bereits in Lebensgefahr sind (neues Spiel, Laden).
func rebuild(cats: Array[CatData], mode: String) -> void:
	_critical.clear()
	if not DifficultyRules.allows_death(mode):
		return
	for cat in cats:
		if cat.is_starving() and is_zero_approx(cat.health):
			_critical[cat.id] = true


## Vergisst eine Katze, die das Haus verlassen hat.
func forget(cat_id: String) -> void:
	_critical.erase(cat_id)


## Laesst Zeit vergehen. `decay` und `recovery_speed` bringen die Ausbauten und
## den Schwierigkeitsgrad mit; das Melden der Ergebnisse bleibt beim Spielzustand.
func step(delta: float, cats: Array[CatData], simulation: HomeSimulation,
		mode: String, decay: float, recovery_speed: float, stats: GameplayStats) -> void:
	adopted.clear()
	deceased.clear()
	care_event = false
	var already_critical := {}
	for cat in cats:
		already_critical[cat.id] = cat.is_starving() and is_zero_approx(cat.health)
		cat.hunger = maxf(cat.hunger - DECAY_HUNGER * decay, 0.0)
		cat.thirst = maxf(cat.thirst - DECAY_THIRST * decay, 0.0)
		cat.cleanliness = maxf(cat.cleanliness - DECAY_CLEANLINESS * decay, 0.0)
		cat.enrichment = maxf(cat.enrichment - HomeSimulation.DECAY_ENRICHMENT * decay, 0.0)

		# Die Gesundheit faellt nur, wenn die Katze wirklich vernachlaessigt wird.
		if cat.is_starving():
			var damage := DifficultyRules.value(mode, "damage")
			if cat.age_group == CatData.Age.SENIOR:
				damage *= DifficultyRules.value(mode, "senior")
			cat.health = maxf(cat.health - HEALTH_DECAY_WHEN_STARVING * decay * damage, 0.0)
	simulation.step(delta)
	for cat in cats:
		if DifficultyRules.allows_death(mode) and cat.is_starving() \
				and is_zero_approx(cat.health):
			if not _critical.has(cat.id):
				_critical[cat.id] = true
				stats.record("cat_became_critical")
				care_event = true
			# Der Schritt, der Gesundheit auf null senkt, verbraucht keine Schonfrist.
			if bool(already_critical[cat.id]):
				cat.critical_elapsed += delta
			if cat.critical_elapsed >= DifficultyRules.value(mode, "grace"):
				deceased.append(cat)
				continue
		else:
			if _critical.erase(cat.id):
				stats.record("cat_recovered_from_critical")
				care_event = true
			cat.critical_elapsed = 0.0
		if cat.all_needs_met():
			cat.recovery_timer += delta * recovery_speed
			if cat.recovery_timer >= CatData.RECOVERY_SECONDS \
					and simulation.held_cat_id != cat.id:
				adopted.append(cat)
		else:
			# Rueckschlag, aber nicht komplett bei null anfangen.
			cat.recovery_timer = maxf(cat.recovery_timer - delta * 2.0, 0.0)

