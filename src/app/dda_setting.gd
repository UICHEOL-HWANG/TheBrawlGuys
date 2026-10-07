class_name DdaSetting
extends RefCounted
## The 설정 switch for bot DDA (dynamic difficulty): the [bots] dda setting BotSquadFactory reads
## at every match start ("on" / "off"; unset = "auto", the device's A/B arm). The switch shows
## what this device plays with now and saves an explicit "on" / "off" when flipped; with DDA off
## in the config (dda_enabled = 0) it is always off. Tracked as settings_changed key TRACK_KEY,
## so analysis can tell a forced arm from the A/B bucket.

const TRACK_KEY := "bot_dda"


static func setting(store: SettingsStore) -> String:
	return String(store.get_value(BotSquadFactory.SETTINGS_SECTION, BotSquadFactory.SETTINGS_KEY,
			BotSquadFactory.AUTO))


static func is_on(store: SettingsStore, config: GameConfig, device_key: String) -> bool:
	return BotSquadFactory.variant(config, setting(store), device_key) == BotSquad.ON


static func save(store: SettingsStore, on: bool) -> void:
	store.set_value(BotSquadFactory.SETTINGS_SECTION, BotSquadFactory.SETTINGS_KEY,
			BotSquad.ON if on else BotSquad.OFF)


## The key the A/B bucket hashes, like BotSquadFactory (headless and test runs never touch user://).
static func device_key() -> String:
	return DeviceId.load_or_create() if PlatformEnv.is_live() else BotSquadFactory.HEADLESS_KEY
