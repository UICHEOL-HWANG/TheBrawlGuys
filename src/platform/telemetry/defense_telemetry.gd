class_name DefenseTelemetry
extends RefCounted
## Defense and recovery counters for CombatTelemetry (event schema 8): dodges by kind, perfect
## guards, guard breaks suffered and caused, knockdowns, techs, getups by kind and clean hits taken
## (launches). Reads sim events only (principle T3). DI, reactions and other skill signals that
## need views and inputs are SkillFeatures.

## A guard break is credited to the last fighter whose hit the victim blocked within this window.
const BREAK_CREDIT_TICKS := 60
const DODGE_COUNTERS := {"roll": "dodges_roll", "air": "dodges_air"}
const GETUP_COUNTERS := {"stand": "getups_stand", "roll": "getups_roll", "attack": "getups_attack"}

var _count: Callable  # (slot, counter)
var _blocked: Dictionary = {}  # guarder -> [attacker, tick] of the last blocked hit


func _init(count: Callable) -> void:
	_count = count


## Handles one sim event; returns extra raw-row fields (guard_break: the credited attacker_slot).
func on_event(e: Dictionary, tick: int) -> Dictionary:
	match String(e["type"]):
		"hit":
			_count.call(int(e["target"]), "hits_taken")
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
		attacker = -1  # no blocked hit in the window: guard held until it drained
	return {"attacker_slot": attacker}


func _count_kind(e: Dictionary, counters: Dictionary) -> void:
	var counter := String(counters.get(String(e.get("kind", "")), ""))
	if not counter.is_empty():
		_count.call(int(e["fighter"]), counter)
