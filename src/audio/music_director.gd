class_name MusicDirector
extends Node
## BGM (design.md DS-SFX-02, context F10): the battle loop is an AudioStreamSynchronized of the
## base loop and the intensity layer, which fades in while someone is on their last stock. The
## menu variation is a separate loop. Files named battle_base / battle_intense / menu under
## assets/music can be replaced by the real soundtrack (.ogg preferred, .wav placeholder).

const SILENT_DB := -60.0
const NAMES: Array[String] = ["battle_base", "battle_intense", "menu"]

var _config: GameConfig
var _player: AudioStreamPlayer
var _battle: AudioStreamSynchronized
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
	_player = AudioStreamPlayer.new()
	_player.bus = AudioBuses.MUSIC
	add_child(_player)
	_battle = AudioStreamSynchronized.new()
	_battle.stream_count = 2
	_battle.set_sync_stream(0, _looped(load(path_for("battle_base"))))
	_battle.set_sync_stream(1, _looped(load(path_for("battle_intense"))))
	_battle.set_sync_stream_volume(1, SILENT_DB)
	_menu = _looped(load(path_for("menu")))


func play_battle() -> void:
	_intense = false
	_layer_db = SILENT_DB
	_battle.set_sync_stream_volume(1, SILENT_DB)
	_player.stream = _battle
	_player.play()


func play_menu() -> void:
	_player.stream = _menu
	_player.play()


func stop() -> void:
	_player.stop()


func update_from(view: Dictionary) -> void:
	_intense = wants_intense(view)


func is_intense() -> bool:
	return _intense


func intense_target_db() -> float:
	return 0.0 if _intense else SILENT_DB


func _process(delta: float) -> void:
	if _battle == null:
		return
	var rate := (0.0 - SILENT_DB) / maxf(_config.music_intense_fade, 0.01)
	_layer_db = move_toward(_layer_db, intense_target_db(), rate * delta)
	_battle.set_sync_stream_volume(1, _layer_db)


static func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
