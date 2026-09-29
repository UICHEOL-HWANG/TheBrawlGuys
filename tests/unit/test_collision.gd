extends GutTest

const R := 0.45
const H := 1.6


func test_floor_is_inside_radius() -> void:
	assert_true(Collision.on_arena_floor(Vector3(9.9, 0, 0), 10.0))
	assert_true(Collision.on_arena_floor(Vector3(0, 5, -10.0), 10.0))
	assert_false(Collision.on_arena_floor(Vector3(7.2, 0, 7.2), 10.0))


func test_out_of_bounds_by_height_or_distance() -> void:
	assert_false(Collision.is_out_of_bounds(Vector3(0, 0, 0), 10.0, 12.0, -8.0))
	assert_true(Collision.is_out_of_bounds(Vector3(0, -8.1, 0), 10.0, 12.0, -8.0))
	assert_true(Collision.is_out_of_bounds(Vector3(22.1, 3, 0), 10.0, 12.0, -8.0))
	assert_false(Collision.is_out_of_bounds(Vector3(21.9, 3, 0), 10.0, 12.0, -8.0))


func test_separate_pushes_apart_by_half_penetration() -> void:
	var push := Collision.separate_capsules(Vector3(0.5, 0, 0), Vector3(0, 0, 0), R, H)
	# overlap = 2R - 0.5 = 0.4 -> a moves +0.2 on x
	assert_almost_eq(push.x, 0.2, 0.0001)
	assert_eq(push.y, 0.0)


func test_separate_ignores_far_or_vertically_disjoint() -> void:
	assert_eq(Collision.separate_capsules(Vector3(2, 0, 0), Vector3.ZERO, R, H), Vector3.ZERO)
	assert_eq(Collision.separate_capsules(Vector3(0.1, 2.0, 0), Vector3.ZERO, R, H), Vector3.ZERO)


func test_separate_coincident_uses_deterministic_axis() -> void:
	var push := Collision.separate_capsules(Vector3.ZERO, Vector3.ZERO, R, H)
	assert_almost_eq(push.x, R, 0.0001)


func test_yaw_of_facing() -> void:
	assert_almost_eq(Collision.yaw_of(Vector3(0, 0, 1)), 0.0, 0.0001)
	assert_almost_eq(Collision.yaw_of(Vector3(1, 0, 0)), PI / 2.0, 0.0001)


func test_box_in_front_hits_capsule() -> void:
	# box 0.8 in front of a fighter facing +x, target standing 1.0 away on x
	var yaw := Collision.yaw_of(Vector3(1, 0, 0))
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_true(Collision.capsule_hits_box(Vector3(1.0, 0, 0), R, H, center, yaw, half))


func test_box_misses_capsule_behind_or_too_far() -> void:
	var yaw := Collision.yaw_of(Vector3(1, 0, 0))
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_false(Collision.capsule_hits_box(Vector3(-1.0, 0, 0), R, H, center, yaw, half), "behind")
	assert_false(Collision.capsule_hits_box(Vector3(1.8, 0, 0), R, H, center, yaw, half), "gap 0.1 beyond radius")


func test_box_touching_edge_counts_as_hit() -> void:
	# box right face at x = 1.25, capsule surface at x = 1.7 - 0.45 = 1.25
	var center := Vector3(0.8, 0.9, 0)
	var half := Vector3(0.45, 0.45, 0.45)
	assert_true(Collision.capsule_hits_box(Vector3(1.7, 0, 0), R, H, center, PI / 2.0, half))


func test_box_rotation_matters() -> void:
	# a long thin box along local +z: facing +x covers x, facing +z does not
	var half := Vector3(0.1, 0.45, 1.0)
	var target := Vector3(1.5, 0, 0)
	assert_true(Collision.capsule_hits_box(target, R, H, Vector3(0.8, 0.9, 0), PI / 2.0, half))
	assert_false(Collision.capsule_hits_box(target, R, H, Vector3(0.8, 0.9, 0), 0.0, half))


func test_box_above_capsule_misses() -> void:
	var half := Vector3(0.45, 0.45, 0.45)
	assert_false(Collision.capsule_hits_box(Vector3(0.8, 0, 0), R, H, Vector3(0.8, 3.0, 0), 0.0, half))
