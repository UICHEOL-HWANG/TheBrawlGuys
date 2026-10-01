class_name DefenseTelemetry
extends RefCounted
## Defense and recovery counters for CombatTelemetry (event schema 8): dodges by kind, perfect
## guards, guard breaks suffered and caused, knockdowns, techs, getups by kind, clean hits taken
## and DI use. Reads sim events and views only (principle T3).
## DI: the sim bends a launch with the stick held on the target's first tick after the hit's
## hitstop (LaunchInfluence). The view carries no velocity, so the launch angle is unknown here;
## what is measured is whether the launched fighter held a non-neutral stick on that tick
## (di_inputs / hits_taken = DI attempt rate), not how much the launch turned.

## A guard break is credited to the last fighter whose hit the victim blocked within this window.
const BREAK_CREDIT_TICKS := 60
## Shorter sticks count as neutral (no DI).
const DI_STICK_MIN := 0.3
const DODGE_COUNTERS := {"roll": "dodges_roll", "air": "dodges_air"}
const GETUP_COUNTERS := {"stand": "getups_stand", "roll": "getups_roll", "attack": "getups_attack"}

var _count: Callable  # (slot, counter)
var _blocked: Dictionary = {}  # guarder -> [attacker, tick] of the last blocked hit
var _di_pending: Dictionary = {}  # launched slot -> true until its DI tick is seen


func _init(count: Callable) -> void:
	_count = count


## Start of a tick, before its events: launched fighters whose hitstop ended in the previous view
## advance this tick and take DI from this tick's stick (inputs: InputFrames in slot order).
func begin_tick(prev: Array, inputs: Array) -> void:
	for slot: int in _di_pending.keys():
		if slot >= prev.size() or slot >= inputs.size():
			_di_pending.erase(slot)
			continue
		var before: Dictionary = prev[slot]
		if int(before.get("hitstop_ticks", 0)) > 0:
			continue  # still frozen: DI comes later
		_di_pending.erase(slot)
		var input: InputFrame = inputs[slot]
		if int(before["state"]) == Fighter.State.HITSTUN \
				and Vector2(input.move_x, input.move_z).length() >= DI_STICK_MIN:
			_count.call(slot, "di_inputs")


## Handles one sim event; returns extra raw-row fields (guard_break: the credited attacker_slot).
func on_event(e: Dictionary, tick: int) -> Dictionary:
	match String(e["type"]):
		"hit":
			var target := int(e["target"])
			_count.call(target, "hits_taken")
			_di_pending[target] = true
		"guard_hit":
			_blocked[int(e["target"])] = [int(e["attacker"]), tick]
		"perfect_guard":
			_count.call(int(e["fighter"]), "perfect_guards")
		"guard_break":
			return _on_break(int(e["fighter"]), tick)
		"dodge":
			_count_kind(e, DODGE_COUNTERS)
		"getup":
			_count_kind(e, GETUP_COUNTERS)
		"knockdown":
			_count.call(int(e["fighter"]), "knockdowns")
		"tech":
			_count.call(int(e["fighter"]), "techs")
	return {}


func _on_break(victim: int, tick: int) -> Dictionary:
	_count.call(victim, "guard_breaks")
	var last: Array = _blocked.get(victim, [-1, -BREAK_CREDIT_TICKS - 1])
	var attacker := int(last[0]) if tick - int(last[1]) <= BREAK_CREDIT_TICKS else -1
	if attacker >= 0 and attacker != victim:
		_count.call(attacker, "guard_breaks_caused")
	else:
		attacker = -1  # held guard until it drained, or the blocker is too long ago
	return {"attacker_slot": attacker}


func _count_kind(e: Dictionary, counters: Dictionary) -> void:
	var counter := String(counters.get(String(e.get("kind", "")), ""))
	if not counter.is_empty():
		_count.call(int(e["fighter"]), counter)
