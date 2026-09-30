class_name ArenaFloor
extends RefCounted
## Floor and ring-out queries against an ArenaData (PRD §4.1, §6.1). Replaces the hardcoded
## arena_radius circle: on the classic arena every answer equals the Phase 1-3 circle rules.

const NO_GROUND := -INF
## A body may land only if it was at most this far below a floor top on the previous tick, so
## anything falling under a floor never snaps back up (Motion.LAND_TOLERANCE, same value).
const LAND_TOLERANCE := 0.05


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
## pos itself when it already is safe. ratio = GameConfig.bot_edge_ratio for bots.
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
	return pos if best_dist <= 0.0 else best


## Direction toward the nearest edge of the floor pos stands on most deeply (for throws).
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
	return arena.floors[best_i].outward(pos)
