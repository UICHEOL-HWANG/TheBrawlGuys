extends GutTest

const ASPECT := 16.0 / 9.0


## Projects a world point with the CameraRig model (camera at center + (0, sin p, cos p) * d,
## looking at center). Returns NDC (x, y); |value| <= 1 is on screen.
func _ndc(q: Vector3, frame: Dictionary, fov_deg: float, aspect: float, pitch_deg: float) -> Vector2:
	var p := deg_to_rad(pitch_deg)
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var r: Vector3 = q - (frame["center"] as Vector3)
	var back := Vector3(0.0, sin(p), cos(p))
	var cam_up := Vector3(0.0, cos(p), -sin(p))
	var depth: float = float(frame["distance"]) - r.dot(back)
	return Vector2(r.x / (t * aspect * depth), r.dot(cam_up) / (t * depth))


func _default_frame(pts: PackedVector3Array) -> Dictionary:
	var c := GameConfig.new()
	return CameraFraming.compute(pts, c.cam_margin, c.cam_zoom_min, c.cam_zoom_max, c.cam_fov, ASPECT, c.cam_pitch)


func _rim(r: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, -r), Vector3(0, 0, r)])


func test_no_targets_looks_at_origin_from_min_zoom() -> void:
	var f := CameraFraming.compute(PackedVector3Array(), 3.0, 14.0, 40.0, 40.0)
	assert_eq(f["center"], Vector3.ZERO)
	assert_eq(f["distance"], 14.0)


func test_center_stays_on_ground_plane() -> void:
	var pts := PackedVector3Array([Vector3(-2, 3, 4), Vector3(6, 1, 0)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0)
	assert_eq((f["center"] as Vector3).y, 0.0, "jumping fighters must not bob the camera")


func test_distance_fits_extent_with_margin() -> void:
	var pts := PackedVector3Array([Vector3(-2, 0, 0), Vector3(2, 0, 0)])
	# half extent 2 + margin 1 = 3; fov 90 -> tan(45) = 1 -> distance 3
	var f := CameraFraming.compute(pts, 1.0, 0.0, 1000.0, 90.0)
	assert_almost_eq(f["distance"], 3.0, 0.0001)


func test_distance_is_clamped() -> void:
	var far := PackedVector3Array([Vector3(-100, 0, 0), Vector3(100, 0, 0)])
	assert_eq(CameraFraming.compute(far, 0.0, 10.0, 40.0, 40.0)["distance"], 40.0)
	var near := PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0, 0)])
	assert_eq(CameraFraming.compute(near, 0.0, 10.0, 40.0, 40.0)["distance"], 10.0)


func test_wide_aspect_fits_x_with_less_distance() -> void:
	var pts := PackedVector3Array([Vector3(-4, 0, 0), Vector3(4, 0, 0)])
	var square := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 1.0, 90.0)
	var wide := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 2.0, 90.0)
	assert_almost_eq(square["distance"], 4.0, 0.0001)
	assert_almost_eq(wide["distance"], 2.0, 0.0001, "horizontal half-FOV tangent doubles")


func test_launched_fighter_stays_framed_with_default_limits() -> void:
	var c := GameConfig.new()
	# a fighter 15 m past a 10 m arena edge, the other at the far edge
	var pts := PackedVector3Array([Vector3(25, 0, 0), Vector3(-10, 0, 0)])
	var f := CameraFraming.compute(pts, c.cam_margin, c.cam_zoom_min, c.cam_zoom_max, c.cam_fov, ASPECT, c.cam_pitch)
	assert_lt(f["distance"], c.cam_zoom_max, "not clamped: the whole spread fits")


func test_arena_rim_and_flung_fighter_are_on_screen_with_defaults() -> void:
	var c := GameConfig.new()
	var flung := Vector3(0, -5, 14)
	var pts := _rim(10.0)
	pts.append(flung)
	var f := _default_frame(pts)
	assert_lt(f["distance"], c.cam_zoom_max, "not clamped")
	for q: Vector3 in pts:
		var n := _ndc(q, f, c.cam_fov, ASPECT, c.cam_pitch)
		assert_lte(absf(n.x), 1.0, "ndc x of %s = %s" % [q, n.x])
		assert_lte(absf(n.y), 1.0, "ndc y of %s = %s" % [q, n.y])


func test_near_and_far_rim_are_vertically_balanced() -> void:
	var c := GameConfig.new()
	var f := _default_frame(_rim(10.0))
	var near := _ndc(Vector3(0, 0, 10), f, c.cam_fov, ASPECT, c.cam_pitch)
	var far := _ndc(Vector3(0, 0, -10), f, c.cam_fov, ASPECT, c.cam_pitch)
	assert_lt(absf(near.y + far.y), 0.1, "near %s far %s" % [near.y, far.y])


func test_tilted_camera_frames_near_extent_exactly() -> void:
	# fov 60 / pitch 45, single point pair on z: the tightest edge must touch NDC 1 (not exceed it)
	var pts := PackedVector3Array([Vector3(0, 0, -4), Vector3(0, 0, 4)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 60.0, 1.0, 45.0)
	var a := _ndc(Vector3(0, 0, 4), f, 60.0, 1.0, 45.0)
	var b := _ndc(Vector3(0, 0, -4), f, 60.0, 1.0, 45.0)
	assert_almost_eq(maxf(absf(a.y), absf(b.y)), 1.0, 0.001)
	assert_almost_eq(a.y, -b.y, 0.001)
