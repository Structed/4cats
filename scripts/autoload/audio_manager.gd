## Zentrale Audio-Ausgabe mit einem kleinen Pool an AudioStreamPlayern.
##
## Autoload -- ueberall als `AudioManager` erreichbar.
## Sounds werden ueber einen kurzen Schluessel angesprochen, damit die
## Aufrufstellen nichts ueber Dateipfade wissen muessen.
extends Node

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const POOL_SIZE := 8

## Schluessel -> Dateipfad. Fehlende Dateien werden still uebersprungen,
## damit das Spiel auch ohne vollstaendige Assets laeuft.
const SFX_LIBRARY := {
	"ui_click": "res://assets/audio/ui_click.ogg",
	"ui_back": "res://assets/audio/ui_back.ogg",
	"pickup": "res://assets/audio/pickup.ogg",
	"meow": "res://assets/audio/meow.ogg",
	"deliver": "res://assets/audio/deliver.ogg",
	"care": "res://assets/audio/care.ogg",
	"adopt": "res://assets/audio/adopt.ogg",
	"scare": "res://assets/audio/scare.ogg",
	"coins": "res://assets/audio/coins.ogg",
}

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _cache: Dictionary = {}
var _missing_reported: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_apply_saved_volumes()


func play_sfx(key: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _get_stream(key)
	if stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


## Wie play_sfx, aber mit leicht zufaelliger Tonhoehe -- klingt weniger monoton.
func play_sfx_varied(key: String, spread: float = 0.12) -> void:
	play_sfx(key, randf_range(1.0 - spread, 1.0 + spread))


func _get_stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	if not SFX_LIBRARY.has(key):
		push_warning("Unbekannter Sound-Schluessel: %s" % key)
		return null
	var path: String = SFX_LIBRARY[key]
	if not ResourceLoader.exists(path):
		if not _missing_reported.has(key):
			_missing_reported[key] = true
			print_verbose("Sound fehlt noch: %s" % path)
		_cache[key] = null
		return null
	var stream: AudioStream = load(path)
	_cache[key] = stream
	return stream


# --- Lautstaerke ------------------------------------------------------------

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, is_zero_approx(linear))
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _apply_saved_volumes() -> void:
	var settings := SaveManager.load_settings()
	set_bus_volume("Master", float(settings.get("volume_master", 1.0)))
	set_bus_volume(SFX_BUS, float(settings.get("volume_sfx", 1.0)))
	set_bus_volume(MUSIC_BUS, float(settings.get("volume_music", 0.7)))
