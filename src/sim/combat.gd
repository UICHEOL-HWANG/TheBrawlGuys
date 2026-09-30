class_name Combat
extends RefCounted
## Hit resolution (PRD §4.2): active hitboxes vs fighter capsules, damage %, knockback formula,
## hitstun and hitstop. Damage is added before knockback is computed (context D7).
## All hit sources share apply_hit, which also handles guard (context E4).


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
## lands its own active hit, whatever the fighter ids.
static func resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for h: Dictionary in _contacts(fighters, attacks, config):
		var attacker: Fighter = h["attacker"]
		var target: Fighter = h["target"]
		var attack: AttackData = h["attack"]
		attacker.hit_ids.append(target.id)
		var e := apply_hit(target, attack, h["facing"], h["power"], config, h["center"], attacker.id)
		e["attack_kind"] = h["kind"]
		attacker.hitstop_ticks = maxi(attacker.hitstop_ticks, attack.hitstop_ticks)
		events.append(e)
	return events


## Active hitbox vs capsule contacts, in attacker then target id order, with everything the hit
## needs captured before any hit changes a fighter.
static func _contacts(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for attacker: Fighter in fighters:
		if attacker.state != Fighter.State.ATTACK or attacker.attack_kind == AttackSet.Kind.GRAB:
			continue
		var attack := attacks.get_attack(attacker.attack_kind)
		if not attack.is_active(attacker.attack_ticks):
			continue
		var center := hitbox_center(attacker, attack)
		var yaw := Collision.yaw_of(attacker.facing)
		var power := attacker.charge_mul if attacker.attack_kind == AttackSet.Kind.HEAVY else 1.0
		for target: Fighter in fighters:
			if target == attacker or not target.is_alive() or target.invuln_ticks > 0:
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
## reports "guard_hit" (context E4). Sets the target's hitstop; the caller sets the attacker's.
static func apply_hit(target: Fighter, attack: AttackData, dir: Vector3, power: float,
		config: GameConfig, at: Vector3, source_id: int) -> Dictionary:
	var guarded := target.state == Fighter.State.GUARD
	target.damage += attack.damage * power * (config.guard_damage_mul if guarded else 1.0)
	var kb := knockback(attack, target.damage, config) * power
	target.hitstop_ticks = attack.hitstop_ticks
	var event := {
		"type": "hit", "attacker": source_id, "target": target.id, "pos": at,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks, "power": power,
	}
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	flat_dir = flat_dir.normalized() if flat_dir.length() > 0.0 else Vector3.ZERO
	if guarded:
		kb *= config.guard_knockback_mul
		var push := flat_dir * kb
		target.vel.x = push.x
		target.vel.z = push.z
		event["type"] = "guard_hit"
		event["knockback"] = kb
		return event
	target.vel = launch_velocity(flat_dir, attack, kb)
	if target.vel.y > 0.0:
		target.on_ground = false
	target.hitstun_ticks = maxi(hitstun_ticks(kb, config), attack.min_hitstun_ticks)
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.combo_queued = false
	target.charge_ticks = 0
	target.set_state(Fighter.State.HITSTUN)
	return event
