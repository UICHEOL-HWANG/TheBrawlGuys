class_name ItemParts
extends RefCounted
## Shared low-poly primitive meshes for the item models (Phase 4 T8). One mesh per shape and
## size, reused by every item on the field. Shared: never mutate a returned mesh.

const LOW_SEGMENTS := 8
const LOW_RINGS := 6

static var _cache: Dictionary = {}


static func box(size: Vector3) -> Mesh:
	var key := "box|%s" % size
	if not _cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_cache[key] = m
	return _cache[key]


static func cylinder(top: float, bottom: float, height: float, segments: int = LOW_SEGMENTS) -> Mesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [top, bottom, height, segments]
	if not _cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_cache[key] = m
	return _cache[key]


static func sphere(radius: float, height: float = -1.0, segments: int = LOW_SEGMENTS * 2) -> Mesh:
	var h := radius * 2.0 if height < 0.0 else height
	var key := "sph|%.3f|%.3f|%d" % [radius, h, segments]
	if not _cache.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = h
		m.radial_segments = segments
		m.rings = maxi(segments / 2, LOW_RINGS)
		_cache[key] = m
	return _cache[key]


## A transform at `pos` rotated by Euler angles `rot` (radians), scaled by `scale`.
static func at(pos: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos)
