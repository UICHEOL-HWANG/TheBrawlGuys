class_name SpecialCutIn
extends RefCounted
## Special-move cut-in timing (Phase 5 T4, design.md GD-CAM-01): a sim special_start zooms the
## camera onto the caster (motion_base, out-quad), holds the close shot while the special plays
## (motion_calm), then eases back to the match framing (motion_slow, in-out-cubic). Render time
## only: nothing here slows or touches the sim, so tick rate and replay hashes never change.
## weight() drives the banner; camera_weight() the close shot (0 with reduce motion).

const IN_S := DS.MOTION_BASE
const HOLD_S := DS.MOTION_CALM
const OUT_S := DS.MOTION_SLOW
## Close shot: camera distance (m), pitch (deg, lower than cam_pitch so the pose reads) and the
## look-at height above the caster's feet (about its chest).
const ZOOM_DISTANCE := 7.0
const PITCH_DEG := 38.0
const FOCUS_HEIGHT := 0.9
const NONE := -1

var _reduce_motion: bool
var _slot: int = NONE
var _special: String = ""
var _t: float = 0.0


func _init(reduce_motion: bool = false) -> void:
	_reduce_motion = reduce_motion


static func total_seconds() -> float:
	return IN_S + HOLD_S + OUT_S


## Starts (or retargets) the cut-in on this frame's special_start events; the last one wins.
func on_events(events: Array) -> void:
	for e: Dictionary in events:
		if String(e.get("type", "")) == "special_start":
			start(int(e["fighter"]), String(e.get("special", "")))


## A new caster continues from the current zoom instead of cutting (no pop between two specials).
func start(slot: int, special: String) -> void:
	var w := weight()
	_slot = slot
	_special = special
	_t = IN_S * (1.0 - sqrt(1.0 - clampf(w, 0.0, 1.0)))  # inverse of the out-quad zoom-in


func update(delta: float) -> void:
	if not is_active():
		return
	_t += maxf(delta, 0.0)
	if _t >= total_seconds():
		reset()


## Eases out from the current zoom (the caster was knocked out or left the view).
func cancel() -> void:
	if not is_active() or _t >= IN_S + HOLD_S:
		return
	_t = IN_S + HOLD_S + OUT_S * _inverse_out(weight())


func reset() -> void:
	_slot = NONE
	_special = ""
	_t = 0.0


func is_active() -> bool:
	return _slot != NONE


func slot() -> int:
	return _slot


func special() -> String:
	return _special


func is_reduced() -> bool:
	return _reduce_motion


## 0 (match framing) .. 1 (full close shot).
func weight() -> float:
	if not is_active():
		return 0.0
	if _t < IN_S:
		var x := _t / IN_S
		return 1.0 - (1.0 - x) * (1.0 - x)
	if _t < IN_S + HOLD_S:
		return 1.0
	var y := clampf((_t - IN_S - HOLD_S) / OUT_S, 0.0, 1.0)
	return 1.0 - _in_out_cubic(y)


func camera_weight() -> float:
	return 0.0 if _reduce_motion else weight()


## The camera shot at weight w between the match framing (center, distance, pitch) and the close
## shot on focus (the caster's feet). Never pulls back from a camera that is already closer.
static func shot(center: Vector3, distance: float, pitch_deg: float, focus: Vector3, w: float) -> Dictionary:
	var k := clampf(w, 0.0, 1.0)
	return {
		"center": center.lerp(focus + Vector3.UP * FOCUS_HEIGHT, k),
		"distance": lerpf(distance, minf(distance, ZOOM_DISTANCE), k),
		"pitch": lerpf(pitch_deg, PITCH_DEG, k),
	}


static func _in_out_cubic(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


## x in 0..1 with 1 - in_out_cubic(x) == w (bisection; the curve is monotonic).
static func _inverse_out(w: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i: int in 24:
		var mid := (lo + hi) * 0.5
		if 1.0 - _in_out_cubic(mid) > w:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
