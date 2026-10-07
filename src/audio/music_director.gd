class_name MusicDirector
extends Node
## BGM (design.md DS-SFX-02, context F10): the battle theme is the base loop and the intensity
## layer on two players started together; the layer fades in while someone is on their last
## stock. Two plain players, not an AudioStreamSynchronized: on the web build a plain player is a
## Web Audio sample, while a synchronized stream goes through the engine's own mixer, which
## stutters on a single-threaded build. The menu variation is a separate loop. Files named
## battle_base / battle_intense / menu under assets/music can be replaced by the real soundtrack
## (.ogg preferred, .wav placeholder).

const SILENT_DB := -60.0
const NAMES: Array[String] = ["battle_base", "battle_intense", "menu"]

var _config: GameConfig
var _base: AudioStreamPlayer
var _layer: AudioStreamPlayer
var _battle_base: AudioStream
var _battle_layer: AudioStream
var _menu: AudioStream
var _intense: bool = false
var _layer_db: float = SILENT_DB


static func path_for(name: String) -> String:
	var ogg := "res://assets/music/%s.ogg" % name
	return ogg if ResourceLoader.exists(ogg) else "res://assets/music/%s.wav" % name


static func wants_intense(view: Dictionary) -> bool:
	if bool(view.get("match_over", false)):
		return false
	for f: Dictionary in view["fighters"]:
		if int(f["state"]) != Fighter.State.KO and int(f["stocks"]) == 1:
			return true
	return false


func setup(config: GameConfig) -> void:
	_config = config
	AudioBuses.ensure(config, SettingsStore.new())
	_base = _new_player()
	_layer = _new_player()
	_battle_base = _looped(load(path_for("battle_base")))
	_battle_layer = _looped(load(path_for("battle_intense")))
	_menu = _looped(load(path_for("menu")))


## Base and layer start in the same frame, so they stay on the beat together.
func play_battle() -> void:
	_intense = false
	_layer_db = SILENT_DB
	_base.stream = _battle_base
	_layer.stream = _battle_layer
	_layer.volume_db = SILENT_DB
	_base.play()
	_layer.play()


func play_menu() -> void:
	_layer.stop()
	_base.stream = _menu
	_base.play()


func stop() -> void:
	_base.stop()
	_layer.stop()


func update_from(view: Dictionary) -> void:
	_intense = wants_intense(view)


func is_intense() -> bool:
	return _intense


func intense_target_db() -> float:
	return 0.0 if _intense else SILENT_DB


## The player of the base loop (and the menu loop); read-only, for tests.
func base_player() -> AudioStreamPlayer:
	return _base


## The player of the intensity layer; read-only, for tests.
func layer_player() -> AudioStreamPlayer:
	return _layer


func _process(delta: float) -> void:
	if _base == null or _base.stream != _battle_base:
		return  # the layer only matters in battle; not `playing`, which a web sample may misreport
	var rate := (0.0 - SILENT_DB) / maxf(_config.music_intense_fade, 0.01)
	var next := move_toward(_layer_db, intense_target_db(), rate * delta)
	if next != _layer_db:  # only touch the player while fading (each change is a Web Audio call)
		_layer_db = next
		_layer.volume_db = _layer_db


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioBuses.MUSIC
	add_child(p)
	return p


static func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
