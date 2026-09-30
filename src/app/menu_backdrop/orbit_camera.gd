class_name OrbitCamera
extends Node3D
## Menu backdrop camera (design.md DS-LAY-03): a lower, closer view than the match camera so the
## fighters read, turning slowly around a pivot that drifts after the fight. Distance and look-at come from
## CameraFraming over the arena-core anchors, rotated with the yaw, so every angle frames the same
## circle. A screen focus (NDC, x right / y up) slides the fight into the part of the screen the
## current menu leaves free, eased with cam_smooth. All values are GameConfig Camera settings.

## Diagonal anchors join the four axis anchors so the ring fits at every yaw.
const DIAGONAL := PI * 0.25

var _config: GameConfig
var _camera: Camera3D
var _yaw: float = 0.0
var _frame: Dictionary = {}
var _aspect: float = -1.0
var _focus: Vector2 = Vector2.ZERO
var _focus_target: Vector2 = Vector2.ZERO
var _pivot: Vector3 = Vector3.ZERO
var _pivot_target: Vector3 = Vector3.ZERO


func setup(config: GameConfig) -> void:
	_config = config
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	advance(0.0)


func advance(delta: float) -> void:
	_yaw = wrapf(_yaw + deg_to_rad(_config.menu_orbit_deg_per_s) * delta, 0.0, TAU)
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := vp.x / maxf(vp.y, 1.0)
	if not is_equal_approx(aspect, _aspect):
		_aspect = aspect
		_frame = frame(_config, aspect)
	_focus = _focus.lerp(_focus_target, 1.0 - exp(-_config.cam_smooth * delta))
	_pivot = _pivot.lerp(_pivot_target, 1.0 - exp(-_config.menu_orbit_follow * delta))
	var distance := float(_frame["distance"])
	_camera.fov = _config.cam_fov
	_camera.transform = pose(_yaw, _config.menu_orbit_pitch, _frame["center"], distance)
	_camera.position += _pivot
	var lens := lens_offset(_focus, distance, _config.cam_fov, aspect)
	_camera.h_offset = lens.x
	_camera.v_offset = lens.y


## Where on screen the arena center should sit (NDC: -1..1, x right, y up).
func set_focus(ndc: Vector2, instant: bool = false) -> void:
	_focus_target = ndc
	if instant:
		_focus = ndc


func focus() -> Vector2:
	return _focus


## Ground point the orbit turns around; drifts there at menu_orbit_follow (the fight's center).
func follow(ground_point: Vector3) -> void:
	_pivot_target = Vector3(ground_point.x, 0.0, ground_point.z)


func pivot() -> Vector3:
	return _pivot


func make_current() -> void:
	_camera.make_current()


func yaw() -> float:
	return _yaw


## {center, distance} that keep the arena core in frame from the menu pitch.
static func frame(config: GameConfig, aspect: float) -> Dictionary:
	var pts := CameraFraming.arena_anchors(config.arena_radius, config.menu_orbit_arena_share)
	for p: Vector3 in pts.duplicate():
		pts.append(p.rotated(Vector3.UP, DIAGONAL))
	return CameraFraming.compute(pts, config.cam_margin, config.menu_orbit_zoom_min, config.cam_zoom_max,
			config.cam_fov, aspect, config.menu_orbit_pitch)


## CameraRig's model (center + (0, sin p, cos p) * d) turned by yaw around the arena axis.
static func pose(yaw_rad: float, pitch_deg: float, center: Vector3, distance: float) -> Transform3D:
	var c := center.rotated(Vector3.UP, yaw_rad)
	var p := deg_to_rad(pitch_deg)
	var eye := c + Vector3(0.0, sin(p), cos(p)).rotated(Vector3.UP, yaw_rad) * distance
	return Transform3D(Basis.IDENTITY, eye).looking_at(c, Vector3.UP)


## Camera h/v offset that shows the look-at point at `ndc` instead of the screen center.
static func lens_offset(ndc: Vector2, distance: float, fov_deg: float, aspect: float) -> Vector2:
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(-ndc.x * distance * t * aspect, -ndc.y * distance * t)
