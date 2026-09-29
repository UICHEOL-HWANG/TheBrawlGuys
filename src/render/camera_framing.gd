class_name CameraFraming
extends RefCounted
## Pure framing math for GD-CAM-01: where to look and how far back to stand.
##
## Camera model (matches CameraRig): position = center + (0, sin p, cos p) * d, looking at center.
## For a point q with r = q - center: back = (0, sin p, cos p), cam_up = (0, cos p, -sin p),
## depth = d - r.back, screen-up u = r.cam_up, screen-right x = r.x. A point is visible iff
## |u| <= t * depth and |x| <= t * aspect * depth (t = tan(fov / 2)), i.e. the distance must satisfy
## d >= r.back + |u| / t and d >= r.back + |x| / (t * aspect) for every point (exact perspective).
##
## The margin expands the target bounding box on the ground plane (x and z). The look-at point
## keeps y = 0 (no bobbing on jumps/respawns); its z is chosen to minimise the vertical distance
## requirement, then re-balanced (at the fitted distance) so the worst |NDC y| of the actual targets
## is minimal, i.e. the near and far extents are symmetric around the screen center. The margin
## corners only enter the fit, not the balance, so the margin never skews the visible arena.

const SEARCH_ITERATIONS := 48
const REBALANCE_PASSES := 4


## Returns {"center": Vector3, "distance": float}. Defaults (aspect 1, pitch 90) are top-down.
static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float,
		fov_deg: float, aspect: float = 1.0, pitch_deg: float = 90.0) -> Dictionary:
	if targets.is_empty():
		return {"center": Vector3.ZERO, "distance": zoom_min}
	var lo := targets[0]
	var hi := targets[0]
	for p: Vector3 in targets:
		lo = lo.min(p)
		hi = hi.max(p)
	var pts := PackedVector3Array(targets)
	for x: float in [lo.x - margin, hi.x + margin]:
		for z: float in [lo.z - margin, hi.z + margin]:
			pts.append(Vector3(x, 0.0, z))
	var pitch := deg_to_rad(pitch_deg)
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var cx := (lo.x + hi.x) * 0.5
	var z_lo := lo.z - margin
	var z_hi := hi.z + margin
	var asp := maxf(aspect, 0.01)
	var cz := _search_center_z(pts, cx, z_lo, z_hi, pitch, t, 0.0)
	var d := clampf(_needed(pts, Vector3(cx, 0.0, cz), pitch, t, asp), zoom_min, zoom_max)
	# Horizontal fit (or a clamp) can leave slack: re-balance the near/far extents at the real
	# distance, then re-fit. A few fixed passes converge well below a pixel.
	for i: int in REBALANCE_PASSES:
		cz = _search_center_z(targets, cx, z_lo, z_hi, pitch, t, d)
		d = clampf(_needed(pts, Vector3(cx, 0.0, cz), pitch, t, asp), zoom_min, zoom_max)
	return {"center": Vector3(cx, 0.0, cz), "distance": d}


static func _needed(pts: PackedVector3Array, center: Vector3, pitch: float, t: float, aspect: float) -> float:
	return maxf(_required_distance(pts, center, pitch, t, true, 1.0),
			_required_distance(pts, center, pitch, t, false, aspect))


## Distance needed to fit every point vertically (vertical=true) or horizontally.
static func _required_distance(pts: PackedVector3Array, center: Vector3, pitch: float, t: float,
		vertical: bool, aspect: float) -> float:
	var back := Vector3(0.0, sin(pitch), cos(pitch))
	var cam_up := Vector3(0.0, cos(pitch), -sin(pitch))
	var need := 0.0
	for q: Vector3 in pts:
		var r := q - center
		var extent := absf(r.dot(cam_up)) / t if vertical else absf(r.x) / (t * aspect)
		need = maxf(need, r.dot(back) + extent)
	return need


## Ternary search over center z. With distance <= 0 it minimises the vertical distance requirement
## (convex: max of linear functions); otherwise it minimises the worst vertical |NDC y| at that
## distance, which centres the near and far extents on the screen.
static func _search_center_z(pts: PackedVector3Array, cx: float, z_lo: float, z_hi: float,
		pitch: float, t: float, distance: float) -> float:
	var a := z_lo
	var b := z_hi
	for i: int in SEARCH_ITERATIONS:
		var m1 := a + (b - a) / 3.0
		var m2 := b - (b - a) / 3.0
		if _z_cost(pts, Vector3(cx, 0.0, m1), pitch, t, distance) \
				< _z_cost(pts, Vector3(cx, 0.0, m2), pitch, t, distance):
			b = m2
		else:
			a = m1
	return (a + b) * 0.5


static func _z_cost(pts: PackedVector3Array, center: Vector3, pitch: float, t: float, distance: float) -> float:
	if distance <= 0.0:
		return _required_distance(pts, center, pitch, t, true, 1.0)
	var back := Vector3(0.0, sin(pitch), cos(pitch))
	var cam_up := Vector3(0.0, cos(pitch), -sin(pitch))
	var worst := 0.0
	for q: Vector3 in pts:
		var r := q - center
		var depth := maxf(distance - r.dot(back), 0.0001)
		worst = maxf(worst, absf(r.dot(cam_up)) / (t * depth))
	return worst
