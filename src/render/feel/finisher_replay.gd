class_name FinisherReplay
extends RefCounted
## Finishing replay timing (design.md GD-CAM-02): keeps the last BUFFER_S of tick views; when the
## match ends on a ring-out, plays them back from LEAD_S before the last hit on the knocked-out
## fighter (NO_HIT_LEAD_S before the ring-out when nothing hit it), at SLOW_SPEED around the hit and
## FAST_SPEED through the flight, then holds TAIL_S before the result. The caller sets
## Engine.time_scale to speed() and feeds advance() the game delta. Render only: the sim is over.

const BUFFER_S := 2.0
const LEAD_S := 0.15
const NO_HIT_LEAD_S := 0.8
## Game seconds after the hit still played at SLOW_SPEED.
const SLOW_AFTER_HIT_S := 0.3
const SLOW_SPEED := 0.25
const FAST_SPEED := 0.6
## Real seconds: the close shot easing in, and the hold on the last tick while it eases back out.
const ZOOM_IN_S := DS.MOTION_BASE
const TAIL_S := 0.6
const NONE := -1

var _frames: Array[Dictionary] = []
var _cap: int = SimTime.to_ticks(BUFFER_S) + 1
var _victim: int = NONE
var _start: int = 0
var _hit: int = NONE
## Playback position in buffer indices (fractional = between two ticks).
var _cursor: float = 0.0
var _emitted: int = 0
var _real: float = 0.0
var _tail: float = 0.0
var _reduce_motion: bool = false


## One tick's state view (the newest last). Ticks after the one that ended the match are dropped,
## so a frame that runs on past the end still replays the ending.
func record(view: Dictionary) -> void:
	if not _frames.is_empty() and bool(_frames.back().get("match_over", false)):
		return
	_frames.append(view)
	if _frames.size() > _cap:
		_frames.pop_front()


func clear() -> void:
	_frames.clear()
	stop()


## Starts when the newest tick has a ring-out; false (and nothing plays) otherwise.
func start(reduce_motion: bool = false) -> bool:
	stop()
	var last := _frames.size() - 1
	if last < 1:
		return false
	var victim := _ringout_id(_frames[last]["events"])
	if victim == NONE:
		return false
	_victim = victim
	_hit = _last_hit_on(victim)
	var from := _hit - SimTime.to_ticks(LEAD_S) if _hit != NONE else last - SimTime.to_ticks(NO_HIT_LEAD_S)
	_start = clampi(from, 0, last - 1)
	_cursor = float(_start)
	_emitted = _start
	_reduce_motion = reduce_motion
	return true


func stop() -> void:
	_victim = NONE
	_hit = NONE
	_real = 0.0
	_tail = 0.0


func is_active() -> bool:
	return _victim != NONE


func victim() -> int:
	return _victim


## Sim tick the playback starts from (its next tick is the first one drawn).
func start_tick() -> int:
	return int(_frames[_start]["tick"]) if not _frames.is_empty() else 0


## The Engine.time_scale to play at (1 when idle).
func speed() -> float:
	if not is_active():
		return 1.0
	if _hit != NONE and _cursor < float(_hit + SimTime.to_ticks(SLOW_AFTER_HIT_S)):
		return SLOW_SPEED
	return FAST_SPEED


## Moves playback by game_delta. Returns {prev, curr, alpha, index (of curr), frames (ticks reached
## this step, oldest first, each to be presented once), done}.
func advance(game_delta: float) -> Dictionary:
	var last := _frames.size() - 1
	var step := maxf(game_delta, 0.0)
	var real := step / maxf(speed(), 0.0001)
	_real += real
	if _cursor >= float(last):
		_tail += real
	_cursor = minf(_cursor + step * SimTime.TICK_RATE, float(last))
	var i := mini(floori(_cursor), last - 1)
	var reached: Array[Dictionary] = []
	while _emitted < i + 1:
		_emitted += 1
		reached.append(_frames[_emitted])
	return {"prev": _frames[i], "curr": _frames[i + 1], "alpha": clampf(_cursor - float(i), 0.0, 1.0),
		"index": i + 1, "frames": reached, "done": _cursor >= float(last) and _tail >= TAIL_S}


## 0 (match framing) .. 1 (close shot on the victim): eases in, then back out over the tail.
func camera_weight() -> float:
	if not is_active() or _reduce_motion:
		return 0.0
	var x := clampf(_real / ZOOM_IN_S, 0.0, 1.0)
	var zoom_in := 1.0 - (1.0 - x) * (1.0 - x)
	var y := clampf(_tail / TAIL_S, 0.0, 1.0)
	var back := 4.0 * y * y * y if y < 0.5 else 1.0 - pow(-2.0 * y + 2.0, 3.0) / 2.0
	return zoom_in * (1.0 - back)


## The victim's feet at this step; once it is knocked out, where it last was in the arena.
func focus(step: Dictionary) -> Vector3:
	var now := _fighter(step["curr"])
	if not now.is_empty() and int(now["state"]) != Fighter.State.KO:
		var before := _fighter(step["prev"])
		var from: Vector3 = before.get("pos", now["pos"])
		return from.lerp(now["pos"], float(step["alpha"]))
	for k: int in range(int(step["index"]), -1, -1):
		var f := _fighter(_frames[k])
		if not f.is_empty() and int(f["state"]) != Fighter.State.KO:
			return f["pos"]
	return Vector3.ZERO


func _fighter(view: Dictionary) -> Dictionary:
	for f: Dictionary in view.get("fighters", []):
		if int(f["id"]) == _victim:
			return f
	return {}


func _last_hit_on(victim: int) -> int:
	for k: int in range(_frames.size() - 1, -1, -1):
		for e: Dictionary in _frames[k]["events"]:
			if String(e["type"]) == "hit" and int(e["target"]) == victim:
				return k
	return NONE


static func _ringout_id(events: Array) -> int:
	var id := NONE
	for e: Dictionary in events:
		if String(e["type"]) == "ringout":
			id = int(e["id"])
	return id
