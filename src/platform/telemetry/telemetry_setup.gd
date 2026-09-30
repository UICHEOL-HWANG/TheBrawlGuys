class_name TelemetrySetup
extends RefCounted
## MatchTelemetry.begin() setup built from a MatchSetup (platform A6/B1): mode, arena, seed, the
## local slot and one entry per slot, plus a fresh match id and build/platform stamps.

const STYLE_DEFAULT := "default"


static func from_match_setup(setup: MatchSetup) -> Dictionary:
	var slots: Array = []
	for s: Dictionary in setup.slots:
		slots.append({
			"slot": int(s["slot"]), "is_bot": s["controller"] == MatchSetup.CONTROLLER_BOT,
			"character": String(s["character"]), "style": STYLE_DEFAULT,
			"input_device": String(s["input_device"]),
		})
	return {
		"match_id": Uuid.v4(), "mode": setup.mode, "arena": setup.arena_id, "seed": setup.seed,
		"local_slot": setup.local_slot(), "started_at": Time.get_datetime_string_from_system(true) + "Z",
		"build_version": PlatformEnv.app_version(), "platform": PlatformEnv.kind(), "slots": slots,
	}
