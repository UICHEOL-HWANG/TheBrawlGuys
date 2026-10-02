class_name ItemActions
extends RefCounted
## Item handling before movement (PRD §4.4, context E6). A fighter that can act and presses grab
## on the ground next to a pickable item picks it up. With an item in hand, grab throws it and
## light uses it: melee items (bat, hammer, glove) swing (Actions.try_start), the rest are thrown. Buttons spent here
## are cleared from that fighter's input copy so Actions does not act on them too.

## Items are held and thrown from this fraction of the fighter height.
const HAND_HEIGHT_RATIO := 0.6


static func pre_step(fighters: Array[Fighter], inputs: Array[InputFrame], field: ItemField,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if not f.can_act() or f.hitstop_ticks > 0:
			continue
		var input := inputs[f.id]
		if f.item_kind != Fighter.NONE:
			if input.grab or (input.light and not Item.is_melee(f.item_kind)):
				events.append(_throw(f, input, field, config))
				input.grab = false
				input.light = false
		elif input.grab and f.on_ground:
			var it := nearest_pickable(field, f.pos, config.item_pickup_radius)
			if it != null:
				f.item_kind = it.kind
				f.item_uses = it.uses
				field.remove(it)
				events.append({"type": "item_pickup", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": it.pos})
				input.grab = false
	return events


## A fighter knocked into hitstun or grabbed lets go of its item, which falls where it stands.
static func drop_from_disabled(fighters: Array[Fighter], field: ItemField, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in fighters:
		if f.item_kind == Fighter.NONE:
			continue
		if f.state != Fighter.State.HITSTUN and f.state != Fighter.State.HELD:
			continue
		events.append(drop(f, field, config))
	return events


## Lets go of the carried item where the fighter stands (it falls, keeping its uses).
static func drop(f: Fighter, field: ItemField, config: GameConfig) -> Dictionary:
	var it := field.add(f.item_kind, _hand(f, config), Item.State.FALLING, config)
	it.uses = f.item_uses
	f.item_kind = Fighter.NONE
	f.item_uses = 0
	return {"type": "item_drop", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": it.pos}


static func nearest_pickable(field: ItemField, pos: Vector3, radius: float) -> Item:
	var best: Item = null
	var best_dist := radius
	for it: Item in field.items:
		if not it.is_pickable():
			continue
		var d := Vector2(it.pos.x - pos.x, it.pos.z - pos.z).length()
		if d <= best_dist and (best == null or d < best_dist or it.id < best.id):
			best = it
			best_dist = d
	return best


static func _throw(f: Fighter, input: InputFrame, field: ItemField, config: GameConfig) -> Dictionary:
	var dir := Vector3(input.move_x, 0.0, input.move_z)
	if dir.length_squared() > 0.0:
		f.facing = dir.normalized()
	var start := _hand(f, config) + f.facing * (config.fighter_radius + config.item_radius)
	var it := field.add(f.item_kind, start, Item.State.THROWN, config)
	it.uses = f.item_uses
	it.vel = f.facing * config.item_throw_speed + Vector3.UP * config.item_throw_up
	it.owner_id = f.id
	if it.kind == Item.Kind.BOMB:
		it.fuse_ticks = SimTime.to_ticks(config.bomb_fuse_time)
	f.item_kind = Fighter.NONE
	f.item_uses = 0
	return {"type": "item_throw", "id": it.id, "kind": it.kind, "fighter": f.id, "pos": start}


static func _hand(f: Fighter, config: GameConfig) -> Vector3:
	return f.pos + Vector3.UP * (config.fighter_height * HAND_HEIGHT_RATIO)
