class_name NetStats
extends RefCounted
## Online match network health for telemetry (online design "Tracking"): round-trip samples,
## prediction corrections (client) and disconnects. props() is the flat, JSON-safe summary the
## match telemetry attaches; the sessions only count, they never send anything themselves.

const MAX_SAMPLES := 600

var is_host: bool = false
var corrections: int = 0
var disconnects: int = 0
var _rtt: PackedFloat32Array = PackedFloat32Array()


func _init(p_is_host: bool = false) -> void:
	is_host = p_is_host


func add_rtt(ms: float) -> void:
	if ms < 0.0:
		return
	_rtt.append(ms)
	if _rtt.size() > MAX_SAMPLES:
		_rtt.remove_at(0)


## Latest round-trip estimate in ms (-1 before the first sample).
func rtt_ms() -> float:
	return _rtt[_rtt.size() - 1] if not _rtt.is_empty() else -1.0


## p in 0..1 over the kept samples; null without samples.
func rtt_percentile(p: float) -> Variant:
	if _rtt.is_empty():
		return null
	var sorted := _rtt.duplicate()
	sorted.sort()
	return roundf(sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)])


func props() -> Dictionary:
	return {"net_host": is_host, "rtt_p50": rtt_percentile(0.5), "rtt_p95": rtt_percentile(0.95),
		"corrections": corrections, "disconnects": disconnects}
