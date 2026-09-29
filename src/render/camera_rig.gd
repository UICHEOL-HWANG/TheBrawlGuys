class_name CameraRig
extends Node3D
## High top-down camera (reference A, GD-CAM-01). Smoothly frames the given targets.

var _config: GameConfig
var _camera: Camera3D
var _center: Vector3 = Vector3.ZERO
var _distance: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO


func setup(config: GameConfig) -> void:
	_config = config
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_distance = config.cam_zoom_max


func follow(targets: PackedVector3Array, delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var frame := CameraFraming.compute(targets, _config.cam_margin, _config.cam_zoom_min,
			_config.cam_zoom_max, _config.cam_fov, aspect, _config.cam_pitch)
	var target_center: Vector3 = frame["center"]
	var target_distance: float = frame["distance"]
	var k := 1.0 - exp(-_config.cam_smooth * delta)
	_center = _center.lerp(target_center, k)
	_distance = lerpf(_distance, target_distance, k)

	var pitch := deg_to_rad(_config.cam_pitch)
	_camera.fov = _config.cam_fov
	_camera.position = _center + Vector3(0.0, sin(pitch), cos(pitch)) * _distance
	_camera.look_at(_center, Vector3.UP)
	_camera.position += _shake_offset


func set_shake_offset(offset: Vector3) -> void:
	_shake_offset = offset


## Screen position of a world point (HUD elements that follow fighters, context E10).
func unproject(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)
