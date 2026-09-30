class_name PlayerRingMesh
extends RefCounted
## A player's flat foot ring (design.md DS-VIS-03) in that player's shape — P1 circle, P2
## triangle, P3 square, P4 diamond (PlayerStyle) — so players read apart in black and white too.
## A band between two outlines of the shape, lying on y = 0 and facing up. Polygon outlines grow
## toward their circumradius so the band still clears the fighter's body along the flat sides.

## Flat sides pull in to cos(PI / sides) of the corner radius; triangles are only partly
## compensated so their corners do not reach far across the arena.
const MIN_SIDE_RATIO := 0.7


## The shape's outline on the floor (x, 0, z), corners scaled so the sides sit near `radius`.
static func outline(shape: int, radius: float) -> PackedVector3Array:
	var flat := PlayerStyle.polygon(shape, 1.0)
	var grow := 1.0 / maxf(cos(PI / flat.size()), MIN_SIDE_RATIO)
	var out := PackedVector3Array()
	for p: Vector2 in flat:
		out.append(Vector3(p.x, 0.0, p.y) * radius * grow)
	return out


## The band between the inner and outer outline: one quad (two clockwise triangles) per side.
static func build(shape: int, inner_radius: float, outer_radius: float) -> ArrayMesh:
	var inner := outline(shape, inner_radius)
	var outer := outline(shape, outer_radius)
	var verts := PackedVector3Array()
	for i: int in inner.size():
		var j := (i + 1) % inner.size()
		verts.append_array(PackedVector3Array([inner[i], outer[i], outer[j], inner[i], outer[j], inner[j]]))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
