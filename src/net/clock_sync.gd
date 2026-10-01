class_name NetClockSync
extends RefCounted
## Keeps a client's tick clock in step with the host's (online design, clock drift). The client
## leads the host by about rtt/2 plus a small input buffer; what matters is that buffer, which the
## host reports directly in every snapshot (inputs queued for this slot after that tick, host-tick
## stamped). A smoothed buffer above TARGET_QUEUED means this client ticks too fast, below means too
## slow; the client scales its frame delta by scale() (at most ±MAX_NUDGE), so the host queue
## neither starves (held inputs, corrections) nor overflows (folded inputs, added latency).

## Inputs the host should hold for this client after each tick (absorbs jitter).
const TARGET_QUEUED := 2.0
## Rate change per tick of buffer error, and its bound (2 %: invisible, fixes 1 % drift).
const GAIN := 0.01
const MAX_NUDGE := 0.02
## Share of each new report in the smoothed buffer.
const SMOOTHING := 0.1

var _smoothed: float = TARGET_QUEUED
var _reports: int = 0


## One snapshot's report: inputs queued at the host for this client's slot.
func observe(queued: int) -> void:
	_reports += 1
	_smoothed = lerpf(_smoothed, float(queued), SMOOTHING)


## Multiplier for the client's frame delta (1.0 until the first report).
func scale() -> float:
	if _reports == 0:
		return 1.0
	return 1.0 + clampf((TARGET_QUEUED - _smoothed) * GAIN, -MAX_NUDGE, MAX_NUDGE)


func smoothed_queue() -> float:
	return _smoothed
