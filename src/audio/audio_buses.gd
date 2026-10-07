class_name AudioBuses
extends RefCounted
## SFX / Music / UI buses, all sent to Master, volumes from GameConfig (design.md DS-SFX-01/02).
## The buses come from res://default_bus_layout.tres so they exist before anything plays. Never
## AudioServer.add_bus() them at runtime: on the web build that reorders Godot's Web Audio buses
## (Bus.move with position -1) and unplugs Master from the speakers, silencing every sample.

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
		if OS.has_feature("web"):
			# Adding it would silence everything (see above); its players fall back to Master instead.
			push_error("AudioBuses: bus '%s' missing from default_bus_layout.tres" % name)
			return
		push_warning("AudioBuses: bus '%s' missing from default_bus_layout.tres; adding it" % name)
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, volume_db)
