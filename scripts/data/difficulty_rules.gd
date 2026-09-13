class_name DifficultyRules
extends RefCounted

const DEFAULT := "relaxed"
const IDS: PackedStringArray = ["relaxed", "challenging", "realistic"]
const WARNING_THRESHOLD := 20.0
const PROFILES := {
	"relaxed": {
		"title": "Entspannt",
		"description": "Kein Katzentod. Futter und Wasser sind kostenlos.\nVorräte holen und Näpfe füllen gehören trotzdem dazu.",
		"decay": 1.0, "damage": 1.0, "senior": 1.0, "grace": 0.0,
		"food_price": 0, "delivery_fee": 0, "delivery_seconds": 30.0,
	},
	"challenging": {
		"title": "Anspruchsvoll",
		"description": "Futter und Lieferungen kosten Münzen.\nKatzen können bei Vernachlässigung sterben. Senioren sind empfindlicher.",
		"decay": 1.15, "damage": 1.15, "senior": 1.5, "grace": 45.0,
		"food_price": 12, "delivery_fee": 5, "delivery_seconds": 45.0,
	},
	"realistic": {
		"title": "Realistisch",
		"description": "Mehr Pflegebedarf, höhere Kosten und kürzere Schonfrist.\nKatzen können bei Vernachlässigung sterben, besonders Senioren.",
		"decay": 1.4, "damage": 1.5, "senior": 1.8, "grace": 30.0,
		"food_price": 16, "delivery_fee": 6, "delivery_seconds": 60.0,
	},
}

static func title(id: String) -> String:
	return String(PROFILES[id]["title"])

static func description(id: String) -> String:
	return String(PROFILES[id]["description"])

static func value(id: String, key: String) -> float:
	return float(PROFILES[id][key])

static func allows_death(id: String) -> bool:
	return id != DEFAULT

