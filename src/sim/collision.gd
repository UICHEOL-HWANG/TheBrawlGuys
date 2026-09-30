class_name Collision
extends RefCounted
## Simple-shape collision for the pure sim (PRD §5.2): vertical capsules (fighters) and
## Y-rotated boxes (hitboxes). No engine physics. Floors and ring-out bounds are ArenaFloor's.

## Push direction used when two capsules sit exactly on top of each other.
const COINCIDENT_AXIS := Vector3(1, 0, 0)
const EPSILON := 0.000001


static func separate_capsules(a: Vector3, b: Vector3, radius: float, height: float) -> Vector3:
	if absf(a.y - b.y) >= height:
		return Vector3.ZERO
	var d := Vector3(a.x - b.x, 0.0, a.z - b.z)
	var dist := d.length()
	var min_dist := radius * 2.0
	if dist >= min_dist:
		return Vector3.ZERO
	var dir := COINCIDENT_AXIS if dist < EPSILON else d / dist
	return dir * (min_dist - dist) * 0.5


static func yaw_of(facing: Vector3) -> float:
	return atan2(facing.x, facing.z)


static func capsule_hits_box(cap_base: Vector3, radius: float, height: float,
		box_center: Vector3, box_yaw: float, half: Vector3) -> bool:
	var local := (cap_base - box_center).rotated(Vector3.UP, -box_yaw)
	var seg_bottom := local.y + radius
	var seg_top := local.y + maxf(height - radius, radius)
	var dx := maxf(absf(local.x) - half.x, 0.0)
	var dz := maxf(absf(local.z) - half.z, 0.0)
	var dy := 0.0
	if seg_bottom > half.y:
		dy = seg_bottom - half.y
	elif seg_top < -half.y:
		dy = -half.y - seg_top
	return dx * dx + dy * dy + dz * dz <= radius * radius + EPSILON
