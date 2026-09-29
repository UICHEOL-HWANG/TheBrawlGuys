class_name CameraFraming
extends RefCounted
## Pure framing math for GD-CAM-01: where to look and how far back to stand.


## x fits the horizontal FOV (vertical FOV widened by the aspect ratio); z is foreshortened by
## the camera pitch. Defaults (aspect 1, pitch 90) reproduce the old single-extent behavior.
static func compute(targets: PackedVector3Array, margin: float, zoom_min: float, zoom_max: float,
		fov_deg: float, aspect: float = 1.0, pitch_deg: float = 90.0) -> Dictionary:
	if targets.is_empty():
		return {"center": Vector3.ZERO, "distance": zoom_min}
	var lo := targets[0]
	var hi := targets[0]
	for p: Vector3 in targets:
		lo = lo.min(p)
		hi = hi.max(p)
	var half_x := (hi.x - lo.x) * 0.5 + margin
	var half_z := (hi.z - lo.z) * 0.5 + margin
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var dist_x := half_x / (t * maxf(aspect, 0.01))
	var dist_z := half_z * sin(deg_to_rad(pitch_deg)) / t
	return {"center": (lo + hi) * 0.5, "distance": clampf(maxf(dist_x, dist_z), zoom_min, zoom_max)}
