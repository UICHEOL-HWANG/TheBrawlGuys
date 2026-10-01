extends RefCounted
## 1 Hz state timeline for the win-probability model (A9, analytics-strategy M2): one row per
## fighter per sample from World.state_view(). Only values known at that tick — the outcome is
## joined later from match_players, never written here. edge_dist is the arena view radius minus
## the fighter's distance from the centre (negative = outside), the same radius telemetry uses.

const SAMPLE_EVERY_TICKS := 60
const COLUMNS: Array[String] = [
	"match_id", "tick", "t", "slot", "damage", "stocks", "x", "y", "z", "edge_dist", "gauge",
	"state", "holding_item", "item_kind", "on_ground", "guard_hp_ratio", "team", "score",
]
const NO_TEAM := -1


static func due(tick: int) -> bool:
	return tick % SAMPLE_EVERY_TICKS == 0


static func rows(match_id: String, view: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tick := int(view["tick"])
	var radius := float(view["arena_radius"])
	var mode: Dictionary = view.get("mode", {})
	var teams: Array = mode.get("teams", []) if String(mode.get("rule", "")) == MatchRules.TEAM else []
	var scores: Array = mode.get("scores", [])
	for f: Dictionary in view["fighters"]:
		out.append(_row(match_id, tick, radius, f, teams, scores))
	return out


static func _row(match_id: String, tick: int, radius: float, f: Dictionary, teams: Array,
		scores: Array) -> Dictionary:
	var slot := int(f["id"])
	var pos: Vector3 = f["pos"]
	return {
		"match_id": match_id, "tick": tick, "t": snappedf(float(tick) / SimTime.TICK_RATE, 0.01),
		"slot": slot, "damage": snappedf(float(f["damage"]), 0.1), "stocks": int(f["stocks"]),
		"x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01),
		"edge_dist": snappedf(radius - Vector2(pos.x, pos.z).length(), 0.01),
		"gauge": snappedf(float(f["gauge"]), 0.1), "state": int(f["state"]),
		"holding_item": int(f["item_kind"]) != Fighter.NONE, "item_kind": int(f["item_kind"]),
		"on_ground": bool(f["on_ground"]), "guard_hp_ratio": snappedf(float(f["guard_hp_ratio"]), 0.01),
		"team": int(teams[slot]) if slot < teams.size() else NO_TEAM,
		"score": int(scores[slot]) if slot < scores.size() else 0,
	}
