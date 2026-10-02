class_name SfxDirector
extends Node
## Sim and view events -> sound effects (design.md DS-SFX-01). A fixed pool of players; the
## oldest voice is stolen when all are busy. Hits sound like the weapon that landed them (HitSounds).

const VOICES := 12
const LAND_QUIET_DB := -14.0

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
	for name: String in sound_names():
		var path := SfxRecipes.stream_path(name)
		if ResourceLoader.exists(path):
			_streams[name] = load(path)


## Every playable sound: the recipes plus the designed weapon hits, each once.
static func sound_names() -> Array[String]:
	var names: Array[String] = []
	for name: String in SfxRecipes.RECIPES.keys() + HitSounds.NAMES:
		if not names.has(name):
			names.append(name)
	return names


## decor_lake: the arena has the classic meadow lake (ring-outs over it splash).
## attacker_style: the hitter's style id ("" = unknown), which picks the weapon's hit sound.
static func sound_for(event: Dictionary, config: GameConfig, decor_lake: bool = false,
		attacker_style: String = "") -> Dictionary:
	match String(event["type"]):
		"hit":
			return HitSounds.for_hit(event, attacker_style, config)
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
		"item_pickup", "item_throw", "explosion", "slip":
			return {"name": String(event["type"]), "pitch": 1.0, "volume_db": 0.0}
	return {}


## The arena being played (ring-outs splash only where there is water).
func set_arena(arena_id: String) -> void:
	_decor_lake = ArenaDressings.has_decor_lake(arena_id)


## The style id of fighter `id` in the view's fighters, or "" (unknown, e.g. no owner).
static func style_of(id: int, fighters: Array) -> String:
	for f: Dictionary in fighters:
		if int(f.get("id", -1)) == id:
			return String(f.get("style", ""))
	return ""


## fighters: the view's fighter dictionaries, so hits sound like the attacker's weapon.
func on_events(events: Array, fighters: Array = []) -> void:
	for e: Dictionary in events:
		var style := style_of(int(e.get("attacker", -1)), fighters) if String(e["type"]) == "hit" else ""
		var s := sound_for(e, _config, _decor_lake, style)
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
