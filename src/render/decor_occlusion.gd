class_name DecorOcclusion
extends RefCounted
## Camera occlusion check for decor (GD-CAM-01, PRD §6.1 "장식은 경기장 바깥, 카메라 시야를 가리지
## 않는다"). A decor piece is an upright cylinder (base, radius, height); it blocks when it cuts a
## sight line from a match camera pose to a point of the arena core (the ring the camera always
## keeps in frame, from the floor to fighter height). Pure math, used by DecorView to drop
## blocking props and by tests to prove none are left.

const RING_SAMPLES := 16
const SEGMENT_SAMPLES := 32
const MATCH_ASPECT := 16.0 / 9.0


## Match camera poses for an arena: the rest framing (arena core + spawn points) and the same
## center pulled back to cam_zoom_max. Each is {eye: Vector3, targets: PackedVector3Array}.
static func match_poses(config: GameConfig, arena: ArenaData, aspect: float = MATCH_ASPECT) -> Array[Dictionary]:
	var core := arena.view_radius() * config.cam_arena_share
	var pts := CameraFraming.arena_anchors(arena.view_radius(), config.cam_arena_share)
	for i: int in 4:
		pts.append(arena.spawn_point(i, 4))
	var frame := CameraFraming.compute(pts, config.cam_margin, config.cam_zoom_min, config.cam_zoom_max,
			config.cam_fov, aspect, config.cam_pitch)
	var targets := core_targets(core, config.fighter_height)
	var out: Array[Dictionary] = []
	for d: float in [float(frame["distance"]), config.cam_zoom_max]:
		out.append({"eye": eye(frame["center"], d, config.cam_pitch), "targets": targets})
	return out


## CameraRig's eye: center + (0, sin p, cos p) * distance.
static func eye(center: Vector3, distance: float, pitch_deg: float) -> Vector3:
	var p := deg_to_rad(pitch_deg)
	return center + Vector3(0.0, sin(p), cos(p)) * distance


## Points of the arena core ring and its center, on the floor and at fighter height.
static func core_targets(core_radius: float, height: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for y: float in [0.0, height]:
		out.append(Vector3(0, y, 0))
		for k: int in RING_SAMPLES:
			var a := TAU * k / RING_SAMPLES
			out.append(Vector3(cos(a) * core_radius, y, sin(a) * core_radius))
	return out


static func blocks_any(poses: Array[Dictionary], base: Vector3, radius: float, height: float) -> bool:
	for pose: Dictionary in poses:
		if blocks(pose["eye"], pose["targets"], base, radius, height):
			return true
	return false


## True when the cylinder at base (radius, height) cuts a sight line from eye to any target.
static func blocks(eye_pos: Vector3, targets: PackedVector3Array, base: Vector3, radius: float, height: float) -> bool:
	for t: Vector3 in targets:
		for s: int in range(1, SEGMENT_SAMPLES):
			var q := eye_pos.lerp(t, float(s) / SEGMENT_SAMPLES)
			if q.y < base.y or q.y > base.y + height:
				continue
			if Vector2(q.x - base.x, q.z - base.z).length() < radius:
				return true
	return false
