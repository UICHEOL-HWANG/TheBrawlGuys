class_name Rules
extends RefCounted
## Match rules (PRD §4.1): spawning here; ring-out, stocks, respawn and winner added in Task 7.

const ONGOING := -2
const DRAW := -1
## Fighters spawn on a circle at this fraction of the arena radius.
const SPAWN_RADIUS_RATIO := 0.5


static func spawn_point(index: int, count: int, config: GameConfig) -> Vector3:
	var angle := PI + TAU * float(index) / float(maxi(count, 1))
	var r := config.arena_radius * SPAWN_RADIUS_RATIO
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


static func facing_to_center(pos: Vector3) -> Vector3:
	var flat := Vector3(-pos.x, 0.0, -pos.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3(0, 0, 1)


static func spawn_fighter(index: int, count: int, config: GameConfig) -> Fighter:
	var f := Fighter.new()
	f.id = index
	f.pos = spawn_point(index, count, config)
	f.facing = facing_to_center(f.pos)
	f.stocks = config.stocks
	f.jumps_left = config.max_jumps
	f.on_ground = true
	return f
