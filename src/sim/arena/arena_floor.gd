class_name ArenaFloor
extends RefCounted
## Floor and ring-out queries against an ArenaData (PRD §4.1, §6.1). Replaces the hardcoded
## arena_radius circle: on the classic arena every answer equals the Phase 1-3 circle rules.

const NO_GROUND := -INF
## A body may land only if it was at most this far below a floor top on the previous tick, so
## anything falling under a floor never snaps back up (Motion.LAND_TOLERANCE, same value).
const LAND_TOLERANCE := 0.05
## Directions sampled around a point to tell a floor seam from a real edge (_deep_in_union).
const UNION_SAMPLES := 8


## Top of the highest active floor under pos that a body coming from prev_y may land on, or
## NO_GROUND. The caller lands when pos.y <= top and the body is not moving up.
static func ground_top(arena: ArenaData, pos: Vector3, prev_y: float) -> float:
	var best := NO_GROUND
	for i: int in arena.floors.size():
		if not arena.floor_active[i]:
			continue
		var s := arena.floors[i]
		if s.center.y > best and prev_y >= s.center.y - LAND_TOLERANCE and s.contains_xz(pos):
			best = s.center.y
	return best


static func over_floor(arena: ArenaData, pos: Vector3) -> bool:
	for i: int in arena.floors.size():
		if arena.floor_active[i] and arena.floors[i].contains_xz(pos):
			return true
	return false


## True when an active floor holds pos up (inside it and standing at its top).
static func supports(arena: ArenaData, pos: Vector3) -> bool:
	for i: int in arena.floors.size():
		var s := arena.floors[i]
		if arena.floor_active[i] and absf(pos.y - s.center.y) <= LAND_TOLERANCE and s.contains_xz(pos):
			return true
	return false


## Why pos is out of the arena: "kill_y", "blast", a ring-out zone tag, or "" when inside.
static func out_zone(arena: ArenaData, pos: Vector3) -> String:
	if pos.y < arena.kill_y:
		return "kill_y"
	if Vector2(pos.x, pos.z).length() > arena.blast_radius:
		return "blast"
	for z: ArenaShape in arena.ringout_zones:
		if pos.y < z.center.y and z.contains_xz(pos):
			return z.tag
	return ""


## Deepest edge distance over the active floors under pos (negative when over none).
static func edge_distance(arena: ArenaData, pos: Vector3) -> float:
	var best := -INF
	for i: int in arena.floors.size():
		if arena.floor_active[i]:
			best = maxf(best, arena.floors[i].edge_distance(pos))
	return best


## Nearest point on safe ground: at least extent * (1 - ratio) inside an active floor. Returns
## pos itself when it already is safe. ratio = GameConfig.bot_edge_ratio for bots. A seam where
## floors meet (frozen pond slabs, bridge planks) is not an edge: near two or more floors, pos is
## safe when the ground all around it, that inset away, is still floor (_deep_in_union). A
## single-floor arena never takes that path, so its answers are exactly the per-floor rule.
static func safe_point(arena: ArenaData, pos: Vector3, ratio: float) -> Vector3:
	var best := pos
	var best_dist := INF
	for i: int in arena.floors.size():
		if not arena.floor_active[i]:
			continue
		var s := arena.floors[i]
		var p := s.core_point(pos, s.extent() * (1.0 - ratio))
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < best_dist:
			best_dist = d
			best = p
	return pos if best_dist <= 0.0 or _deep_in_union(arena, pos, ratio) else best



## True when pos is within the safety inset of two or more active floors and every point that
## inset away around it is over a floor (the largest inset of those floors, to stay cautious).
static func _deep_in_union(arena: ArenaData, pos: Vector3, ratio: float) -> bool:
	var near := 0
	var inset := 0.0
	for i: int in arena.floors.size():
		var s := arena.floors[i]
		var need := s.extent() * (1.0 - ratio)
		if arena.floor_active[i] and s.edge_distance(pos) > -need:
			near += 1
			inset = maxf(inset, need)
	if near < 2 or not over_floor(arena, pos):
		return false
	for k: int in UNION_SAMPLES:
		var dir := Vector2.from_angle(TAU * k / UNION_SAMPLES)
		if not over_floor(arena, pos + Vector3(dir.x, 0.0, dir.y) * inset):
			return false
	return true


## Unit (x, z) direction toward the nearest real edge of the ground under pos (for throws): the
## nearest edge of the floor pos stands on most deeply, unless that edge is a seam with another
## floor, in which case the compass direction that leaves the ground soonest.
static func outward(arena: ArenaData, pos: Vector3) -> Vector2:
	var best_i := -1
	var best := -INF
	for i: int in arena.floors.size():
		if arena.floor_active[i]:
			var d := arena.floors[i].edge_distance(pos)
			if d > best:
				best = d
				best_i = i
	if best_i < 0:
		return Vector2(1, 0)
	var out := arena.floors[best_i].outward(pos)
	var past_edge := pos + Vector3(out.x, 0.0, out.y) * (maxf(best, 0.0) + EXIT_STEP)
	return out if not over_floor(arena, past_edge) else _nearest_exit(arena, pos)


const EXIT_DIRECTIONS := 8
const EXIT_STEP := 0.25
const EXIT_MAX := 40.0


static func _nearest_exit(arena: ArenaData, pos: Vector3) -> Vector2:
	var best_dir := Vector2(1, 0)
	var best_len := INF
	for k: int in EXIT_DIRECTIONS:
		var dir := Vector2.from_angle(TAU * k / EXIT_DIRECTIONS)
		var reach := 0.0
		while reach < EXIT_MAX and reach < best_len and over_floor(arena, pos + Vector3(dir.x, 0.0, dir.y) * reach):
			reach += EXIT_STEP
		if reach < best_len:
			best_len = reach
			best_dir = dir
	return best_dir
