class_name CameraRig
extends Node3D
## High top-down camera (reference A, GD-CAM-01). Smoothly frames the given targets; a special
## cut-in (SpecialCutIn) blends a close, lower shot of the caster over that framing by its weight.

var _config: GameConfig
var _camera: Camera3D
var _center: Vector3 = Vector3.ZERO
var _distance: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _punch: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _focus_weight: float = 0.0

const PUNCH_DISTANCE := 3.0
const PUNCH_DECAY := 10.0


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

	_punch = move_toward(_punch, 0.0, PUNCH_DECAY * delta * maxf(_punch, 0.1))
	var s := SpecialCutIn.shot(_center, _distance, _config.cam_pitch, _focus, _focus_weight)
	var center: Vector3 = s["center"]
	var pitch := deg_to_rad(float(s["pitch"]))
	_camera.fov = _config.cam_fov
	_camera.position = center + Vector3(0.0, sin(pitch), cos(pitch)) * (float(s["distance"]) - punch_offset())
	_camera.look_at(center, Vector3.UP)
	_camera.position += _shake_offset


## Briefly pulls the camera in, then it settles back (ring-out punch).
func punch(strength: float) -> void:
	_punch = maxf(_punch, clampf(strength, 0.0, 1.0))


func punch_offset() -> float:
	return _punch * PUNCH_DISTANCE


## Special cut-in: the caster's feet and how far (0..1) the close shot replaces the framing.
func set_focus(point: Vector3, weight: float) -> void:
	_focus = point
	_focus_weight = clampf(weight, 0.0, 1.0)


func focus_point() -> Vector3:
	return _focus


func focus_weight() -> float:
	return _focus_weight


func set_shake_offset(offset: Vector3) -> void:
	_shake_offset = offset


## Whether a world point is in front of the camera and inside the viewport (a special cut-in
## close shot leaves most of the arena out of frame).
func sees(world: Vector3) -> bool:
	if _camera.is_position_behind(world):
		return false
	return get_viewport().get_visible_rect().has_point(_camera.unproject_position(world))


## Screen position of a world point (HUD elements that follow fighters, context E10).
func unproject(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)
