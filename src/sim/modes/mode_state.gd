class_name ModeState
extends RefCounted
## What a match mode tracks while it runs (combat-depth D): the MatchRules, each fighter's score
## and last attacker (from the tick's "hit"/"guard_hit" events), the timed clock, sudden death and
## the winning team. Scoring (TIMED, outside sudden death): a ring-out is +1 for the last attacker
## if that hit landed within ringout_credit_time, else -1 for the victim; each change is a
## {"type": "score", "id", "delta", "score"} event. Serialized in World snapshots (v10).

const NONE := -1
const DATA_TYPES := {
	"rules": TYPE_DICTIONARY, "scores": TYPE_ARRAY, "last_hit_by": TYPE_ARRAY, "last_hit_tick": TYPE_ARRAY,
	"ticks_left": TYPE_INT, "sudden_death": TYPE_BOOL, "winner_team": TYPE_INT,
}
const INT_ARRAYS: Array[String] = ["scores", "last_hit_by", "last_hit_tick"]
const HIT_TYPES: Array[String] = ["hit", "guard_hit"]

var rules: MatchRules
var scores: Array[int] = []
var last_hit_by: Array[int] = []
var last_hit_tick: Array[int] = []
var ticks_left: int = 0
var sudden_death: bool = false
var winner_team: int = MatchRules.NO_TEAM


func _init(p_rules: MatchRules = null, player_count: int = 0) -> void:
	rules = p_rules if p_rules != null else MatchRules.stock()
	ticks_left = rules.duration_ticks
	for i: int in player_count:
		scores.append(0)
		last_hit_by.append(NONE)
		last_hit_tick.append(0)


func is_timed() -> bool:
	return rules.mode == MatchRules.TIMED


## Ring-outs respawn without spending a stock (timed, until sudden death).
func infinite_stocks() -> bool:
	return is_timed() and not sudden_death


func note_hit(attacker: int, victim: int, tick: int) -> void:
	if attacker >= 0 and attacker != victim and victim >= 0 and victim < last_hit_by.size():
		last_hit_by[victim] = attacker
		last_hit_tick[victim] = tick


## Reads one tick's events in order (hits before ring-outs); returns the score events.
func observe(events: Array[Dictionary], tick: int, credit_ticks: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		var type := String(e.get("type", ""))
		if HIT_TYPES.has(type):
			note_hit(int(e.get("attacker", NONE)), int(e.get("target", NONE)), tick)
		elif type == "ringout":
			out.append_array(_on_ringout(int(e["id"]), tick, credit_ticks))
	return out


func _on_ringout(victim: int, tick: int, credit_ticks: int) -> Array[Dictionary]:
	if victim < 0 or victim >= scores.size():
		return []
	var by := last_hit_by[victim]
	var credited := by != NONE and tick - last_hit_tick[victim] <= credit_ticks
	last_hit_by[victim] = NONE
	if not is_timed() or sudden_death:
		return []
	var scorer := by if credited else victim
	var delta := 1 if credited else -1
	scores[scorer] += delta
	return [{"type": "score", "id": scorer, "delta": delta, "score": scores[scorer], "victim": victim}]


## Plain values for state_view()["mode"].
func view() -> Dictionary:
	return {"rule": rules.mode, "teams": rules.teams.duplicate(), "friendly_fire": rules.friendly_fire,
		"scores": scores.duplicate(), "ticks_left": ticks_left, "duration_ticks": rules.duration_ticks,
		"sudden_death": sudden_death, "winner_team": winner_team}


func to_data() -> Dictionary:
	return {"rules": rules.to_data(), "scores": scores.duplicate(), "last_hit_by": last_hit_by.duplicate(),
		"last_hit_tick": last_hit_tick.duplicate(), "ticks_left": ticks_left, "sudden_death": sudden_death,
		"winner_team": winner_team}


## Null unless d is a well-formed state for player_count fighters.
static func from_data(d: Dictionary, player_count: int) -> ModeState:
	for key: String in DATA_TYPES:
		if not d.has(key) or typeof(d[key]) != DATA_TYPES[key]:
			return null
	var r := MatchRules.from_data(d["rules"])
	if r == null or (r.mode == MatchRules.TEAM and r.teams.size() != player_count):
		return null
	for key: String in INT_ARRAYS:
		if not _ints(d[key], player_count):
			return null
	var s := ModeState.new(r, 0)
	s.scores.assign(d["scores"])
	s.last_hit_by.assign(d["last_hit_by"])
	s.last_hit_tick.assign(d["last_hit_tick"])
	s.ticks_left = d["ticks_left"]
	s.sudden_death = d["sudden_death"]
	s.winner_team = d["winner_team"]
	for by: int in s.last_hit_by:
		if by < NONE or by >= player_count:
			return null
	return s


static func _ints(a: Array, size: int) -> bool:
	if a.size() != size:
		return false
	for v: Variant in a:
		if typeof(v) != TYPE_INT:
			return false
	return true
