class_name ComboTracker
extends RefCounted
## The HUD's "N연타" badge (design.md DS-CMP-22, render-only): clean hits ("hit" events, not
## guarded ones) by one attacker on the same target, each landing within WINDOW_TICKS of the
## previous one, count up; another target, a gap or a guarded hit starts over. Reads sim events
## only, never writes to the sim.

## One second at 60 Hz.
const WINDOW_TICKS := 60

var _runs: Dictionary = {}  # attacker -> {"target": int, "count": int, "tick": int}


## events: the sim events since the last call (World.state_view events), all stamped `tick`.
func on_events(events: Array, tick: int) -> void:
	for e: Variant in events:
		var d := e as Dictionary
		if d == null:
			continue
		var type := String(d.get("type", ""))
		if type == "guard_hit":
			_runs.erase(int(d.get("attacker", -1)))
		elif type == "hit":
			_note(int(d.get("attacker", -1)), int(d.get("target", -1)), tick)


func _note(attacker: int, target: int, tick: int) -> void:
	if attacker < 0 or attacker == target:
		return
	var run: Dictionary = _runs.get(attacker, {})
	var going := not run.is_empty() and int(run["target"]) == target and tick - int(run["tick"]) <= WINDOW_TICKS
	_runs[attacker] = {"target": target, "count": int(run["count"]) + 1 if going else 1, "tick": tick}


## The attacker's running hit count at `tick` (0 once the window has passed).
func count(attacker: int, tick: int) -> int:
	var run: Dictionary = _runs.get(attacker, {})
	if run.is_empty() or tick - int(run["tick"]) > WINDOW_TICKS:
		return 0
	return int(run["count"])


func reset() -> void:
	_runs.clear()
