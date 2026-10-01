class_name Combat
extends RefCounted
## Hit resolution (PRD §4.2): active hitboxes vs fighter capsules, damage %, knockback formula,
## hitstun and hitstop. Damage is added before knockback is computed (context D7).
## All hit sources share apply_hit, which also handles guard (context E4) and the target style's
## knockback_taken (Phase 5). Melee numbers come from each attacker's style (StyleBook).


static func knockback(attack: AttackData, target_damage: float, config: GameConfig) -> float:
	return (attack.base_knockback + target_damage * attack.knockback_scaling) * config.global_knockback_mul


static func launch_velocity(facing: Vector3, attack: AttackData, knockback_value: float) -> Vector3:
	var dir := Vector3(facing.x, attack.launch_angle_y, facing.z)
	if dir.length() <= 0.0:
		return Vector3.ZERO
	return dir.normalized() * knockback_value


static func hitstun_ticks(knockback_value: float, config: GameConfig) -> int:
	return SimTime.to_ticks(knockback_value * config.hitstun_factor)


static func hitbox_center(attacker: Fighter, attack: AttackData) -> Vector3:
	return attacker.pos + attacker.facing * attack.hitbox_forward + Vector3.UP * attack.hitbox_up


## Two passes so same-tick trades are fair (Phase 3 carry-over): every contact is found from the
## state at the start of the step, then all of them are applied. A fighter hit this tick still
## lands its own active hit, whatever the fighter ids, and everyone in a contact ends up frozen
## for the longest hitstop among its contacts this tick (order-free).
static func resolve(fighters: Array[Fighter], book: StyleBook, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var freeze := {}  # Fighter -> longest hitstop from this pass
	for h: Dictionary in _contacts(fighters, book, config):
		var attacker: Fighter = h["attacker"]
		var target: Fighter = h["target"]
		var attack: AttackData = h["attack"]
		attacker.hit_ids.append(target.id)
		var e := apply_hit(target, attack, h["facing"], h["power"], config, h["center"], attacker.id)
		e["attack_kind"] = h["kind"]
		events.append(e)
		for f: Fighter in [attacker, target]:
			freeze[f] = maxi(int(freeze.get(f, 0)), attack.hitstop_ticks)
	for f: Fighter in freeze:
		f.hitstop_ticks = freeze[f]
	return events


## Active hitbox vs capsule contacts, in attacker then target id order, with everything the hit
## needs captured before any hit changes a fighter.
static func _contacts(fighters: Array[Fighter], book: StyleBook, config: GameConfig) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for attacker: Fighter in fighters:
		if attacker.state != Fighter.State.ATTACK or attacker.attack_kind == AttackSet.Kind.GRAB:
			continue
		var attack := book.attacks(attacker.id).get_attack(attacker.attack_kind)
		if not attack.hits_melee(attacker.attack_ticks):
			continue
		var center := hitbox_center(attacker, attack)
		var yaw := Collision.yaw_of(attacker.facing)
		var power := attacker.charge_mul if attacker.attack_kind == AttackSet.Kind.HEAVY else 1.0
		for target: Fighter in fighters:
			if target == attacker or not target.is_alive() or target.untouchable_by(attacker.id):
				continue
			if attacker.hit_ids.has(target.id):
				continue
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, attack.hitbox_half):
				found.append({"attacker": attacker, "target": target, "attack": attack, "center": center,
						"facing": attacker.facing, "power": power, "kind": attacker.attack_kind})
	return found


## One hit from any source (melee, throw, projectile, explosion). dir is the push direction (only its horizontal part is used, normalized),
## power scales damage and knockback (heavy charge). A guarding target takes guard_damage_mul
## of the damage and guard_knockback_mul of the knockback as a flat push, stays in GUARD and
## reports "guard_hit" (context E4); the block costs guard points, or nothing at all on a perfect
## guard (GuardMeter). Sets the target's hitstop; the caller sets the attacker's.
static func apply_hit(target: Fighter, attack: AttackData, dir: Vector3, power: float,
		config: GameConfig, at: Vector3, source_id: int) -> Dictionary:
	var guarded := target.state == Fighter.State.GUARD
	var perfect := guarded and GuardMeter.is_perfect(target, config)
	var dealt := attack.damage * power * (0.0 if perfect else config.guard_damage_mul if guarded else 1.0)
	target.damage += dealt
	var kb := knockback(attack, target.damage, config) * power * StyleCatalog.knockback_taken(
			CharacterData.style_of(target.character), config) * Knockdown.hit_mul(target, config)
	target.hitstop_ticks = attack.hitstop_ticks
	var event := {
		"type": "hit", "attacker": source_id, "target": target.id, "pos": at, "damage": dealt,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks, "power": power,
	}
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	flat_dir = flat_dir.normalized() if flat_dir.length() > 0.0 else Vector3.ZERO
	if guarded:
		if perfect:
			target.perfect_by = source_id
		else:
			GuardMeter.block(target, attack.damage * power, config)
		_guard_push(target, flat_dir, kb * config.guard_knockback_mul, event)
		return event
	_launch(target, attack, flat_dir, kb, config)
	return event


## A clean hit: launch, hitstun, interrupt; a strong upward launch tumbles (Knockdown) and every
## launch takes DI when its hitstop ends (LaunchInfluence).
static func _launch(target: Fighter, attack: AttackData, flat_dir: Vector3, kb: float, config: GameConfig) -> void:
	var was_lying := target.state == Fighter.State.KNOCKDOWN
	target.vel = launch_velocity(flat_dir, attack, kb)
	if target.vel.y > 0.0:
		target.on_ground = false
	target.hitstun_ticks = maxi(hitstun_ticks(kb, config), attack.min_hitstun_ticks)
	_interrupt(target)
	target.tumble = Knockdown.tumbles(kb, target.vel, was_lying, config)
	target.di_pending = true


static func _guard_push(target: Fighter, flat_dir: Vector3, kb: float, event: Dictionary) -> void:
	var push := flat_dir * kb
	target.vel.x = push.x
	target.vel.z = push.z
	event["type"] = "guard_hit"
	event["knockback"] = kb


## A clean hit ends whatever the target was doing (attack, charge, dodge, guard-break stun).
static func _interrupt(target: Fighter) -> void:
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.combo_queued = false
	target.charge_ticks = 0
	target.guard_break_left = 0
	Dodge.clear(target)
	Getup.clear(target)
	target.set_state(Fighter.State.HITSTUN)
