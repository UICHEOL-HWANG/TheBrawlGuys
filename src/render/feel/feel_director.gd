class_name FeelDirector
extends Node3D
## Turns sim events into game feel (design.md §9): hit puffs sized by knockback, screen shake that
## starts when hitstop ends, a full-strength shake on ring-out, a small puff on guarded hits and a
## large puff plus shake on bomb explosions. Landing dust and knockback trails come from
## ViewEvents. Render-side only.

## Explosion shake as a fraction of shake_max.
const EXPLOSION_SHAKE_RATIO := 0.8

var _config: GameConfig
var _camera: CameraRig
var _shake: ShakeModel
var _trail: KnockbackTrail


func setup(config: GameConfig, camera: CameraRig) -> void:
	_config = config
	_camera = camera
	_shake = ShakeModel.new(config)
	_trail = KnockbackTrail.new()
	add_child(_trail)


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
				var at: Vector3 = e["pos"]
				at.y = maxf(at.y, DecorView.GROUND_Y)  # a fighter out at kill_y is far below the ground plane
				var burst := RingoutBurst.new()
				add_child(burst)
				burst.play(at, DecorView.is_water_ringout(e, _config.arena_radius), PlayerStyle.color(int(e["id"])),
						Quality.particle_scale(_config))
				if _camera != null:
					_camera.punch(1.0)


## Render-side events from ViewEvents (context F8).
func on_view_events(events: Array) -> void:
	var scale := Quality.particle_scale(_config)
	for e: Dictionary in events:
		match String(e["type"]):
			"landed":
				var dust := DustPuff.new()
				add_child(dust)
				dust.play(e["pos"], float(e["intensity"]), scale)
			"respawned":
				var beam := RespawnBeam.new()
				add_child(beam)
				beam.play(e["pos"])
			"trail":
				_trail.add_sample(e["pos"], float(e["intensity"]), PlayerStyle.color(int(e["id"])), scale)


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
