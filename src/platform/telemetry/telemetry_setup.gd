class_name TelemetrySetup
extends RefCounted
## MatchTelemetry.begin() setup built from a MatchSetup (platform A6/B1/A7): mode, arena, seed, the
## local slot and one entry per slot, a fresh match id and build/platform stamps, plus the
## reproducibility header (analytics-strategy §1): config fingerprint, sim and event schema
## versions, per-slot controller and bot tuning, and the session context the caller passes in.

const VARIANT_CONTROL := "control"
const BOT_DIFFICULTY_DEFAULT := "normal"
const BOT_GROUP := "Bot"
## Context keys copied as-is (null when absent): session_id, user_match_seq, loss_streak.
const CONTEXT_KEYS: Array[String] = ["session_id", "user_match_seq", "loss_streak"]


## config: the match's GameConfig (null leaves config-derived fields null).
static func from_match_setup(setup: MatchSetup, config: GameConfig = null, context: Dictionary = {}) -> Dictionary:
	var out := {
		"match_id": Uuid.v4(), "mode": setup.mode, "rule": setup.rule, "arena": setup.arena_id, "seed": setup.seed,
		"local_slot": setup.local_slot(), "started_at": Time.get_datetime_string_from_system(true) + "Z",
		"build_version": PlatformEnv.app_version(), "platform": PlatformEnv.kind(),
		"slots": _slots(setup, config),
		"config_fingerprint": config.fingerprint() if config != null else null,
		"sim_version": World.SNAPSHOT_VERSION, "event_schema_version": EventCatalog.SCHEMA_VERSION,
		"config_variant": String(context.get("config_variant", VARIANT_CONTROL)),
	}
	for key: String in CONTEXT_KEYS:
		out[key] = context.get(key)
	return out


## Hash of the Bot config group: two bots with the same hash play the same way.
static func bot_params_hash(config: GameConfig) -> int:
	var values: Array = []
	var group := ""
	for p: Dictionary in config.get_property_list():
		var usage := int(p["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			group = String(p["name"])
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and group == BOT_GROUP:
			values.append([p["name"], config.get(p["name"])])
	return hash(values)


static func _slots(setup: MatchSetup, config: GameConfig) -> Array:
	var bot_hash: Variant = bot_params_hash(config) if config != null else null
	var slots: Array = []
	for s: Dictionary in setup.slots:
		var is_bot: bool = s["controller"] == MatchSetup.CONTROLLER_BOT
		slots.append({
			"slot": int(s["slot"]), "is_bot": is_bot, "controller": String(s["controller"]),
			"character": String(s["character"]), "style": CharacterData.style_of(String(s["character"])),
			"input_device": String(s["input_device"]),
			"bot_difficulty": String(s.get("bot_difficulty", BOT_DIFFICULTY_DEFAULT)) if is_bot else null,
			"bot_params_hash": bot_hash if is_bot else null,
		})
	return slots
