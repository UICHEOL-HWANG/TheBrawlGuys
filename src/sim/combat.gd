class_name Combat
extends RefCounted
## Hit resolution (PRD §4.2): active hitboxes vs fighter capsules, damage %, knockback formula,
## hitstun and hitstop. Damage is added before knockback is computed (context D7).


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


static func resolve(fighters: Array[Fighter], attacks: AttackSet, config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for attacker: Fighter in fighters:
		if attacker.state != Fighter.State.ATTACK or attacker.attack_kind == AttackSet.Kind.GRAB:
			continue
		var attack := attacks.get_attack(attacker.attack_kind)
		if not attack.is_active(attacker.attack_ticks):
			continue
		var center := hitbox_center(attacker, attack)
		var yaw := Collision.yaw_of(attacker.facing)
		for target: Fighter in fighters:
			if target == attacker or not target.is_alive() or target.invuln_ticks > 0:
				continue
			if attacker.hit_ids.has(target.id):
				continue
			if Collision.capsule_hits_box(target.pos, config.fighter_radius, config.fighter_height,
					center, yaw, attack.hitbox_half):
				events.append(_apply_hit(attacker, target, attack, config, center))
	return events


static func _apply_hit(attacker: Fighter, target: Fighter, attack: AttackData,
		config: GameConfig, at: Vector3) -> Dictionary:
	var power := attacker.charge_mul if attacker.attack_kind == AttackSet.Kind.HEAVY else 1.0
	attacker.hit_ids.append(target.id)
	target.damage += attack.damage * power
	var kb := knockback(attack, target.damage, config) * power
	target.vel = launch_velocity(attacker.facing, attack, kb)
	if target.vel.y > 0.0:
		target.on_ground = false
	target.hitstun_ticks = maxi(hitstun_ticks(kb, config), attack.min_hitstun_ticks)
	target.attack_ticks = 0
	target.hit_ids.clear()
	target.set_state(Fighter.State.HITSTUN)
	target.hitstop_ticks = attack.hitstop_ticks
	attacker.hitstop_ticks = attack.hitstop_ticks
	return {
		"type": "hit", "attacker": attacker.id, "target": target.id, "pos": at,
		"knockback": kb, "hitstop_ticks": attack.hitstop_ticks, "attack_kind": attacker.attack_kind,
		"power": power,
	}
