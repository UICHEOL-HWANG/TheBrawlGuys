class_name ReactionFeatures
extends RefCounted
## Defensive skill per slot (event schema 8). Views, events and guard presses only.
## threats_faced: an opponent's swing started within THREAT_RANGE (one pending threat at a time,
## a new one replaces it once REACT_WINDOW_TICKS passed). reactions / reaction_ticks_avg: a guard
## press (guard or dodge: both start on it) 1..REACT_WINDOW_TICKS ticks after the threat started —
## a press on the same tick cannot have seen the swing. roll_evades: an opponent's swing was active
## within THREAT_RANGE while this slot was intangible in a dodge (state DODGE; getup and tech
## intangibility do not count), and the swing never hit it.
## tech_attempts: tumbles in which guard was pressed (success = the "techs" counter).

const THREAT_RANGE := 3.0
const REACT_WINDOW_TICKS := 30
const NONE := -1
const TICK_STEP := 0.1

var _threat_at: Array[int] = []
var _tried_tech: Array[bool] = []
var _swings: Dictionary = {}  # attacker -> {"dodgers": {slot: true}, "hit": {slot: true}}
var _slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		_threat_at.append(NONE)
		_tried_tech.append(false)
		_slots.append({"threats_faced": 0, "reactions": 0, "reaction_ticks": 0, "roll_evades": 0, "tech_attempts": 0})


## presses: per slot {"guard": bool, ...} rising edges this tick (empty without inputs).
## teams: slot -> team in team mode, else empty (everyone is an opponent).
func observe(tick: int, events: Array, prev: Array, fighters: Array, presses: Array, teams: Array) -> void:
	for e: Dictionary in events:
		if String(e["type"]) in ["hit", "guard_hit"] and e.has("target") and _swings.has(int(e.get("attacker", NONE))):
			_swings[int(e["attacker"])]["hit"][int(e["target"])] = true
	for i: int in mini(presses.size(), _slots.size()):
		if bool(presses[i]["guard"]):
			_on_guard_press(i, tick, prev)
	for i: int in mini(fighters.size(), _slots.size()):
		if not bool((fighters[i] as Dictionary).get("tumbling", false)):
			_tried_tech[i] = false
		_observe_swing(i, tick, prev, fighters, teams)
	_mark_dodgers(fighters, teams)


## Swings still open at match end are dropped (their outcome is unknown).
func summary(slot: int) -> Dictionary:
	var s := _slots[slot]
	var n := int(s["reactions"])
	return {"threats_faced": s["threats_faced"], "reactions": n,
		"reaction_ticks_avg": snappedf(float(s["reaction_ticks"]) / n, TICK_STEP) if n > 0 else null,
		"roll_evades": s["roll_evades"], "tech_attempts": s["tech_attempts"]}


func _on_guard_press(slot: int, tick: int, prev: Array) -> void:
	var s := _slots[slot]
	var since := tick - _threat_at[slot]
	if _threat_at[slot] != NONE and since >= 1 and since <= REACT_WINDOW_TICKS:
		s["reactions"] = int(s["reactions"]) + 1
		s["reaction_ticks"] = int(s["reaction_ticks"]) + since
		_threat_at[slot] = NONE
	if slot < prev.size() and bool((prev[slot] as Dictionary).get("tumbling", false)) and not _tried_tech[slot]:
		_tried_tech[slot] = true
		s["tech_attempts"] = int(s["tech_attempts"]) + 1


## Same swing boundaries as AttackTracker: entering ATTACK or a restarted attack opens one.
func _observe_swing(i: int, tick: int, prev: Array, fighters: Array, teams: Array) -> void:
	var a: Dictionary = prev[i] if i < prev.size() else {}
	var b: Dictionary = fighters[i]
	var attacking := int(b["state"]) == Fighter.State.ATTACK
	var restarted := attacking and (int(a.get("state", NONE)) != Fighter.State.ATTACK
			or int(a.get("attack_kind", NONE)) != int(b["attack_kind"])
			or int(b["attack_ticks"]) < int(a.get("attack_ticks", 0)))
	if _swings.has(i) and (restarted or not attacking):
		_close_swing(i)
	if restarted:
		_swings[i] = {"dodgers": {}, "hit": {}}
		for j: int in _near_opponents(i, fighters, teams):
			if _threat_at[j] == NONE or tick - _threat_at[j] > REACT_WINDOW_TICKS:
				_threat_at[j] = tick
				_slots[j]["threats_faced"] = int(_slots[j]["threats_faced"]) + 1


func _close_swing(attacker: int) -> void:
	var swing: Dictionary = _swings[attacker]
	_swings.erase(attacker)
	for j: int in swing["dodgers"]:
		if not (swing["hit"] as Dictionary).has(j):
			_slots[j]["roll_evades"] = int(_slots[j]["roll_evades"]) + 1


func _mark_dodgers(fighters: Array, teams: Array) -> void:
	for attacker: int in _swings:
		for j: int in _near_opponents(attacker, fighters, teams):
			var f: Dictionary = fighters[j]
			if int(f["state"]) == Fighter.State.DODGE and bool(f.get("is_dodging", false)):
				_swings[attacker]["dodgers"][j] = true


## Living opponents of slot within THREAT_RANGE.
func _near_opponents(slot: int, fighters: Array, teams: Array) -> Array[int]:
	var out: Array[int] = []
	var at: Vector3 = fighters[slot]["pos"]
	for j: int in mini(fighters.size(), _slots.size()):
		var f: Dictionary = fighters[j]
		var ally := j < teams.size() and slot < teams.size() and int(teams[j]) == int(teams[slot])
		if j == slot or ally or int(f["state"]) == Fighter.State.KO:
			continue
		if at.distance_to(f["pos"]) <= THREAT_RANGE:
			out.append(j)
	return out
