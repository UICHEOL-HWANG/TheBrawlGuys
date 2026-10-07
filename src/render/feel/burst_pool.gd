class_name BurstPool
extends Node3D
## A fixed set of MagicBursts reused round-robin (FxPool): when all are busy the oldest is
## recycled, so a storm of bolts never builds nodes mid-match. Spark counts follow the quality's
## particle scale (LOW halves them).

## Live bursts at full quality (LOW keeps half).
const CAP := 12

var _bursts: Array[MagicBurst] = []
var _pool: FxPool
var _particle_scale: float = 1.0


func setup(particle_scale: float) -> void:
	_particle_scale = particle_scale
	_pool = FxPool.new(maxi(roundi(CAP * particle_scale), 4))
	for i: int in _pool.size():
		var b := MagicBurst.new()
		add_child(b)
		_bursts.append(b)


func play(at: Vector3, look: Dictionary) -> MagicBurst:
	var b := _bursts[_pool.acquire()]
	b.play(at, look, maxi(roundi(int(look.get("sparks", 0)) * _particle_scale), 0))
	return b


## A quality change: spark counts follow the new particle scale (the pool size stays).
func set_particle_scale(particle_scale: float) -> void:
	_particle_scale = particle_scale


## Ages every live burst (CombatFxLayer calls this every frame).
func advance(delta: float) -> void:
	for b: MagicBurst in _bursts:
		b.advance(delta)


func stop_all() -> void:
	for b: MagicBurst in _bursts:
		b.stop()


func active() -> Array[MagicBurst]:
	return _bursts.filter(func(b: MagicBurst) -> bool: return b.active())


func cap() -> int:
	return _pool.size()
