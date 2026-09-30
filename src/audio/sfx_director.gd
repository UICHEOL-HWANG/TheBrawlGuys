class_name SfxDirector
extends Node
## Sim and view events -> sound effects (design.md DS-SFX-01). A fixed pool of players; the
## oldest voice is stolen when all are busy. Hit pitch and loudness follow the knockback.

const VOICES := 12
const LIGHT_HIT_VOLUME_DB := -4.0
const LAND_QUIET_DB := -14.0
const MIN_PITCH := 0.7
const MAX_PITCH := 1.2
const BASE_PITCH := 1.15

var _config: GameConfig
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}
var _decor_lake: bool = ArenaDressings.has_decor_lake(ArenaCatalog.DEFAULT_ID)


func setup(config: GameConfig) -> void:
	_config = config
	AudioBuses.ensure(config)
	for i: int in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for name: String in SfxRecipes.RECIPES:
		var path := SfxRecipes.path(name)
		if ResourceLoader.exists(path):
			_streams[name] = load(path)


## decor_lake: the arena has the classic meadow lake (ring-outs over it splash).
static func sound_for(event: Dictionary, config: GameConfig, decor_lake: bool = false) -> Dictionary:
	match String(event["type"]):
		"hit":
			var k := float(event["knockback"])
			var heavy := k >= config.spark_large_threshold
			return {"name": "hit_heavy" if heavy else "hit_light",
				"pitch": clampf(BASE_PITCH - k * config.sfx_pitch_per_knockback, MIN_PITCH, MAX_PITCH),
				"volume_db": 0.0 if heavy else LIGHT_HIT_VOLUME_DB}
		"guard_hit":
			return {"name": "guard", "pitch": 1.0, "volume_db": 0.0}
		"ringout":
			var lake := DecorView.is_water_ringout(event, config.arena_radius, decor_lake)
			return {"name": "ringout_splash" if lake else "ringout_whistle", "pitch": 1.0, "volume_db": 0.0}
		"landed":
			return {"name": "land", "pitch": 1.0, "volume_db": lerpf(LAND_QUIET_DB, 0.0, float(event["intensity"]))}
		"jumped":
			return {"name": "jump", "pitch": 1.0, "volume_db": 0.0}
		"respawned":
			return {"name": "respawn", "pitch": 1.0, "volume_db": 0.0}
		"item_pickup", "item_throw", "explosion":
			return {"name": String(event["type"]), "pitch": 1.0, "volume_db": 0.0}
	return {}


## The arena being played (ring-outs splash only where there is water).
func set_arena(arena_id: String) -> void:
	_decor_lake = ArenaDressings.has_decor_lake(arena_id)


func on_events(events: Array) -> void:
	for e: Dictionary in events:
		var s := sound_for(e, _config, _decor_lake)
		if not s.is_empty():
			play(String(s["name"]), float(s["pitch"]), float(s["volume_db"]))


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0, bus: String = AudioBuses.SFX) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stop()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.bus = bus
	p.play()


func play_ui(name: String) -> void:
	play(name, 1.0, 0.0, AudioBuses.UI)


func voices() -> int:
	return _players.size()


## Index of the voice the next play() will take (read-only, for tests).
func next_voice() -> int:
	return _next


## The stream a voice last played, or null if it was never used.
func voice_stream(index: int) -> AudioStream:
	return _players[index].stream
