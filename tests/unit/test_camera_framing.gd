extends GutTest


func test_no_targets_looks_at_origin_from_min_zoom() -> void:
	var f := CameraFraming.compute(PackedVector3Array(), 3.0, 14.0, 40.0, 40.0)
	assert_eq(f["center"], Vector3.ZERO)
	assert_eq(f["distance"], 14.0)


func test_center_is_midpoint_of_bounds() -> void:
	var pts := PackedVector3Array([Vector3(-2, 0, 4), Vector3(6, 1, 0)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0)
	assert_eq(f["center"], Vector3(2, 0.5, 2))


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


func test_pitch_shrinks_depth_extent() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, -4), Vector3(0, 0, 4)])
	var f := CameraFraming.compute(pts, 0.0, 0.0, 1000.0, 90.0, 1.0, 30.0)
	assert_almost_eq(f["distance"], 4.0 * sin(deg_to_rad(30.0)), 0.0001)


func test_launched_fighter_stays_framed_with_default_limits() -> void:
	var c := GameConfig.new()
	# a fighter 15 m past a 10 m arena edge, the other at the far edge
	var pts := PackedVector3Array([Vector3(25, 0, 0), Vector3(-10, 0, 0)])
	var f := CameraFraming.compute(pts, c.cam_margin, c.cam_zoom_min, c.cam_zoom_max, c.cam_fov, 16.0 / 9.0, c.cam_pitch)
	assert_lt(f["distance"], c.cam_zoom_max, "not clamped: the whole spread fits")
