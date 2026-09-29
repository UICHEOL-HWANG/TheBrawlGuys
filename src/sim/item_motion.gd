class_name ItemMotion
extends RefCounted
## Loose item physics (PRD §4.4): falling boxes land on the arena floor and items that fall past
## kill_y are removed. Thrown items (Task 8) and bomb fuses (Task 9) extend _advance.

## Same landing rule as fighters (Motion.LAND_TOLERANCE): never snap up from under the floor.
const LAND_TOLERANCE := 0.05


static func step(field: ItemField, _fighters: Array[Fighter], _attacks: AttackSet,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	for it: Item in field.items:
		if _advance(it, config, events):
			keep.append(it)
	field.items = keep
	return events


## Moves one item; returns false when it is gone.
static func _advance(it: Item, config: GameConfig, events: Array[Dictionary]) -> bool:
	if it.state == Item.State.GROUND:
		return true
	var prev_y := it.pos.y
	it.vel.y += config.gravity * SimTime.TICK_DT
	it.pos += it.vel * SimTime.TICK_DT
	if _landed(it, prev_y, config):
		it.pos.y = 0.0
		it.vel = Vector3.ZERO
		it.state = Item.State.GROUND
		events.append({"type": "item_land", "id": it.id, "kind": it.kind, "pos": it.pos})
		return true
	return it.pos.y >= config.kill_y


static func _landed(it: Item, prev_y: float, config: GameConfig) -> bool:
	return Collision.on_arena_floor(it.pos, config.arena_radius) and it.pos.y <= 0.0 \
			and prev_y >= -LAND_TOLERANCE and it.vel.y <= 0.0
