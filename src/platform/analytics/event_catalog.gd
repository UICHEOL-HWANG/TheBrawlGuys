class_name EventCatalog
extends RefCounted
## Amplitude event schema (platform A2, PRD-DATA-03): every tracked event name and the properties
## it must carry. Extra properties are allowed; values must be JSON-safe. docs/tracking-plan.md
## describes each event; this table is what code and tests enforce.

## Bumped with every change to event names, properties or Supabase row shapes (tracking-plan §7).
## Stamped on matches rows and sent as an Amplitude super property. 1 = platform A6,
## 2 = A7 replay header, 3 = A8 features and session / load / result / perf events,
## 4 = Phase 5 special events and the match_players.special_hits column, 5 = Phase 5 character
## select (character_selected is_bot/input_device, characters reach the sim, character ids and
## styles on match_players and match_ended.players[]), 6 = Phase 5 onboarding tutorial funnel
## (tutorial_started / tutorial_step_completed / tutorial_skipped / tutorial_completed), 7 =
## combat-depth D match rules (rule_selected, "rule" on match events, players[] team / score,
## matches.rule and match_players.team / score from migration 0004).
const SCHEMA_VERSION := 7

const EVENTS: Dictionary = {
	# App and session
	"app_opened": [],
	"app_backgrounded": [],
	"app_closed": [],
	"session_started": [],
	"session_ended": ["duration_s", "matches", "last_screen"],
	"load_timed": ["stage", "ms"],
	"perf_sampled": ["match_id", "fps_p5", "fps_p50", "spike_count", "frame_count"],
	# Login
	"login_viewed": [],
	"login_started": ["provider", "platform"],
	"login_completed": ["provider", "platform"],
	"login_failed": ["provider", "reason"],
	"login_skipped": [],
	"session_restored": [],
	"logout": [],
	# Email code sign-in (never the address or the code)
	"email_code_requested": ["result"],
	"email_code_resent": [],
	"email_code_verified": ["attempts"],
	# Menu funnel
	"screen_viewed": ["screen"],
	"mode_selected": ["mode"],
	"rule_selected": ["rule"],
	"character_selected": ["slot", "character", "style", "is_bot", "input_device"],
	"arena_selected": ["arena"],
	"select_cancelled": ["screen"],
	# Onboarding tutorial (step = TutorialSteps id, index = 1-based position)
	"tutorial_started": ["source"],
	"tutorial_step_completed": ["step", "index", "ms_in_step", "attempts"],
	"tutorial_skipped": ["step", "index"],
	"tutorial_completed": ["total_ms"],
	# Match
	"match_started": ["match_id", "mode", "rule", "arena", "player_count", "bot_count", "characters", "input_device",
		"loss_streak"],
	"match_ended": ["match_id", "mode", "rule", "arena", "result", "winner_slot", "duration_s", "players"],
	"match_abandoned": ["match_id", "mode", "rule", "arena", "duration_s", "stock_diff", "ms_since_last_ringout"],
	"result_viewed": ["match_id", "dwell_ms", "next"],
	"rematch_clicked": ["match_id"],
	# Combat highlights
	"stock_lost": ["match_id", "victim_slot", "attacker_slot", "cause", "damage_at_death", "angle_deg", "zone",
		"stocks_left"],
	"special_used": ["match_id", "slot", "character", "special", "ms_since_full", "target_damage"],
	"special_hit": ["match_id", "slot", "character", "special", "targets_hit", "target_slot", "caused_ringout"],
	"gauge_full": ["match_id", "slot", "character", "match_time_s"],
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
