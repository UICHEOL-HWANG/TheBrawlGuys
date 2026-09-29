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


static func respawn(f: Fighter, count: int, config: GameConfig) -> void:
	f.pos = spawn_point(f.id, count, config) + Vector3.UP * config.respawn_height
	f.vel = Vector3.ZERO
	f.facing = facing_to_center(f.pos)
	f.damage = 0.0
	f.on_ground = false
	f.jumps_left = config.max_jumps
	clear_actions(f)
	f.invuln_ticks = SimTime.to_ticks(config.respawn_invuln)
	f.spawn_id += 1
	f.set_state(Fighter.State.AIR)


## Resets attack, charge, combo and grab bookkeeping (respawn and KO).
static func clear_actions(f: Fighter) -> void:
	f.hitstun_ticks = 0
	f.hitstop_ticks = 0
	f.attack_ticks = 0
	f.hit_ids.clear()
	f.combo_queued = false
	f.charge_ticks = 0
	f.charge_mul = 1.0
	f.grab_ticks = 0
	f.partner_id = Fighter.NONE


static func apply(fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.is_alive():
			continue
		if not Collision.is_out_of_bounds(f.pos, config.arena_radius, config.blast_margin, config.kill_y):
			continue
		var at := f.pos
		f.stocks -= 1
		if f.stocks > 0:
			respawn(f, fighters.size(), config)
		else:
			f.vel = Vector3.ZERO
			clear_actions(f)
			f.set_state(Fighter.State.KO)
		events.append({"type": "ringout", "id": f.id, "pos": at, "stocks_left": f.stocks})
	return events


static func winner(fighters: Array[Fighter]) -> int:
	var alive: Array[int] = []
	for f: Fighter in fighters:
		if f.is_alive():
			alive.append(f.id)
	if alive.size() == 1:
		return alive[0]
	if alive.is_empty():
		return DRAW
	return ONGOING
