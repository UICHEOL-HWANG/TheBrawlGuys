class_name UserVolume
extends RefCounted
## The player's sound volumes (설정 화면): whole percents 0..100 in SettingsStore's [audio]
## section, on top of GameConfig's bus levels. 100 leaves the game's mix as designed; 0 is silent.

const SECTION := "audio"
const SFX := "sfx_volume"
const MUSIC := "music_volume"
const FULL := 100
const STEP := 5
const MUTE_DB := -80.0


static func percent(store: SettingsStore, key: String) -> int:
	var v: Variant = store.get_value(SECTION, key, FULL)
	return clampi(int(v), 0, FULL) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else FULL


static func set_percent(store: SettingsStore, key: String, value: int) -> void:
	store.set_value(SECTION, key, clampi(value, 0, FULL))


## Decibels to add to a bus: 100 -> 0 dB, 50 -> about -6 dB, 0 -> silent.
static func db(percent_value: int) -> float:
	if percent_value <= 0:
		return MUTE_DB
	return maxf(linear_to_db(float(percent_value) / FULL), MUTE_DB)
