class_name LaunchFeatures
extends RefCounted
## Launch signals per slot (event schema 8): DI use and launches survived. Views and inputs only.
## DI: a clean "hit" marks its target; the sim bends the launch with the stick held on the
## target's first advancing tick after the hitstop (LaunchInfluence, verified: Motion counts the
## hitstop down, the view of the last frozen tick shows 0). On that tick: di_inputs counts a
## non-neutral stick, and di_perp is the stick's share perpendicular to the launch (0 = along or
## neutral, 1 = fully sideways: the most DI). The view has no velocity, so the launch direction is
## the target's horizontal motion on that tick — already bent by at most di_max_deg, a small error.
## Tumbles: a strong launch tumbles (view "tumbling"); survived = the tumble ended in the same life.

## Shorter sticks count as neutral.
const STICK_MIN := 0.3
## Less horizontal motion than this on the DI tick (m): no direction to measure against.
const MOVE_MIN := 0.001
const RATIO_STEP := 0.001

var _pending: Dictionary = {}  # launched slot -> true until its DI tick
var _tumble_life: Dictionary = {}  # tumbling slot -> spawn_id when the tumble began
var _slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		_slots.append({"di_inputs": 0, "perp_sum": 0.0, "perp_n": 0, "tumbles": 0, "tumbles_survived": 0})


## One tick: its sim events, the last and current fighter views, its inputs (may be empty).
func observe(events: Array, prev: Array, fighters: Array, inputs: Array) -> void:
	_check_di(prev, fighters, inputs)
	for e: Dictionary in events:
		match String(e["type"]):
			"hit":
				_pending[int(e.get("target", -1))] = true  # out-of-range slots are dropped by _check_di
			"ringout":
				_tumble_life.erase(int(e.get("id", -1)))
	_track_tumbles(prev, fighters)


func summary(slot: int) -> Dictionary:
	var s := _slots[slot]
	var n := int(s["perp_n"])
	return {"di_inputs": s["di_inputs"], "di_perp_avg": snappedf(float(s["perp_sum"]) / n, RATIO_STEP) if n > 0 else null,
		"tumbles": s["tumbles"], "tumbles_survived": s["tumbles_survived"]}


func _check_di(prev: Array, fighters: Array, inputs: Array) -> void:
	for slot: int in _pending.keys():
		if slot < 0 or slot >= mini(prev.size(), fighters.size()) or slot >= mini(inputs.size(), _slots.size()):
			_pending.erase(slot)
			continue
		var before: Dictionary = prev[slot]
		if int(before.get("hitstop_ticks", 0)) > 0:
			continue  # still frozen: DI comes later
		_pending.erase(slot)
		var now: Dictionary = fighters[slot]
		if int(before["state"]) != Fighter.State.HITSTUN or int(before["spawn_id"]) != int(now["spawn_id"]):
			continue
		var input: InputFrame = inputs[slot]
		var stick := Vector2(input.move_x, input.move_z).limit_length(1.0)
		var s := _slots[slot]
		if stick.length() >= STICK_MIN:
			s["di_inputs"] = int(s["di_inputs"]) + 1
		var from: Vector3 = before["pos"]
		var to: Vector3 = now["pos"]
		var moved := Vector2(to.x - from.x, to.z - from.z)
		if moved.length() > MOVE_MIN:
			var perp := absf(moved.normalized().cross(stick)) if stick.length() >= STICK_MIN else 0.0
			s["perp_sum"] = float(s["perp_sum"]) + perp
			s["perp_n"] = int(s["perp_n"]) + 1


func _track_tumbles(prev: Array, fighters: Array) -> void:
	for i: int in mini(mini(prev.size(), fighters.size()), _slots.size()):
		var was := bool((prev[i] as Dictionary).get("tumbling", false))
		var now := bool((fighters[i] as Dictionary).get("tumbling", false))
		var spawn := int(fighters[i]["spawn_id"])
		if now and not was:
			_slots[i]["tumbles"] = int(_slots[i]["tumbles"]) + 1
			_tumble_life[i] = spawn
		elif was and not now and _tumble_life.has(i):
			if int(_tumble_life[i]) == spawn:
				_slots[i]["tumbles_survived"] = int(_slots[i]["tumbles_survived"]) + 1
			_tumble_life.erase(i)
