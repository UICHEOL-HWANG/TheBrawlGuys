class_name PerfSampler
extends RefCounted
## One match's frame pacing for perf_sampled (platform A8, analytics-strategy §3.5): fps at the
## 5th and 50th percentile of frames (nearest rank) and spikes, frames taking longer than
## SPIKE_FACTOR x the median frame. Fed the render delta of every frame while the match runs.

const SPIKE_FACTOR := 2.0
const FPS_STEP := 0.1

var _frames := PackedFloat32Array()


func add_frame(delta: float) -> void:
	if delta > 0.0:
		_frames.append(delta)


## perf_sampled properties (without match_id).
func props() -> Dictionary:
	var n := _frames.size()
	if n == 0:
		return {"fps_p5": 0.0, "fps_p50": 0.0, "spike_count": 0, "frame_count": 0}
	var sorted := _frames.duplicate()
	sorted.sort()  # shortest frame first = highest fps first
	var median := sorted[_rank(0.5, n)]
	var spikes := 0
	for d: float in sorted:
		spikes += 1 if d > SPIKE_FACTOR * median else 0
	return {
		"fps_p5": snappedf(1.0 / sorted[n - 1 - _rank(0.05, n)], FPS_STEP),
		"fps_p50": snappedf(1.0 / median, FPS_STEP),
		"spike_count": spikes, "frame_count": n,
	}


## 0-based nearest-rank index of percentile p among n values.
static func _rank(p: float, n: int) -> int:
	return clampi(ceili(p * n) - 1, 0, n - 1)
