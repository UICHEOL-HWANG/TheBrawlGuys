class_name NetInterpolation
extends RefCounted
## Remote fighters drawn ~net_interp_delay_ms behind the newest snapshot (PRD-NET-02). Keeps the
## host's state views by host tick; once per client tick advance() moves the render clock one tick
## and eases it toward (newest - delay), and view() blends the two snapshots around it: fighter
## positions lerp (unless the fighter respawned in between), everything else comes from the older
## one. compose() puts the client's own predicted fighter into that view, so MatchStage / HUD get
## one ordinary state_view per tick and keep lerping prev -> curr as in a local match.

const MAX_VIEWS := 32
## Share of the render clock's error removed per tick (smooth catch-up after jitter).
const CATCH_UP := 0.1

var _delay: float
## {"tick": int, "view": Dictionary}, oldest first.
var _views: Array[Dictionary] = []
var _t: float = -1.0


func _init(delay_ticks: float) -> void:
	_delay = maxf(delay_ticks, 0.0)


static func delay_ticks(config: GameConfig) -> float:
	return config.net_interp_delay_ms / 1000.0 * SimTime.TICK_RATE


func push(tick: int, view: Dictionary) -> void:
	if not _views.is_empty() and tick <= int(_views[-1]["tick"]):
		return
	_views.append({"tick": tick, "view": view})
	if _views.size() > MAX_VIEWS:
		_views.remove_at(0)
	if _t < 0.0:
		_t = float(tick) - _delay
	_clamp()


func advance() -> void:
	if _views.is_empty():
		return
	_t += 1.0
	var target := float(_views[-1]["tick"]) - _delay
	if absf(target - _t) > maxf(_delay, 6.0):
		_t = target
	else:
		_t += (target - _t) * CATCH_UP
	_clamp()


func render_tick() -> float:
	return _t


func has_views() -> bool:
	return not _views.is_empty()


## The blended host view at the render clock ({} before the first snapshot).
func view() -> Dictionary:
	if _views.is_empty():
		return {}
	for i: int in range(_views.size() - 1, -1, -1):
		var a: Dictionary = _views[i]
		if float(a["tick"]) <= _t:
			if i == _views.size() - 1:
				return a["view"]
			var b: Dictionary = _views[i + 1]
			var frac := (_t - float(a["tick"])) / float(int(b["tick"]) - int(a["tick"]))
			return blend(a["view"], b["view"], frac)
	return _views[0]["view"]


## The view to draw: remote fighters from view(), the own fighter (slot) from the predicted view,
## tick from the predicted view (it only moves forward), events as given.
func compose(predicted: Dictionary, slot: int, events: Array) -> Dictionary:
	var base := view()
	var out := predicted.duplicate() if base.is_empty() else base.duplicate()
	var fighters: Array = (out["fighters"] as Array).duplicate()
	var own: Array = predicted["fighters"]
	if slot >= 0 and slot < fighters.size() and slot < own.size():
		fighters[slot] = own[slot]
	out["fighters"] = fighters
	out["tick"] = predicted["tick"]
	out["events"] = events
	return out


static func blend(a: Dictionary, b: Dictionary, frac: float) -> Dictionary:
	var out := a.duplicate()
	var fa: Array = a["fighters"]
	var fb: Array = b["fighters"]
	var fighters: Array = []
	for i: int in fa.size():
		var f: Dictionary = fa[i]
		if i < fb.size() and int(fb[i]["spawn_id"]) == int(f["spawn_id"]):
			f = f.duplicate()
			f["pos"] = (f["pos"] as Vector3).lerp(fb[i]["pos"], clampf(frac, 0.0, 1.0))
		fighters.append(f)
	out["fighters"] = fighters
	return out


func _clamp() -> void:
	_t = clampf(_t, float(_views[0]["tick"]), float(_views[-1]["tick"]))
