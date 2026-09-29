class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): hit puffs sized by knockback, screen shake that
## starts when hitstop ends, a full-strength shake on ring-out. Render-side only.

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
				var spark := HitSpark.new()
				add_child(spark)
				spark.play(e["pos"], kb >= _config.spark_large_threshold)
				_shake.add(kb, float(e["hitstop_ticks"]) / SimTime.TICK_RATE)
			"ringout":
				_shake.add(_config.shake_max / maxf(_config.shake_per_knockback, 0.0001), 0.0)


func _process(delta: float) -> void:
	if _shake != null and _camera != null:
		_camera.set_shake_offset(_shake.update(delta))
