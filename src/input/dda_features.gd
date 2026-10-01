class_name DdaFeatures
extends RefCounted
## Win-probability features of one slot from a state view (PRD-BOT-06), the same names and
## definitions as analysis/src/brawl_analysis/models/dda_models.py builds from timeline.csv:
## a side is the team in team mode, else the slot; side_* sum / average the side, foe_* the
## other sides (best stocks, mean of side damages, best score); d_self is the slot's skill
## (dial d, or a human's estimate), d_foe the mean d of the slots on other sides.

const FEATURES: Array[String] = [
	"t", "player_count", "damage", "stocks", "edge_dist", "side_stocks", "side_damage",
	"foe_best_stocks", "foe_damage", "stock_diff", "damage_diff", "score_diff", "foe_sides_alive",
	"d_self", "d_foe", "d_diff", "is_team", "is_timed",
]
const DEFAULT_D := 0.5


## Features for `slot`; skill maps slot -> d (missing slots count as DEFAULT_D).
static func of(view: Dictionary, slot: int, skill: Dictionary) -> Dictionary:
	var team := String((view.get("mode", {}) as Dictionary).get("rule", "")) == MatchRules.TEAM
	var timed := String((view.get("mode", {}) as Dictionary).get("rule", "")) == MatchRules.TIMED
	var sides := _sides(view, team)
	var my_side := _side_of(view, slot, team)
	var mine: Dictionary = sides[my_side]
	var foe := _foe_totals(sides, my_side)
	var me := BotViewQuery.find(view, slot)
	var pos: Vector3 = me.get("pos", Vector3.ZERO)
	var d_self := float(skill.get(slot, DEFAULT_D))
	var d_foe := _foe_d(view, my_side, team, skill)
	return {
		"t": float(view.get("tick", 0)) / SimTime.TICK_RATE, "player_count": float(view["fighters"].size()),
		"damage": float(me.get("damage", 0.0)), "stocks": float(me.get("stocks", 0)),
		"edge_dist": float(view.get("arena_radius", 10.0)) - Vector2(pos.x, pos.z).length(),
		"side_stocks": mine["stocks"], "side_damage": mine["damage"],
		"foe_best_stocks": foe["best_stocks"], "foe_damage": foe["damage"],
		"stock_diff": mine["stocks"] - foe["best_stocks"], "damage_diff": foe["damage"] - mine["damage"],
		"score_diff": mine["score"] - foe["best_score"], "foe_sides_alive": foe["alive"],
		"d_self": d_self, "d_foe": d_foe, "d_diff": d_self - d_foe,
		"is_team": 1.0 if team else 0.0, "is_timed": 1.0 if timed else 0.0,
	}


## Fair share of a win: 0.5 in team mode, 1 / players otherwise.
static func prior(view: Dictionary) -> float:
	if String((view.get("mode", {}) as Dictionary).get("rule", "")) == MatchRules.TEAM:
		return 0.5
	return 1.0 / maxf(1.0, float(view["fighters"].size()))


static func _side_of(view: Dictionary, slot: int, team: bool) -> int:
	var teams: Array = (view.get("mode", {}) as Dictionary).get("teams", [])
	return int(teams[slot]) if team and slot < teams.size() else slot


## side -> {stocks (sum), damage (mean), score (sum)}
static func _sides(view: Dictionary, team: bool) -> Dictionary:
	var scores: Array = (view.get("mode", {}) as Dictionary).get("scores", [])
	var out := {}
	for f: Dictionary in view["fighters"]:
		var slot := int(f["id"])
		var side := _side_of(view, slot, team)
		var s: Dictionary = out.get(side, {"stocks": 0.0, "damage_sum": 0.0, "n": 0.0, "score": 0.0})
		s["stocks"] += float(f["stocks"])
		s["damage_sum"] += float(f["damage"])
		s["n"] += 1.0
		s["score"] += float(scores[slot]) if slot < scores.size() else 0.0
		s["damage"] = s["damage_sum"] / s["n"]
		out[side] = s
	return out


static func _foe_totals(sides: Dictionary, my_side: int) -> Dictionary:
	var out := {"best_stocks": 0.0, "damage": 0.0, "best_score": -INF, "alive": 0.0}
	var n := 0.0
	for side: Variant in sides:
		if int(side) == my_side:
			continue
		var s: Dictionary = sides[side]
		out["best_stocks"] = maxf(out["best_stocks"], s["stocks"])
		out["best_score"] = maxf(out["best_score"], s["score"])
		out["damage"] += s["damage"]
		out["alive"] += 1.0 if s["stocks"] > 0.0 else 0.0
		n += 1.0
	out["damage"] = out["damage"] / n if n > 0.0 else 0.0
	out["best_score"] = out["best_score"] if n > 0.0 else 0.0
	return out


static func _foe_d(view: Dictionary, my_side: int, team: bool, skill: Dictionary) -> float:
	var total := 0.0
	var n := 0.0
	for f: Dictionary in view["fighters"]:
		var other := int(f["id"])
		if _side_of(view, other, team) != my_side:
			total += float(skill.get(other, DEFAULT_D))
			n += 1.0
	return total / n if n > 0.0 else DEFAULT_D
