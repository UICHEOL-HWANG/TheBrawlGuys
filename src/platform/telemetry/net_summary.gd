class_name NetSummary
extends RefCounted
## Online match network summary in telemetry (event schema 9, online design "Tracking",
## supabase/migrations/0007_online_stats.sql). Built from NetStats.props(): match_ended /
## match_abandoned and the matches row get KEYS, each match_ended.players[] entry and match_players
## row gets PLAYER_KEYS. Offline matches pass {} and keep their earlier shape (no keys at all), so
## local uploads work before 0007 runs.

## net_host: this peer hosted; rtt_p50 / rtt_p95: round trip in ms (null without samples);
## corrections: own-fighter prediction corrections (clients; 0 on the host); disconnects: drops
## seen by this peer; disconnect_reason: the newest one (timeout | left | host_left | room_full, or null).
const KEYS: Array[String] = ["net_host", "rtt_p50", "rtt_p95", "corrections", "disconnects", "disconnect_reason"]
## Host only: why that slot's player dropped (timeout | left), null when it never did.
const PLAYER_KEYS: Array[String] = ["disconnect_reason"]


static func match_fields(net: Dictionary) -> Dictionary:
	var out := {}
	if net.is_empty():
		return out
	for key: String in KEYS:
		out[key] = net.get(key)
	return out


static func player_fields(net: Dictionary, slot: int) -> Dictionary:
	if net.is_empty():
		return {}
	var reasons: Dictionary = net.get("slot_reasons", {})
	return {"disconnect_reason": reasons.get(slot)}
