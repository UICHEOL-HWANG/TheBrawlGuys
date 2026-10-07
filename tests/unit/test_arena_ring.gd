extends GutTest
## ArenaShape ring kind (frozen pond outer ice, PRD §6.1): an annulus between inner and radius.


func _ring() -> ArenaShape:
	return ArenaShape.ring(Vector3(1, 0, 0), 9.0, 5.0)


func test_ring_contains_only_the_band() -> void:
	var s := _ring()
	assert_eq(s.kind, ArenaShape.Kind.RING)
	assert_true(s.contains_xz(Vector3(8.0, 3, 0)), "inside the band")
	assert_false(s.contains_xz(Vector3(1.0, 0, 0)), "the hole in the middle")
	assert_false(s.contains_xz(Vector3(5.5, 0, 0)), "just inside the inner edge")
	assert_false(s.contains_xz(Vector3(10.5, 0, 0)), "past the outer edge")


func test_ring_edge_distance_takes_the_nearer_edge() -> void:
	var s := _ring()
	assert_almost_eq(s.edge_distance(Vector3(7.5, 0, 0)), 1.5, 0.0001, "1.5 to the inner edge (2.5 to the outer)")
	assert_almost_eq(s.edge_distance(Vector3(1, 0, 5.5)), 0.5, 0.0001, "0.5 to the inner edge")
	assert_almost_eq(s.edge_distance(Vector3(1, 0, 4.0)), -1.0, 0.0001, "1 inside the hole")
	assert_almost_eq(s.edge_distance(Vector3(12.0, 0, 0)), -2.0, 0.0001, "2 outside")
	assert_almost_eq(s.extent(), 2.0, 0.0001, "half the band width")


func test_ring_core_point_and_outward() -> void:
	var s := _ring()
	var p := s.core_point(Vector3(9.8, 0, 0), 1.0)
	assert_almost_eq(p.x, 9.0, 0.0001, "pulled in from the outer edge")
	var q := s.core_point(Vector3(1, 0, 4.0), 1.0)
	assert_almost_eq(q.z, 6.0, 0.0001, "pushed out of the hole")
	assert_eq(s.core_point(Vector3(8, 0, 0), 1.0), Vector3(8, 0, 0), "already safe: unchanged")
	var thin := s.core_point(Vector3(9.8, 0, 0), 3.0)
	assert_almost_eq(thin.x, 8.0, 0.0001, "a band thinner than the inset collapses to its middle")
	assert_almost_eq(s.outward(Vector3(9.5, 0, 0)).x, 1.0, 0.0001, "near the rim: out")
	assert_almost_eq(s.outward(Vector3(1, 0, -5.5)).y, 1.0, 0.0001, "near the hole: toward the middle")


func test_ring_bound_samples_copy_and_view() -> void:
	var s := _ring()
	assert_almost_eq(s.bound_radius(), 10.0, 0.0001)
	for k: int in 10:
		var at := s.sample_point(k / 10.0, k / 10.0, 1.0, 0.0)
		assert_true(s.contains_xz(at), "sample %d lands on the band" % k)
	var c := s.copy()
	assert_eq(c.kind, ArenaShape.Kind.RING)
	assert_eq(c.inner, 5.0)
	assert_eq(float(s.to_view()["inner"]), 5.0)
