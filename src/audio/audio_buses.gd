class_name AudioBuses
extends RefCounted
## SFX / Music / UI buses, all sent to Master, volumes from GameConfig (design.md DS-SFX-01/02).

const SFX := "SFX"
const MUSIC := "Music"
const UI := "UI"


## store: the player's settings; their sound and music volumes lower the buses (null = as designed).
## UI clicks follow the sound volume.
static func ensure(config: GameConfig, store: SettingsStore = null) -> void:
	if store == null:
		apply(config, UserVolume.FULL, UserVolume.FULL)
	else:
		apply(config, UserVolume.percent(store, UserVolume.SFX), UserVolume.percent(store, UserVolume.MUSIC))


## The buses at the config levels lowered by the player's sound and music percents (no disk).
static func apply(config: GameConfig, sfx_percent: int, music_percent: int) -> void:
	var sfx_db := UserVolume.db(sfx_percent)
	_bus(SFX, maxf(config.sfx_volume_db + sfx_db, UserVolume.MUTE_DB))
	_bus(MUSIC, maxf(config.music_volume_db + UserVolume.db(music_percent), UserVolume.MUTE_DB))
	_bus(UI, maxf(config.ui_volume_db + sfx_db, UserVolume.MUTE_DB))


static func _bus(name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, volume_db)
