class_name TickStats
extends RefCounted
## Debug-panel loop numbers: measured ticks per second (over one-second windows) and the
## smoothed sim cost per tick.

var _ticks: int = 0
var _time: float = 0.0
var _tps: float = 0.0
var _sim_us: float = 0.0


func add_sim_cost(usec: int, smoothing: float) -> void:
	_sim_us = lerpf(_sim_us, float(usec), smoothing)


func add_frame(delta: float, ticks: int) -> void:
	_ticks += ticks
	_time += delta
	if _time >= 1.0:
		_tps = _ticks / _time
		_ticks = 0
		_time = 0.0


func tps() -> float:
	return _tps


func text() -> String:
	return "%.0f tps · sim %.3f ms" % [_tps, _sim_us / 1000.0]
