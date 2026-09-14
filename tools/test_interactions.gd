## Prueft die bedienbaren Gegenstaende im Haus.
##
## Aufruf ueber tools/test_gameplay.gd (`--test`).
##
## Der Test baut keine Szene: Interaktionen sollen genau deshalb ohne das
## halbe Haus pruefbar sein.
extends RefCounted

## Die Arten, die frueher fest in home_scene.gd standen. Faellt eine aus dem
## Verzeichnis, ist sie im Spiel stumm -- ohne dass etwas abstuerzt.
const EXPECTED_KINDS: PackedStringArray = [
	"food", "water", "litter", "pantry", "faucet", "wash", "vet",
]

var _failures: PackedStringArray = []
var _toasts: PackedStringArray = []


func run(_tree: SceneTree) -> PackedStringArray:
	_failures = []
	if GameState.home_simulation == null:
		_failures.append("Interaktions-Test: GameState ist nicht eingerichtet.")
		return _failures
	_test_registry()
	_test_hints()
	_test_cargo_texts()
	return _failures


func _test_registry() -> void:
	var kinds := InteractionRegistry.kinds()
	for kind in EXPECTED_KINDS:
		_check(InteractionRegistry.has(kind),
			"Gegenstandsart „%s“ ist nicht mehr bedienbar." % kind)
		_check(InteractionRegistry.handler(kind) is ItemInteraction,
			"Gegenstandsart „%s“ liefert keine Interaktion." % kind)
	for kind in kinds:
		_check(EXPECTED_KINDS.has(kind),
			"Unerwartete Gegenstandsart im Verzeichnis: %s" % kind)
		_check(HomeCatalog.KINDS.has(kind),
			"Gegenstandsart „%s“ kennt der Katalog nicht." % kind)
	# Je Art genau eine Instanz -- die Interaktionen sind zustandslos.
	for kind in kinds:
		_check(InteractionRegistry.handler(kind) == InteractionRegistry.handler(kind),
			"Gegenstandsart „%s“ wird bei jedem Zugriff neu gebaut." % kind)


func _test_hints() -> void:
	var context := InteractionContext.new(GameState.home_simulation,
		_record_toast, _ignore_supply, _ignore_save)
	for kind in EXPECTED_KINDS:
		var handler := InteractionRegistry.handler(kind)
		var item := HomeItemData.new()
		item.id = "test_" + kind
		item.kind = kind
		item.stock = 0
		item.dirt = 0
		context.item = item
		for holding in [false, true]:
			context.holding = holding
			var text := handler.hint(context)
			_check(not text.is_empty(),
				"Gegenstandsart „%s“ liefert keinen Hinweis (Katze: %s)." % [kind, holding])
			_check(text.contains("\n"),
				"Hinweis fuer „%s“ hat keine zweite Zeile." % kind)
			_check(not text.begins_with("\n"),
				"Hinweis fuer „%s“ hat keine Ueberschrift." % kind)


func _test_cargo_texts() -> void:
	for kind in ["food", "water", "package"]:
		_check(not SupplyCatalog.cargo_destination(kind).is_empty(),
			"Getragenes „%s“ hat kein Ziel." % kind)
		_check(not SupplyCatalog.cargo_return_hint(kind).is_empty(),
			"Getragenes „%s“ hat keinen Rueckgabe-Hinweis." % kind)
	_check(SupplyCatalog.cargo_destination("").is_empty(),
		"Freie Haende duerfen kein Ziel haben.")


func _record_toast(text: String) -> void:
	_toasts.append(text)


func _ignore_supply(_error: String, _message: String, _sound: String) -> void:
	pass


func _ignore_save() -> void:
	pass


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
