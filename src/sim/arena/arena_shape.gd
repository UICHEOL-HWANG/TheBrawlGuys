class_name ArenaShape
extends RefCounted
## One flat arena shape (PRD §6.1): a circle or a Y-rotated box in the XZ plane at height center.y.
## Floors use center.y as the walkable top, ring-out zones as the water line, gimmicks as their area.
## Pure value object: queries never mutate it.

enum Kind { CIRCLE, BOX }

var kind: int = Kind.CIRCLE
var center: Vector3 = Vector3.ZERO
var radius: float = 0.0
## Box half extents along its local x and z.
var half: Vector2 = Vector2.ZERO
var yaw: float = 0.0
## Name for views and events (ring-out zone "lake", "water", ...).
var tag: String = ""


static func circle(p_center: Vector3, p_radius: float, p_tag: String = "") -> ArenaShape:
	var s := ArenaShape.new()
	s.kind = Kind.CIRCLE
	s.center = p_center
	s.radius = p_radius
	s.tag = p_tag
	return s


static func box(p_center: Vector3, size: Vector2, p_yaw: float = 0.0, p_tag: String = "") -> ArenaShape:
	var s := ArenaShape.new()
	s.kind = Kind.BOX
	s.center = p_center
	s.half = size * 0.5
	s.yaw = p_yaw
	s.tag = p_tag
	return s


## p relative to the center, in the shape's own axes (box yaw undone), as (x, z).
func local_xz(p: Vector3) -> Vector2:
	var d := Vector3(p.x - center.x, 0.0, p.z - center.z)
	if kind == Kind.BOX and yaw != 0.0:
		d = d.rotated(Vector3.UP, -yaw)
	return Vector2(d.x, d.z)


func contains_xz(p: Vector3) -> bool:
	if kind == Kind.CIRCLE:
		return Vector2(p.x - center.x, p.z - center.z).length() <= radius
	var l := local_xz(p)
	return absf(l.x) <= half.x and absf(l.y) <= half.y


## Horizontal distance to the edge: positive inside, negative outside.
func edge_distance(p: Vector3) -> float:
	var l := local_xz(p)
	if kind == Kind.CIRCLE:
		return radius - l.length()
	var gap := Vector2(absf(l.x) - half.x, absf(l.y) - half.y)
	if gap.x <= 0.0 and gap.y <= 0.0:
		return -maxf(gap.x, gap.y)
	return -Vector2(maxf(gap.x, 0.0), maxf(gap.y, 0.0)).length()


## Smallest half size: the circle radius or the box's shorter half extent.
func extent() -> float:
	return radius if kind == Kind.CIRCLE else minf(half.x, half.y)


## Nearest point at least `inset` inside the edge (thin shapes collapse to their middle line).
## Returns p unchanged when it already is that deep inside.
func core_point(p: Vector3, inset: float) -> Vector3:
	var l := local_xz(p)
	var clamped: Vector2
	if kind == Kind.CIRCLE:
		clamped = l.limit_length(maxf(radius - inset, 0.0))
	else:
		var lim := Vector2(maxf(half.x - inset, 0.0), maxf(half.y - inset, 0.0))
		clamped = Vector2(clampf(l.x, -lim.x, lim.x), clampf(l.y, -lim.y, lim.y))
	if clamped == l:
		return p
	return _to_world(clamped, center.y)


## Unit horizontal direction from inside toward the nearest edge (world x, z).
func outward(p: Vector3) -> Vector2:
	var l := local_xz(p)
	var out: Vector2
	if kind == Kind.CIRCLE:
		out = l.normalized() if l.length() > 0.0001 else Vector2(1, 0)
	elif half.x - absf(l.x) < half.y - absf(l.y):
		out = Vector2(signf(l.x) if l.x != 0.0 else 1.0, 0.0)
	else:
		out = Vector2(0.0, signf(l.y) if l.y != 0.0 else 1.0)
	if kind == Kind.BOX and yaw != 0.0:
		out = out.rotated(-yaw)
	return out


## A point inside the inner `ratio` of the shape from two uniform draws u1, u2 in [0, 1), at
## height y. Circles use the Phase 2 item formula (angle u1 * TAU, radius sqrt(u2)) unchanged.
func sample_point(u1: float, u2: float, ratio: float, y: float) -> Vector3:
	if kind == Kind.CIRCLE:
		var angle := u1 * TAU
		var r := sqrt(u2) * radius * ratio
		return Vector3(center.x + cos(angle) * r, y, center.z + sin(angle) * r)
	return _to_world(Vector2((u1 * 2.0 - 1.0) * half.x * ratio, (u2 * 2.0 - 1.0) * half.y * ratio), y)


## Farthest horizontal distance of the shape from the world origin.
func bound_radius() -> float:
	var reach := radius if kind == Kind.CIRCLE else half.length()
	return Vector2(center.x, center.z).length() + reach


func copy() -> ArenaShape:
	var s := ArenaShape.new()
	s.kind = kind
	s.center = center
	s.radius = radius
	s.half = half
	s.yaw = yaw
	s.tag = tag
	return s


func to_view() -> Dictionary:
	return {"kind": kind, "center": center, "radius": radius, "half": half, "yaw": yaw, "tag": tag}


func _to_world(l: Vector2, y: float) -> Vector3:
	var d := Vector3(l.x, 0.0, l.y)
	if kind == Kind.BOX and yaw != 0.0:
		d = d.rotated(Vector3.UP, yaw)
	return Vector3(center.x + d.x, y, center.z + d.z)
