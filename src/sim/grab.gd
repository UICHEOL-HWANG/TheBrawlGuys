class_name Grab
extends RefCounted
## Grab -> hold -> throw (PRD §4.3, context E5). A grab is an ATTACK of kind GRAB with no damage;
## a connecting grab box turns the pair into HOLDING / HELD. The holder turns with the move
## input and throws with a second grab press; an unthrown hold ends after grab_hold_max_time.
## Grabs ignore guard (context E4). cleanup() frees any pair broken by hits or ring-outs.


static func resolve(fighters: Array[Fighter], book: StyleBook, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for holder: Fighter in fighters:
		if holder.state != Fighter.State.ATTACK or holder.attack_kind != AttackSet.Kind.GRAB:
			continue
		var grab := book.attacks(holder.id).get_attack(AttackSet.Kind.GRAB)
		if not grab.is_active(holder.attack_ticks):
			continue
		var center := Combat.hitbox_center(holder, grab)
		var yaw := Collision.yaw_of(holder.facing)
		for target: Fighter in fighters:
			if not _grabbable(holder, target):
				continue
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, grab.hitbox_half):
				_start_hold(holder, target, config)
				events.append({"type": "grab", "attacker": holder.id, "target": target.id, "pos": target.pos})
				break
	return events


static func step(fighters: Array[Fighter], inputs: Array[InputFrame], book: StyleBook,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for holder: Fighter in fighters:
		if holder.state != Fighter.State.HOLDING or holder.hitstop_ticks > 0:
			continue
		var target := find(fighters, holder.partner_id)
		if target == null or target.state != Fighter.State.HELD or target.partner_id != holder.id:
			continue  # cleanup() frees broken pairs
		var input := inputs[holder.id]
		var dir := Vector3(input.move_x, 0.0, input.move_z)
		if dir.length_squared() > 0.0:
			holder.facing = dir.normalized()
		_place(holder, target, config)
		if input.grab:
			events.append(_throw(holder, target, book.attacks(holder.id).get_attack(AttackSet.Kind.THROW), config))
			continue
		holder.grab_ticks -= 1
		if holder.grab_ticks <= 0:
			_release(holder)
			_release(target)
			events.append({"type": "grab_release", "attacker": holder.id, "target": target.id, "pos": target.pos})
	return events


static func cleanup(fighters: Array[Fighter]) -> void:
	for f: Fighter in fighters:
		if f.state == Fighter.State.HOLDING or f.state == Fighter.State.HELD:
			var want := Fighter.State.HELD if f.state == Fighter.State.HOLDING else Fighter.State.HOLDING
			var partner := find(fighters, f.partner_id)
			if partner == null or partner.state != want or partner.partner_id != f.id:
				_release(f)
		elif f.partner_id != Fighter.NONE:
			f.partner_id = Fighter.NONE
			f.grab_ticks = 0


static func find(fighters: Array[Fighter], id: int) -> Fighter:
	for f: Fighter in fighters:
		if f.id == id:
			return f
	return null


static func _grabbable(holder: Fighter, target: Fighter) -> bool:
	return target != holder and target.is_alive() and not target.untouchable() \
			and target.state != Fighter.State.HOLDING and target.state != Fighter.State.HELD


static func _start_hold(holder: Fighter, target: Fighter, config: GameConfig) -> void:
	holder.set_state(Fighter.State.HOLDING)
	holder.partner_id = target.id
	holder.grab_ticks = SimTime.to_ticks(config.grab_hold_max_time)
	holder.hit_ids.clear()
	Actions.stop_horizontal(holder)
	target.set_state(Fighter.State.HELD)
	target.partner_id = holder.id
	target.vel = Vector3.ZERO
	target.hitstun_ticks = 0
	target.guard_break_left = 0
	target.attack_ticks = 0
	target.charge_ticks = 0
	target.combo_queued = false
	target.hit_ids.clear()
	Dodge.clear(target)
	_place(holder, target, config)


static func _place(holder: Fighter, target: Fighter, config: GameConfig) -> void:
	target.pos = holder.pos + holder.facing * config.grab_hold_distance
	target.facing = -holder.facing


static func _throw(holder: Fighter, target: Fighter, throw_attack: AttackData, config: GameConfig) -> Dictionary:
	_release(holder)
	target.partner_id = Fighter.NONE
	var e := Combat.apply_hit(target, throw_attack, holder.facing, 1.0, config, target.pos, holder.id)
	e["attack_kind"] = AttackSet.Kind.THROW
	holder.hitstop_ticks = throw_attack.hitstop_ticks
	return e


static func _release(f: Fighter) -> void:
	f.partner_id = Fighter.NONE
	f.grab_ticks = 0
	f.set_state(Fighter.State.IDLE if f.on_ground else Fighter.State.AIR)
