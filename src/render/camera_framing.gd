class_name CameraFraming
extends RefCounted
## Pure framing math for GD-CAM-01: where to look and how far back to stand.


static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float, fov_deg: float) -> Dictionary:
	if targets.is_empty():
		return {"center": Vector3.ZERO, "distance": zoom_min}
	var lo := targets[0]
	var hi := targets[0]
	for p: Vector3 in targets:
		lo = lo.min(p)
		hi = hi.max(p)
	var half_extent := maxf(hi.x - lo.x, hi.z - lo.z) * 0.5 + margin
	var distance := half_extent / tan(deg_to_rad(fov_deg) * 0.5)
	return {"center": (lo + hi) * 0.5, "distance": clampf(distance, zoom_min, zoom_max)}
