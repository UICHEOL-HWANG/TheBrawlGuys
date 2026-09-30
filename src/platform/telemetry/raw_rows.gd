class_name RawRows
extends RefCounted
## Supabase row builders (platform A6, supabase/migrations/0001_match_telemetry.sql).
## match_events rows all share the same six columns so PostgREST can bulk insert them.

## Event types whose "id" is a fighter (item events use "id" for the item).
const FIGHTER_ID_TYPES: Array[String] = ["ringout", "jumped", "landed", "respawned"]
const ACTOR_KEYS: Array[String] = ["attacker", "fighter"]
const TARGET_KEYS: Array[String] = ["target", "victim"]


static func event_row(match_id: String, tick: int, e: Dictionary) -> Dictionary:
	var type := String(e.get("type", ""))
	var payload := e.duplicate()
	payload.erase("type")
	var actor: Variant = _take(payload, ACTOR_KEYS)
	if actor == null and FIGHTER_ID_TYPES.has(type):
		actor = _take(payload, ["id"])
	var target: Variant = _take(payload, TARGET_KEYS)
	return _row(match_id, tick, type, actor, target, payload)


static func position_row(match_id: String, tick: int, fighter: Dictionary) -> Dictionary:
	var payload := {"pos": fighter["pos"], "damage": fighter["damage"], "state": fighter["state"],
		"stocks": fighter["stocks"]}
	return _row(match_id, tick, "pos", int(fighter["id"]), null, payload)


static func match_row(setup: Dictionary, duration_ticks: int, winner_slot: Variant, result: String) -> Dictionary:
	return {
		"id": setup["match_id"], "mode": setup["mode"], "arena": setup["arena"],
		"player_count": (setup["slots"] as Array).size(), "seed": setup["seed"],
		"started_at": setup["started_at"], "duration_ticks": duration_ticks, "winner_slot": winner_slot,
		"result": result, "build_version": setup.get("build_version", ""), "platform": setup.get("platform", ""),
	}


static func player_row(match_id: String, slot_setup: Dictionary, summary: Dictionary) -> Dictionary:
	var row := summary.duplicate()
	row["match_id"] = match_id
	for key: String in ["is_bot", "character", "style", "input_device"]:
		row[key] = slot_setup[key]
	return row


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
