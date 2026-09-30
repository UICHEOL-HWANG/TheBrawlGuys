extends GutTest
## Foot ring shapes (design.md DS-VIS-03): each player's floor ring is a flat band in that
## player's shape (P1 circle, P2 triangle, P3 square, P4 diamond) so the players read apart
## in black and white, and every band shows around the fighter's body whatever its shape.

const INNER := 1.15
const OUTER := 1.45
const RADIUS := 0.5


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func test_each_player_gets_a_band_in_their_shape() -> void:
	var sides := {0: PlayerStyle.CIRCLE_SEGMENTS, 1: 3, 2: 4, 3: 4}
	for index: int in sides:
		var mesh := PlayerRingMesh.build(PlayerStyle.shape(index), RADIUS * INNER, RADIUS * OUTER)
		assert_eq(_vertices(mesh).size(), int(sides[index]) * 6, "P%d: one quad per side" % (index + 1))


func test_the_band_lies_flat_and_faces_up() -> void:
	var mesh := PlayerRingMesh.build(PlayerStyle.Shape.TRIANGLE, RADIUS * INNER, RADIUS * OUTER)
	for v: Vector3 in _vertices(mesh):
		assert_eq(v.y, 0.0)
	for n: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n, Vector3.UP, Vector3.ONE * 0.001)


func test_square_and_diamond_are_turned_apart() -> void:
	var square := PlayerRingMesh.outline(PlayerStyle.Shape.SQUARE, 1.0)
	var diamond := PlayerRingMesh.outline(PlayerStyle.Shape.DIAMOND, 1.0)
	assert_almost_eq(absf(square[0].x), absf(square[0].z), 0.0001, "square corners sit on the diagonals")
	assert_almost_eq(diamond[0].x, 0.0, 0.0001, "diamond corners sit on the axes")


func test_every_band_shows_outside_the_body() -> void:
	for shape: int in PlayerStyle.SHAPES:
		var outer := PlayerRingMesh.outline(shape, RADIUS * OUTER)
		assert_gt(_inradius(outer), RADIUS, "shape %d: the band's outer edge clears the body" % shape)
		var inner := PlayerRingMesh.outline(shape, RADIUS * INNER)
		assert_gte(inner[0].length(), RADIUS * INNER, "shape %d: corners reach at least the circle ring" % shape)


## Distance from the center to the nearest point of the polygon's edges.
func _inradius(pts: PackedVector3Array) -> float:
	var best := INF
	for i: int in pts.size():
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[(i + 1) % pts.size()].x, pts[(i + 1) % pts.size()].z)
		best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length())
	return best
