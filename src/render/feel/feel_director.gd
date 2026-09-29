class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): hit puffs sized by knockback, screen shake that
## starts when hitstop ends, a full-strength shake on ring-out, a small puff on guarded hits and a
## large puff plus shake on bomb explosions. Render-side only.

## Explosion shake as a fraction of shake_max.
const EXPLOSION_SHAKE_RATIO := 0.8

var _config: GameConfig
var _camera: CameraRig
var _shake: ShakeModel


func setup(config: GameConfig, camera: CameraRig) -> void:
	_config = config
	_camera = camera
	_shake = ShakeModel.new(config)


func on_events(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"hit":
				var kb: float = e["knockback"]
				_spark(e["pos"], kb >= _config.spark_large_threshold)
				_shake.add(kb, float(e["hitstop_ticks"]) / SimTime.TICK_RATE)
			"guard_hit":
				_spark(e["pos"], false)
			"explosion":
				_spark(e["pos"], true)
				_shake.add(_full_shake_knockback() * EXPLOSION_SHAKE_RATIO, 0.0)
			"ringout":
				_shake.add(_full_shake_knockback(), 0.0)


## A restart starts with a still camera (Phase 1 carry-over).
func reset() -> void:
	_shake = ShakeModel.new(_config)
	if _camera != null:
		_camera.set_shake_offset(Vector3.ZERO)


func shake_amplitude() -> float:
	return _shake.amplitude()


func _process(delta: float) -> void:
	if _shake == null:
		return
	var offset := _shake.update(delta)
	if _camera != null:
		_camera.set_shake_offset(offset)


func _spark(at: Vector3, large: bool) -> void:
	var spark := HitSpark.new()
	add_child(spark)
	spark.play(at, large)


## The knockback whose shake reaches shake_max.
func _full_shake_knockback() -> float:
	return _config.shake_max / maxf(_config.shake_per_knockback, 0.0001)
