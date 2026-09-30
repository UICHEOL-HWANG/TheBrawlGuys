class_name StarShape
extends RefCounted
## Flat meshes for the comic hit impact (design.md DS-VFX-01 v2), all in the XY plane facing +Z
## with a unit outer radius: an uneven spiky star, a thin shock ring and radial speed-line
## needles. Built once per shape and shared (never mutate a returned mesh).

## Tip lengths cycle through these fractions of the outer radius (uneven comic spikes).
const TIP_PATTERN := [1.0, 0.74, 0.9, 0.8, 0.96, 0.7]
const RING_SEGMENTS := 28
const RING_INNER := 0.82
const NEEDLE_START := 0.42
const NEEDLE_HALF_WIDTH := 0.035

static var _cache: Dictionary = {}


## Outline of a star with `points` spikes: tips (even indices) reach up to `outer`, valleys (odd
## indices) sit at `inner`. Starts pointing up.
static func star_points(points: int, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := maxi(points, 3) * 2
	for i: int in count:
		var a := PI * 0.5 + TAU * float(i) / float(count)
		var r := inner
		if i % 2 == 0:
			r = outer * float(TIP_PATTERN[(i / 2) % TIP_PATTERN.size()])
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


static func star_mesh(points: int, inner: float) -> ArrayMesh:
	var key := "star|%d|%.3f" % [points, inner]
	if not _cache.has(key):
		_cache[key] = _fan(star_points(points, 1.0, inner))
	return _cache[key]


static func ring_mesh() -> ArrayMesh:
	if not _cache.has("ring"):
		var verts := PackedVector3Array()
		for i: int in RING_SEGMENTS:
			var a0 := TAU * float(i) / RING_SEGMENTS
			var a1 := TAU * float(i + 1) / RING_SEGMENTS
			var o0 := Vector3(cos(a0), sin(a0), 0.0)
			var o1 := Vector3(cos(a1), sin(a1), 0.0)
			verts.append_array([o0, o1, o0 * RING_INNER, o1, o1 * RING_INNER, o0 * RING_INNER])
		_cache["ring"] = _mesh(verts)
	return _cache["ring"]


static func needle_mesh(count: int, half_width: float = NEEDLE_HALF_WIDTH) -> ArrayMesh:
	var key := "needles|%d|%.3f" % [count, half_width]
	if not _cache.has(key):
		var verts := PackedVector3Array()
		for i: int in count:
			# Offset by half a step so needles fall between the star's spikes.
			var a := TAU * (float(i) + 0.5) / float(count)
			var along := Vector3(cos(a), sin(a), 0.0)
			var side := Vector3(-along.y, along.x, 0.0) * half_width
			var base := along * NEEDLE_START
			verts.append_array([base - side, base + side, along])
		_cache[key] = _mesh(verts)
	return _cache[key]


## Triangle fan from the center over a closed outline.
static func _fan(outline: PackedVector2Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i: int in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		verts.append_array([Vector3.ZERO, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0)])
	return _mesh(verts)


static func _mesh(verts: PackedVector3Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
