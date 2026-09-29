class_name ItemMotion
extends RefCounted
## Loose item physics (PRD §4.4): falling boxes land on the arena floor and items that fall past
## kill_y are removed. Thrown rocks and bats hit the first fighter they touch (never their thrower) and break on the ground; thrown bombs stop on bodies and land (context E7).
## Lit bombs count down every tick and explode at zero, hitting every fighter in bomb_radius, thrower included (context E7).

## Same landing rule as fighters (Motion.LAND_TOLERANCE): never snap up from under the floor.
const LAND_TOLERANCE := 0.05


static func step(field: ItemField, fighters: Array[Fighter], attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	for it: Item in field.items:
		if it.fuse_ticks > 0:
			it.fuse_ticks -= 1
			if it.fuse_ticks == 0:
				events.append_array(_explode(it, fighters, attacks.get_attack(AttackSet.Kind.BOMB), config))
				continue
		if _advance(it, fighters, attacks, config, events):
			keep.append(it)
	field.items = keep
	return events


static func _explode(it: Item, fighters: Array[Fighter], attack: AttackData, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = [{"type": "explosion", "id": it.id, "pos": it.pos, "radius": config.bomb_radius}]
	for f: Fighter in fighters:
		if not f.is_alive() or f.invuln_ticks > 0:
			continue
		var offset := f.pos + Vector3.UP * (config.fighter_height * 0.5) - it.pos
		if offset.length() > config.bomb_radius + config.fighter_radius:
			continue
		var dir := Vector3(offset.x, 0.0, offset.z)
		if dir.length() < Collision.EPSILON:
			dir = Collision.COINCIDENT_AXIS
		var e := Combat.apply_hit(f, attack, dir, 1.0, config, it.pos, it.owner_id)
		e["attack_kind"] = AttackSet.Kind.BOMB
		events.append(e)
	return events


## Moves one item; returns false when it is gone.
static func _advance(it: Item, fighters: Array[Fighter], attacks: AttackSet, config: GameConfig,
		events: Array[Dictionary]) -> bool:
	if it.state == Item.State.GROUND:
		return true
	var prev_y := it.pos.y
	it.vel.y += config.gravity * SimTime.TICK_DT
	it.pos += it.vel * SimTime.TICK_DT
	if it.state == Item.State.THROWN:
		var target := _first_hit(it, fighters, config)
		if target != null:
			if it.kind == Item.Kind.BOMB:
				it.vel.x = 0.0
				it.vel.z = 0.0
			else:
				events.append(_projectile_hit(it, target, attacks.get_attack(AttackSet.Kind.ROCK), config))
				return false
	if _landed(it, prev_y, config):
		if it.state == Item.State.THROWN and it.kind != Item.Kind.BOMB:
			events.append({"type": "item_break", "id": it.id, "kind": it.kind, "pos": it.pos})
			return false
		it.pos.y = 0.0
		it.vel = Vector3.ZERO
		it.state = Item.State.GROUND
		events.append({"type": "item_land", "id": it.id, "kind": it.kind, "pos": it.pos})
		return true
	return it.pos.y >= config.kill_y


static func _first_hit(it: Item, fighters: Array[Fighter], config: GameConfig) -> Fighter:
	var half := Vector3.ONE * config.item_radius
	for f: Fighter in fighters:
		if f.id == it.owner_id or not f.is_alive() or f.invuln_ticks > 0:
			continue
		if Collision.capsule_hits_box(f.pos, config.fighter_radius, config.fighter_height, it.pos, 0.0, half):
			return f
	return null


static func _projectile_hit(it: Item, target: Fighter, attack: AttackData, config: GameConfig) -> Dictionary:
	var e := Combat.apply_hit(target, attack, Vector3(it.vel.x, 0.0, it.vel.z), 1.0, config, it.pos, it.owner_id)
	e["attack_kind"] = AttackSet.Kind.ROCK
	e["item_kind"] = it.kind
	return e


static func _landed(it: Item, prev_y: float, config: GameConfig) -> bool:
	return Collision.on_arena_floor(it.pos, config.arena_radius) and it.pos.y <= 0.0 \
			and prev_y >= -LAND_TOLERANCE and it.vel.y <= 0.0
