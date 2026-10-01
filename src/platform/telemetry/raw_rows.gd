class_name RawRows
extends RefCounted
## Supabase row builders (platform A6, supabase/migrations/0001_match_telemetry.sql).
## match_events rows all share the same six columns so PostgREST can bulk insert them.

## Event types whose "id" is a fighter (item events use "id" for the item).
const FIGHTER_ID_TYPES: Array[String] = ["ringout", "jumped", "landed", "respawned", "score"]
## "owner": projectile events (event schema 8; before that the owner stayed in the payload).
const ACTOR_KEYS: Array[String] = ["attacker", "fighter", "owner"]
const TARGET_KEYS: Array[String] = ["target", "victim"]
## Events whose "fighter" is the one hit, so actor = attacker / target = fighter like guard_hit.
const FIGHTER_TARGET_TYPES: Array[String] = ["perfect_guard"]
## Reproducibility header copied from the setup onto the matches row (null when absent).
const HEADER_KEYS: Array[String] = [
	"config_fingerprint", "sim_version", "event_schema_version", "session_id", "user_match_seq",
	"dda_variant",
]
## matches.config_variant is NOT NULL: setups without an experiment are the control group.
const VARIANT_DEFAULT := "control"


static func event_row(match_id: String, tick: int, e: Dictionary) -> Dictionary:
	var type := String(e.get("type", ""))
	var payload := e.duplicate()
	payload.erase("type")
	var target: Variant = _take(payload, ["fighter"]) if FIGHTER_TARGET_TYPES.has(type) else null
	var actor: Variant = _take(payload, ACTOR_KEYS)
	if actor == null and FIGHTER_ID_TYPES.has(type):
		actor = _take(payload, ["id"])
	if target == null:
		target = _take(payload, TARGET_KEYS)
	return _row(match_id, tick, type, actor, target, payload)


static func position_row(match_id: String, tick: int, fighter: Dictionary) -> Dictionary:
	var payload := {"pos": fighter["pos"], "damage": fighter["damage"], "state": fighter["state"],
		"stocks": fighter["stocks"]}
	return _row(match_id, tick, "pos", int(fighter["id"]), null, payload)


## final_state_hash: World.state_hash() when tracking ended (null when unknown).
static func match_row(setup: Dictionary, duration_ticks: int, winner_slot: Variant, result: String,
		final_state_hash: Variant = null) -> Dictionary:
	var row := {
		"id": setup["match_id"], "mode": setup["mode"], "arena": setup["arena"],
		"player_count": (setup["slots"] as Array).size(), "seed": setup["seed"],
		"started_at": setup["started_at"], "duration_ticks": duration_ticks, "winner_slot": winner_slot,
		"result": result, "build_version": setup.get("build_version", ""), "platform": setup.get("platform", ""),
		"final_state_hash": final_state_hash,
	}
	for key: String in HEADER_KEYS:
		row[key] = setup.get(key)
	row["config_variant"] = setup.get("config_variant", VARIANT_DEFAULT)
	var rule := String(setup.get("rule", MatchRules.STOCK))
	if rule != MatchRules.STOCK:
		row["rule"] = rule  # matches.rule (migration 0004); stock rows keep the 0003 shape
	return row


static func player_row(match_id: String, slot_setup: Dictionary, summary: Dictionary) -> Dictionary:
	var row := summary.duplicate()
	row["match_id"] = match_id
	for key: String in ["is_bot", "character", "style", "input_device"]:
		row[key] = slot_setup[key]
	var is_bot := bool(slot_setup["is_bot"])
	row["controller"] = slot_setup.get("controller", "bot" if is_bot else "local")
	# A dial bot's own preset / params hash (BotSquad summary) wins over the setup's.
	row["bot_difficulty"] = summary.get("bot_difficulty", slot_setup.get("bot_difficulty"))
	row["bot_params_hash"] = summary.get("bot_params_hash", slot_setup.get("bot_params_hash"))
	return row


## A bot-side event row (BotSquad: probe_stage, dda_adjusted, bot_intent), same six columns.
static func bot_row(match_id: String, tick: int, type: String, actor: Variant, target: Variant,
		payload: Dictionary) -> Dictionary:
	return _row(match_id, tick, type, actor, target, payload)


static func _row(match_id: String, tick: int, type: String, actor: Variant, target: Variant,
		payload: Dictionary) -> Dictionary:
	return {
		"match_id": match_id, "tick": tick, "type": type,
		"actor_slot": null if actor == null else int(actor),
		"target_slot": null if target == null else int(target),
		"payload": JsonSafe.to_json_value(payload),
	}


## Removes and returns the first present key's value, or null.
static func _take(d: Dictionary, keys: Array[String]) -> Variant:
	for k: String in keys:
		if d.has(k):
			var v: Variant = d[k]
			d.erase(k)
			return v
	return null
