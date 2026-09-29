class_name TouchStickModel
extends RefCounted
## Floating virtual stick math (PRD §3.3, design.md DS-LAY-01): wherever the thumb lands becomes
## the center. vector() is normalized by the radius, zero inside the dead zone, length <= 1.
## Screen y grows downward, which maps to +z (toward the camera).

var radius: float
## Fraction of the radius that reads as zero.
var deadzone: float
var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func _init(p_radius: float, p_deadzone: float) -> void:
	radius = maxf(p_radius, 1.0)
	deadzone = p_deadzone


func begin(p: Vector2) -> void:
	_active = true
	_center = p
	_current = p


func move(p: Vector2) -> void:
	if _active:
		_current = p


func end() -> void:
	_active = false


func active() -> bool:
	return _active


func center() -> Vector2:
	return _center


func knob() -> Vector2:
	return _center + (_current - _center).limit_length(radius)


func vector() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var d := (_current - _center) / radius
	if d.length() < deadzone:
		return Vector2.ZERO
	return d.limit_length(1.0)
