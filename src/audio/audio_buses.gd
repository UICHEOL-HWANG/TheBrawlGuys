class_name AudioBuses
extends RefCounted
## SFX / Music / UI buses, all sent to Master, volumes from GameConfig (design.md DS-SFX-01/02).

const SFX := "SFX"
const MUSIC := "Music"
const UI := "UI"


static func ensure(config: GameConfig) -> void:
	_bus(SFX, config.sfx_volume_db)
	_bus(MUSIC, config.music_volume_db)
	_bus(UI, config.ui_volume_db)


static func _bus(name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, volume_db)
