class_name TelemetrySetup
extends RefCounted
## MatchTelemetry.begin() setup for today's fixed match (platform A6): mode "bot", the default
## arena, one local player and bots, characters by slot. B1's MatchSetup replaces the constants.

const MODE_BOT := "bot"
const ARENA_DEFAULT := "default"
const STYLE_DEFAULT := "default"
const INPUT_BOT := "bot"


static func for_local_match(player_count: int, local_slot: int, seed: int) -> Dictionary:
	var slots: Array = []
	for i: int in player_count:
		var is_bot := i != local_slot
		slots.append({
			"slot": i, "is_bot": is_bot, "character": String(CharacterCatalog.for_player(i)["name"]),
			"style": STYLE_DEFAULT, "input_device": INPUT_BOT if is_bot else PlatformEnv.default_input_device(),
		})
	return {
		"match_id": Uuid.v4(), "mode": MODE_BOT, "arena": ARENA_DEFAULT, "seed": seed, "local_slot": local_slot,
		"started_at": Time.get_datetime_string_from_system(true) + "Z", "build_version": PlatformEnv.app_version(),
		"platform": PlatformEnv.kind(), "slots": slots,
	}
