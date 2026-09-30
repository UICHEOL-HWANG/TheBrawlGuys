class_name InputFeatures
extends RefCounted
## Per-slot input habits (platform A8, analytics-strategy §3.2) from each tick's InputFrames:
## presses per action (rising edges), mash presses (same button again within MASH_WINDOW_TICKS,
## the default combo buffer), 8-way direction changes, guard hold time and idle gaps
## (IDLE_GAP_TICKS of neutral input in a row, counted once per gap: away vs. giving up).
## press_special counts each forming of the special chord (heavy + guard held together, X+C —
## what SpecialRunner reads); its buttons already count as heavy / guard presses.

const ACTIONS := {
	"jump": InputCodec.JUMP, "light": InputCodec.LIGHT, "heavy": InputCodec.HEAVY,
	"guard": InputCodec.GUARD, "grab": InputCodec.GRAB,
}
const SPECIAL_CHORD := InputCodec.HEAVY | InputCodec.GUARD
const MASH_WINDOW_TICKS := 10
const IDLE_GAP_TICKS := 5 * SimTime.TICK_RATE
const SECTORS := 8
const NO_DIRECTION := -1
const TICKS_PER_MINUTE := 60.0 * SimTime.TICK_RATE
const RATE_STEP := 0.1
const RATIO_STEP := 0.001

var _slots: Array[Dictionary] = []


func _init(slot_count: int) -> void:
	for i: int in slot_count:
		var presses := {}
		for action: String in ACTIONS:
			presses[action] = 0
		_slots.append({"code": InputCodec.NEUTRAL, "dir": NO_DIRECTION, "presses": presses, "last_press": {},
			"mashes": 0, "chords": 0, "dir_changes": 0, "guard_ticks": 0, "idle_run": 0, "idle_gaps": 0, "ticks": 0})


## One tick's inputs in slot order (missing slots are neutral, as in World).
func observe(inputs: Array) -> void:
	for slot: int in _slots.size():
		var f: InputFrame = inputs[slot] if slot < inputs.size() else null
		_observe_slot(_slots[slot], InputCodec.pack(f) if f != null else InputCodec.NEUTRAL)


func summary(slot: int) -> Dictionary:
	var s := _slots[slot]
	var total := 0
	var out := {}
	for action: String in ACTIONS:
		out["press_" + action] = int(s["presses"][action])
		total += int(s["presses"][action])
	out["press_special"] = int(s["chords"])
	var ticks := maxi(int(s["ticks"]), 1)
	out["inputs_per_min"] = snappedf(total * TICKS_PER_MINUTE / ticks, RATE_STEP)
	out["direction_changes"] = int(s["dir_changes"])
	out["mash_ratio"] = snappedf(float(s["mashes"]) / total, RATIO_STEP) if total > 0 else 0.0
	out["guard_hold_ratio"] = snappedf(float(s["guard_ticks"]) / ticks, RATIO_STEP)
	out["idle_gaps"] = int(s["idle_gaps"])
	return out


func _observe_slot(s: Dictionary, code: int) -> void:
	var tick := int(s["ticks"])
	var pressed := InputCodec.buttons(code) & ~InputCodec.buttons(int(s["code"]))
	for action: String in ACTIONS:
		if pressed & int(ACTIONS[action]):
			_press(s, action, tick)
	if InputCodec.buttons(code) & SPECIAL_CHORD == SPECIAL_CHORD \
			and InputCodec.buttons(int(s["code"])) & SPECIAL_CHORD != SPECIAL_CHORD:
		s["chords"] = int(s["chords"]) + 1
	_track_direction(s, code)
	if InputCodec.buttons(code) & InputCodec.GUARD:
		s["guard_ticks"] = int(s["guard_ticks"]) + 1
	s["idle_run"] = int(s["idle_run"]) + 1 if code == InputCodec.NEUTRAL else 0
	if int(s["idle_run"]) == IDLE_GAP_TICKS:
		s["idle_gaps"] = int(s["idle_gaps"]) + 1
	s["ticks"] = tick + 1
	s["code"] = code


func _press(s: Dictionary, action: String, tick: int) -> void:
	s["presses"][action] = int(s["presses"][action]) + 1
	var last: Dictionary = s["last_press"]
	if last.has(action) and tick - int(last[action]) <= MASH_WINDOW_TICKS:
		s["mashes"] = int(s["mashes"]) + 1
	last[action] = tick


## A change between two non-neutral 8-way directions (letting go in between does not reset it).
func _track_direction(s: Dictionary, code: int) -> void:
	var x := InputCodec.axis(code, 0)
	var z := InputCodec.axis(code, 1)
	if x == 0.0 and z == 0.0:
		return
	var sector := posmod(roundi(atan2(z, x) / (TAU / SECTORS)), SECTORS)
	if int(s["dir"]) != NO_DIRECTION and sector != int(s["dir"]):
		s["dir_changes"] = int(s["dir_changes"]) + 1
	s["dir"] = sector
