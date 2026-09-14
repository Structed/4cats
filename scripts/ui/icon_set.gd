## Zuordnung von Knopfnamen zu Symbolen im UI-Atlas.
##
## Hier -- und nur hier -- entscheidet sich, welcher Knopf welches Symbol
## bekommt. Ein Symbol zu ergaenzen ist deshalb ein Eintrag in `BUTTON_ICONS`
## und keine Aenderung an der Stelle, an der der Knopf gebaut wird.
##
## Der Atlas wird erzeugt, nicht von Hand gepflegt:
##     pwsh tools/generate_ui_icons.ps1
##
## Fehlt der Atlas, liefert `texture()` null und alle Knoepfe bleiben bei ihrer
## Beschriftung. Das Spiel laeuft dann unveraendert weiter.
class_name IconSet
extends RefCounted

const ATLAS_PATH := "res://assets/sprites/ui_icons.png"

## Kantenlaenge einer Zelle im Atlas.
const CELL := 16

## Symbolname -> Spalte im Atlas. Die Reihenfolge muss zu
## `tools/generate_ui_icons.ps1` passen.
const ICONS := {
	"furnish": 0,
	"supplies": 1,
	"upgrade": 2,
	"pause": 3,
	"close": 4,
	"resume": 5,
	"menu": 6,
	"home": 7,
	"cart": 8,
	"emergency": 9,
	"rotate": 10,
	"store": 11,
	"action": 12,
	"sprint": 13,
	"play": 14,
	"new": 15,
	"options": 16,
	"quit": 17,
	"credits": 18,
	"accept": 19,
	"decline": 20,
	"info": 21,
	"coins": 22,
	"food": 23,
	"water": 24,
	"wash": 25,
	"vet": 26,
	"toy": 27,
	"litter": 28,
	"pantry": 29,
	"faucet": 30,
}

## Knotenname -> Symbolname. Die Knotennamen sind stabil; die Testsuiten
## greifen ueber dieselben Namen auf die Knoepfe zu.
const BUTTON_ICONS := {
	"FurnishButton": "furnish",
	"SupplyButton": "supplies",
	"ShopButton": "upgrade",
	"PauseButton": "pause",
	"ModalCloseButton": "close",
	"CloseShopButton": "close",
	"CreditsCloseButton": "close",
	"OptionsCloseButton": "close",
	"ResumeButton": "resume",
	"MenuButton": "menu",
	"ToMenuButton": "menu",
	"HomeButton": "home",
	"ToHomeButton": "home",
	"OrderFoodButton": "cart",
	"BuyFoodButton": "cart",
	"EmergencyFoodButton": "emergency",
	"RotateButton": "rotate",
	"StoreButton": "store",
	"ActionButton": "action",
	"SprintButton": "sprint",
	"ContinueButton": "play",
	"NewGameButton": "new",
	"OptionsButton": "options",
	"QuitButton": "quit",
	"CreditsButton": "credits",
	"AnalyticsButton": "info",
	"ConfirmYesButton": "accept",
	"ConfirmNoButton": "decline",
	"Accept": "accept",
	"Decline": "decline",
	"PrivacyDetails": "info",
}

## Praefix -> Symbolname fuer Knoepfe, die je Gegenstand entstehen. Ein leerer
## Wert heisst: der Rest des Knotennamens ist selbst der Symbolname
## (z.B. "Buy_food" -> "food").
const BUTTON_PREFIXES := {
	"Buy_": "",
	"Upgrade_": "upgrade",
}

static var _cache: Dictionary = {}


## Symbolname fuer einen Knotennamen, oder "" wenn keiner hinterlegt ist.
static func for_button(node_name: String) -> String:
	if BUTTON_ICONS.has(node_name):
		return String(BUTTON_ICONS[node_name])
	for prefix: String in BUTTON_PREFIXES:
		if not node_name.begins_with(prefix):
			continue
		var mapped: String = String(BUTTON_PREFIXES[prefix])
		if not mapped.is_empty():
			return mapped
		var derived := node_name.trim_prefix(prefix)
		return derived if ICONS.has(derived) else ""
	return ""


## Textur fuer ein Symbol, oder null wenn der Atlas oder das Symbol fehlt.
static func texture(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not ICONS.has(icon_name):
		return null
	if _cache.has(icon_name):
		return _cache[icon_name] as Texture2D
	if not ResourceLoader.exists(ATLAS_PATH):
		return null
	var atlas := load(ATLAS_PATH) as Texture2D
	if atlas == null:
		return null
	var column: int = ICONS[icon_name]
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2(column * CELL, 0, CELL, CELL)
	_cache[icon_name] = region
	return region


## Verwirft zwischengespeicherte Texturen -- fuer Tests, die den Atlas tauschen.
static func clear_cache() -> void:
	_cache.clear()
