class_name EventCatalog
extends RefCounted
## Amplitude event schema (platform A2, PRD-DATA-03): every tracked event name and the properties
## it must carry. Extra properties are allowed; values must be JSON-safe. docs/tracking-plan.md
## describes each event; this table is what code and tests enforce.

const EVENTS: Dictionary = {
	# App and session
	"app_opened": [],
	"app_backgrounded": [],
	"app_closed": [],
	"perf_sampled": ["avg_fps", "p95_frame_ms", "avg_tick_ms"],
	# Login
	"login_viewed": [],
	"login_started": ["provider", "platform"],
	"login_completed": ["provider", "platform"],
	"login_failed": ["provider", "reason"],
	"session_restored": [],
	"logout": [],
	# Menu funnel
	"screen_viewed": ["screen"],
	"mode_selected": ["mode"],
	"character_selected": ["slot", "character", "style"],
	"arena_selected": ["arena"],
	"select_cancelled": ["screen"],
	# Match
	"match_started": ["match_id", "mode", "arena", "player_count", "bot_count", "characters", "input_device"],
	"match_ended": ["match_id", "mode", "arena", "result", "winner_slot", "duration_s", "players"],
	"match_abandoned": ["match_id", "mode", "arena", "duration_s"],
	"rematch_clicked": ["match_id"],
	# Combat highlights
	"stock_lost": ["match_id", "victim_slot", "attacker_slot", "cause", "damage_at_death", "angle_deg", "zone",
		"stocks_left"],
	"special_used": ["match_id", "slot", "character"],
	"special_hit": ["match_id", "slot", "target_slot"],
	"gauge_full": ["match_id", "slot"],
	# Items
	"item_picked_up": ["match_id", "slot", "item"],
	"item_used": ["match_id", "slot", "item", "action"],
	"item_hit": ["match_id", "slot", "target_slot", "item", "guarded"],
	# Arena
	"gimmick_triggered": ["match_id", "kind", "victim_slot"],
	"gimmick_ringout": ["match_id", "kind", "victim_slot"],
	# Settings and input
	"settings_changed": ["key", "old", "new"],
	"quality_changed": ["old", "new"],
	"input_device_changed": ["device"],
	"touch_layout_changed": ["layout"],
	# Errors
	"net_error": ["endpoint", "status"],
}


static func has(event_name: String) -> bool:
	return EVENTS.has(event_name)


static func names() -> PackedStringArray:
	return PackedStringArray(EVENTS.keys())


## Empty when the event may be sent; otherwise one message per problem.
static func validate(event_name: String, props: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not EVENTS.has(event_name):
		errors.append("unknown event '%s' (add it to EventCatalog and docs/tracking-plan.md)" % event_name)
		return errors
	for key: String in EVENTS[event_name]:
		if not props.has(key) or props[key] == null:
			errors.append("%s: missing property '%s'" % [event_name, key])
	for key: Variant in props:
		if typeof(key) != TYPE_STRING or not JsonSafe.is_safe(props[key]):
			errors.append("%s: property '%s' is not JSON-safe" % [event_name, str(key)])
	return errors
