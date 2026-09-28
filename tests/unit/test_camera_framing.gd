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
