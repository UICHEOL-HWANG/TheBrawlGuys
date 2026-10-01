class_name MatchSummary
extends RefCounted
## Small pure helpers for MatchTelemetry (platform A6): results, durations and view lookups.

## Duration precision in seconds.
const SECONDS_STEP := 0.01
const VICTIM_KEYS: Array[String] = ["target", "fighter", "victim"]


## "win" | "loss" | "draw" | "abandoned" for one slot. winner is a slot or null. teams (team
## mode, view["mode"]["teams"]): the winner's teammates win too.
static func result(slot: int, over: bool, winner: Variant, teams: Array = []) -> String:
	if not over:
		return "abandoned"
	if winner == null:
		return "draw"
	if int(winner) == slot:
		return "win"
	var same_team: bool = slot < teams.size() and int(winner) < teams.size() and teams[slot] == teams[int(winner)]
	return "win" if same_team else "loss"


## Per-slot mode fields for match_ended.players[] / match_players: team (team mode) and score
## (timed); {} in stock so stock rows keep the pre-0004 shape.
static func mode_fields(view: Dictionary, slot: int) -> Dictionary:
	var mode: Dictionary = view.get("mode", {})
	match String(mode.get("rule", MatchRules.STOCK)):
		MatchRules.TEAM:
			return {"team": int((mode["teams"] as Array)[slot])}
		MatchRules.TIMED:
			return {"score": int((mode["scores"] as Array)[slot])}
	return {}


static func seconds(ticks: int) -> float:
	return snappedf(float(ticks) / SimTime.TICK_RATE, SECONDS_STEP)


static func stocks_left(view: Dictionary, slot: int) -> int:
	for f: Dictionary in view.get("fighters", []):
		if int(f["id"]) == slot:
			return int(f["stocks"])
	return 0


## Damage a fighter had in the last view before this tick (its damage at death on a ringout).
static func damage_of(fighters: Array, slot: int) -> float:
	for f: Dictionary in fighters:
		if int(f["id"]) == slot:
			return float(f["damage"])
	return 0.0


## Fighter touched by an arena event (target / fighter / victim key), or -1.
static func fighter_of(e: Dictionary) -> int:
	for k: String in VICTIM_KEYS:
		if e.has(k):
			return int(e[k])
	return -1


## Attack kind name (AttackSet.Kind key) a fighter is using in this view, or "" if none/unknown.
## Items and projectiles report their thrower here too, so read it together with the event type.
static func attack_kind_name(fighters: Array, slot: int) -> String:
	for f: Dictionary in fighters:
		if int(f["id"]) == slot:
			var kind := int(f.get("attack_kind", -1))
			var names := AttackSet.Kind.keys()
			return String(names[kind]) if kind >= 0 and kind < names.size() else ""
	return ""
