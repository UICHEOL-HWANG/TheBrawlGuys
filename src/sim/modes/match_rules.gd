class_name MatchRules
extends RefCounted
## The rules a match is played under, as plain data (combat-depth D, PRD §4.1 modes): "stock"
## (last fighter with stocks wins, Phase 1-5), "team" (2v2: teams per slot, friendly fire on or
## off, last team with stocks wins) or "timed" (FFA: unlimited respawns, ring-out score, highest
## score at time up wins). Built by MatchSetup and fixed for the whole match; ModeState holds what
## changes while it runs. Serialized inside World snapshots (ModeState.to_data).

const STOCK := "stock"
const TEAM := "team"
const TIMED := "timed"
const MODES: Array[String] = [STOCK, TEAM, TIMED]
const NO_TEAM := -1
const TEAM_COUNT := 2
## Team 2v2 always plays four fighters (bots fill empty slots).
const TEAM_PLAYERS := 4
const DATA_TYPES := {
	"mode": TYPE_STRING, "teams": TYPE_ARRAY, "friendly_fire": TYPE_BOOL, "duration_ticks": TYPE_INT,
}

var mode: String = STOCK
## Team per slot (TEAM only, else empty).
var teams: Array[int] = []
var friendly_fire: bool = true
## Match length (TIMED only, else 0).
var duration_ticks: int = 0


static func stock() -> MatchRules:
	return MatchRules.new()


static func team(p_teams: Array[int], p_friendly_fire: bool) -> MatchRules:
	var r := MatchRules.new()
	r.mode = TEAM
	r.teams = p_teams.duplicate()
	r.friendly_fire = p_friendly_fire
	return r


static func timed(ticks: int) -> MatchRules:
	var r := MatchRules.new()
	r.mode = TIMED
	r.duration_ticks = maxi(ticks, 1)
	return r


## Slots alternate teams: P1 + P3 against P2 + P4.
static func default_teams(player_count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in player_count:
		out.append(i % TEAM_COUNT)
	return out


## The rules for a mode id with the config's defaults (unknown ids play stock).
static func for_mode(p_mode: String, player_count: int, config: GameConfig) -> MatchRules:
	match p_mode:
		TEAM:
			return team(default_teams(player_count), config.friendly_fire == 1)
		TIMED:
			return timed(SimTime.to_ticks(config.timed_duration))
	return stock()


func team_of(id: int) -> int:
	return teams[id] if mode == TEAM and id >= 0 and id < teams.size() else NO_TEAM


## Two different fighters on the same team.
func allies(a: int, b: int) -> bool:
	return a != b and team_of(a) != NO_TEAM and team_of(a) == team_of(b)


## Bit i set = fighter i's hits pass through fighter id (Fighter.ally_mask): teammates while
## friendly fire is off.
func ally_mask(id: int) -> int:
	if friendly_fire:
		return 0
	var mask := 0
	for other: int in teams.size():
		if allies(id, other):
			mask |= 1 << other
	return mask


func to_data() -> Dictionary:
	return {"mode": mode, "teams": teams.duplicate(), "friendly_fire": friendly_fire,
		"duration_ticks": duration_ticks}


static func from_data(d: Dictionary) -> MatchRules:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	if not MODES.has(String(d["mode"])):
		return null
	for t: Variant in d["teams"]:
		if typeof(t) != TYPE_INT or int(t) < NO_TEAM or int(t) >= TEAM_COUNT:
			return null
	var r := MatchRules.new()
	r.mode = d["mode"]
	r.teams.assign(d["teams"])
	r.friendly_fire = d["friendly_fire"]
	r.duration_ticks = d["duration_ticks"]
	return r
