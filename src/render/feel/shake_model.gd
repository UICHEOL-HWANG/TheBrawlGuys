class_name ShakeModel
extends RefCounted
## Screen shake (design.md GD-FEEL-02): amplitude = min(knockback x shake_per_knockback, shake_max),
## starting when hitstop ends, decaying exponentially. Deterministic sine pattern, no randomness.

## Incommensurate frequencies (Hz) so the offset never settles into a visible loop.
const FREQ_X := 41.0
const FREQ_Y := 53.0
const FREQ_PHASE := 1.3

var _config: GameConfig
var _amplitude: float = 0.0
var _time: float = 0.0
## Pending shakes as Vector2(seconds_until_start, amplitude).
var _pending: Array[Vector2] = []


func _init(p_config: GameConfig) -> void:
	_config = p_config


func add(knockback: float, delay_seconds: float) -> void:
	var amp := minf(knockback * _config.shake_per_knockback, _config.shake_max)
	_pending.append(Vector2(delay_seconds, amp))


func amplitude() -> float:
	return _amplitude


func update(delta: float) -> Vector3:
	var still: Array[Vector2] = []
	for p: Vector2 in _pending:
		var left := p.x - delta
		if left <= 0.0:
			_amplitude = maxf(_amplitude, p.y)
		else:
			still.append(Vector2(left, p.y))
	_pending = still
	_amplitude *= exp(-_config.shake_decay * delta) if delta > 0.0 else 1.0
	_time += delta
	if _amplitude <= 0.0:
		return Vector3.ZERO
	return Vector3(sin(_time * FREQ_X), sin(_time * FREQ_Y + FREQ_PHASE), 0.0) * _amplitude
