class_name Rules
extends RefCounted
## Match rules (PRD §4.1): spawning, ring-out (ArenaFloor.out_zone), stocks, respawn and winner.
## Spawn points and ring-out bounds come from the World's ArenaData (Phase 4 T1); the optional
## arena argument defaults to the classic circle for callers outside a World.

const ONGOING := -2
const DRAW := -1


static func spawn_point(index: int, count: int, config: GameConfig, arena: ArenaData = null) -> Vector3:
	return _arena_or_default(arena, config).spawn_point(index, count)


static func facing_to_center(pos: Vector3) -> Vector3:
	var flat := Vector3(-pos.x, 0.0, -pos.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3(0, 0, 1)


static func spawn_fighter(index: int, count: int, config: GameConfig, arena: ArenaData = null) -> Fighter:
	var f := Fighter.new()
	f.id = index
	f.pos = spawn_point(index, count, config, arena)
	f.facing = facing_to_center(f.pos)
	f.stocks = config.stocks
	f.jumps_left = config.max_jumps
	f.on_ground = true
	return f


static func respawn(f: Fighter, count: int, config: GameConfig, arena: ArenaData = null) -> void:
	f.pos = spawn_point(f.id, count, config, arena) + Vector3.UP * config.respawn_height
	f.vel = Vector3.ZERO
	f.facing = facing_to_center(f.pos)
	f.damage = 0.0
	f.on_ground = false
	f.jumps_left = config.max_jumps
	clear_actions(f)
	f.invuln_ticks = SimTime.to_ticks(config.respawn_invuln)
	f.spawn_id += 1
	f.set_state(Fighter.State.AIR)


## Resets attack, charge, combo and grab bookkeeping, the carried item and burning (respawn and KO).
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
	f.item_kind = Fighter.NONE
	f.item_uses = 0
	f.burn_ticks = 0
	f.burn_clock = 0
	f.held_presses = 0


## Ring-outs this tick. Each "ringout" event says which bound was crossed ("zone": "kill_y",
## "blast" or a ring-out zone tag such as "lake" / "water").
static func apply(fighters: Array[Fighter], config: GameConfig, arena: ArenaData) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.is_alive():
			continue
		var zone := ArenaFloor.out_zone(arena, f.pos)
		if zone.is_empty():
			continue
		var at := f.pos
		f.stocks -= 1
		if f.stocks > 0:
			respawn(f, fighters.size(), config, arena)
		else:
			f.vel = Vector3.ZERO
			clear_actions(f)
			f.set_state(Fighter.State.KO)
		events.append({"type": "ringout", "id": f.id, "pos": at, "stocks_left": f.stocks, "zone": zone})
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


static func _arena_or_default(arena: ArenaData, config: GameConfig) -> ArenaData:
	return arena if arena != null else ArenaCatalog.default(config)
