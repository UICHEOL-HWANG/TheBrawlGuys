extends GutTest
## Comic star burst outlines (design.md DS-VFX-01 v2).


func test_star_alternates_outer_and_inner_points() -> void:
	var pts := StarShape.star_points(8, 1.0, 0.4)
	assert_eq(pts.size(), 16)
	for i: int in pts.size():
		var r := pts[i].length()
		if i % 2 == 0:
			assert_gt(r, 0.69, "tip %d reaches out" % i)
		else:
			assert_almost_eq(r, 0.4, 0.0001, "valley %d" % i)


func test_star_tips_vary_in_length_but_stay_within_the_radius() -> void:
	var pts := StarShape.star_points(10, 1.0, 0.45)
	var lengths := {}
	for i: int in range(0, pts.size(), 2):
		assert_true(pts[i].length() <= 1.0001)
		lengths[snappedf(pts[i].length(), 0.001)] = true
	assert_gt(lengths.size(), 1, "comic stars have uneven spikes")


func test_star_mesh_is_a_triangle_fan() -> void:
	var mesh := StarShape.star_mesh(8, 0.4)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 16 * 3, "one triangle per outline edge")


func test_meshes_are_cached() -> void:
	assert_same(StarShape.star_mesh(8, 0.4), StarShape.star_mesh(8, 0.4))
	assert_same(StarShape.ring_mesh(), StarShape.ring_mesh())
	assert_same(StarShape.needle_mesh(6), StarShape.needle_mesh(6))


func test_needles_have_one_triangle_each() -> void:
	var verts: PackedVector3Array = StarShape.needle_mesh(6).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 6 * 3)
