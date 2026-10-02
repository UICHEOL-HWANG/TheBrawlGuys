class_name ItemTraps
extends RefCounted
## Laid banana peels (PRD-ITEM-07): a grounded fighter whose feet come within fighter_radius +
## banana_trigger_radius of a live trap slips — whatever it was doing ends (Combat.interrupt), it
## takes banana_damage, slides on along its facing at banana_slip_speed and lies in KNOCKDOWN (the
## usual getup options follow, Knockdown) and drops what it carried. The peel is used up. The
## thrower is safe while the trap's grace (fuse_ticks) runs and its allies always are; airborne,
## intangible, frozen, staggered (hitstun: a combo is not cut short), held and lying fighters pass.
## Event "slip" {victim, owner (the thrower), item_id, pos} (match_events actor = owner, target = victim).

## Feet this far above the peel no longer touch it.
const STEP_HEIGHT := 0.3


static func step(field: ItemField, fighters: Array[Fighter], config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Item] = []
	var slips: Array[Array] = []  # [trap, victim]; applied after the scan so drops never join it
	for it: Item in field.items:
		var victim := _victim(it, fighters, config) if it.is_trap() else null
		if victim == null:
			keep.append(it)
		else:
			_slip(victim, config)  # now lying: a later trap this tick skips it
			slips.append([it, victim])
	field.items = keep
	for pair: Array in slips:
		var it: Item = pair[0]
		var victim: Fighter = pair[1]
		if victim.item_kind != Fighter.NONE:
			events.append(ItemActions.drop(victim, field, config))
		events.append({"type": "slip", "victim": victim.id, "owner": it.owner_id, "item_id": it.id, "pos": it.pos})
	return events


## The lowest-id fighter standing on the trap, or null.
static func _victim(it: Item, fighters: Array[Fighter], config: GameConfig) -> Fighter:
	var reach := config.fighter_radius + config.banana_trigger_radius
	for f: Fighter in fighters:
		if f.id == it.owner_id and it.fuse_ticks > 0:
			continue
		if f.id != it.owner_id and f.untouchable_by(it.owner_id):
			continue
		if not _can_slip(f) or absf(f.pos.y - it.pos.y) > STEP_HEIGHT:
			continue
		if Vector2(f.pos.x - it.pos.x, f.pos.z - it.pos.z).length() <= reach:
			return f
	return null


static func _can_slip(f: Fighter) -> bool:
	if not f.is_alive() or not f.on_ground or f.intangible or f.invuln_ticks > 0 or f.hitstop_ticks > 0:
		return false
	return not [Fighter.State.KNOCKDOWN, Fighter.State.HELD, Fighter.State.HOLDING, Fighter.State.GETUP,
			Fighter.State.HITSTUN].has(f.state)


static func _slip(f: Fighter, config: GameConfig) -> void:
	Combat.interrupt(f)
	f.hitstun_ticks = 0
	f.tumble = false
	f.damage += config.banana_damage
	var slide := Vector3(f.facing.x, 0.0, f.facing.z)
	f.vel = (slide.normalized() if slide.length() > 0.0 else Vector3.ZERO) * config.banana_slip_speed
	f.set_state(Fighter.State.KNOCKDOWN)
