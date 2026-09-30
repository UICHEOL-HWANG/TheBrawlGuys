class_name OrbitCamera
extends Node3D
## Menu backdrop camera (design.md DS-LAY-03): the match camera's high pitch (GD-CAM-01), turning
## slowly around the arena center. Distance and look-at come from CameraFraming over the arena
## anchors (the whole arena by default) and are rotated with the yaw, so every angle frames the
## same circle. Speed and share are GameConfig Camera values.

## Diagonal anchors join the four axis anchors so the ring fits at every yaw.
const DIAGONAL := PI * 0.25

var _config: GameConfig
var _camera: Camera3D
var _yaw: float = 0.0
var _frame: Dictionary = {}
var _aspect: float = -1.0


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
	_camera.fov = _config.cam_fov
	_camera.transform = pose(_yaw, _config.cam_pitch, _frame["center"], float(_frame["distance"]))


func make_current() -> void:
	_camera.make_current()


func yaw() -> float:
	return _yaw


## {center, distance} that keep the arena share in frame from the match camera's pitch.
static func frame(config: GameConfig, aspect: float) -> Dictionary:
	var pts := CameraFraming.arena_anchors(config.arena_radius, config.menu_orbit_arena_share)
	for p: Vector3 in pts.duplicate():
		pts.append(p.rotated(Vector3.UP, DIAGONAL))
	return CameraFraming.compute(pts, config.cam_margin, config.cam_zoom_min, config.cam_zoom_max,
			config.cam_fov, aspect, config.cam_pitch)


## CameraRig's model (center + (0, sin p, cos p) * d) turned by yaw around the arena axis.
static func pose(yaw_rad: float, pitch_deg: float, center: Vector3, distance: float) -> Transform3D:
	var c := center.rotated(Vector3.UP, yaw_rad)
	var p := deg_to_rad(pitch_deg)
	var eye := c + Vector3(0.0, sin(p), cos(p)).rotated(Vector3.UP, yaw_rad) * distance
	return Transform3D(Basis.IDENTITY, eye).looking_at(c, Vector3.UP)
