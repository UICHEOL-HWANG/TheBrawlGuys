class_name SpecialHits
extends RefCounted
## Hit helpers shared by the specials. Every special hit goes through Combat.apply_hit (guard,
## damage, knockback, hitstun) and adds a "special_hit" event {attacker, target, pos, knockback,
## character, special} next to the usual "hit"/"guard_hit" (attack_kind SPECIAL).
## Melee specials report contacts ({attacker, target, attack, dir, at}) found from the start-of-step
## state; SpecialRunner applies them after melee combat, so like Combat.resolve every contact
## lands whatever the fighter ids and whoever else got hit this tick.


static func contact(attacker: Fighter, target: Fighter, attack: AttackData, dir: Vector3, at: Vector3) -> Dictionary:
	return {"attacker": attacker, "target": target, "attack": attack, "dir": dir, "at": at}


## One special hit on target. A melee hit (the attacker's own body) records the target in the
## attacker's hit_ids and freezes the attacker for the hit's hitstop too; a blast does neither.
static func hit(attacker: Fighter, target: Fighter, attack: AttackData, dir: Vector3, at: Vector3,
		config: GameConfig, melee: bool = true) -> Array[Dictionary]:
	var e := Combat.apply_hit(target, attack, dir, 1.0, config, at, attacker.id)
	e["attack_kind"] = AttackSet.Kind.SPECIAL
	if melee:
		attacker.hit_ids.append(target.id)
		attacker.hitstop_ticks = maxi(attacker.hitstop_ticks, attack.hitstop_ticks)
	var special := {
		"type": "special_hit", "attacker": attacker.id, "target": target.id, "pos": at,
		"knockback": e["knockback"], "character": attacker.character,
		"special": CharacterData.special_of(attacker.character),
	}
	return [e, special]


## Contacts with every fighter (not yet hit by this special) whose capsule is within `radius` of
## f, level with it, pushing each straight away from f.
static func radial(f: Fighter, fighters: Array[Fighter], attack: AttackData, radius: float,
		config: GameConfig) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for t: Fighter in fighters:
		if not _hittable(f, t):
			continue
		var d := Vector3(t.pos.x - f.pos.x, 0.0, t.pos.z - f.pos.z)
		if d.length() > radius + config.fighter_radius or absf(t.pos.y - f.pos.y) > config.fighter_height:
			continue
		var dir := d if d.length() > Collision.EPSILON else f.facing
		found.append(contact(f, t, attack, dir, t.pos))
	return found


## Fighters whose capsule touches a sphere of `radius` at `center`, skipping `owner_id`.
static func in_blast(center: Vector3, radius: float, fighters: Array[Fighter], owner_id: int,
		config: GameConfig) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for t: Fighter in fighters:
		if t.id == owner_id or not t.is_alive() or t.untouchable():
			continue
		var offset := t.pos + Vector3.UP * (config.fighter_height * 0.5) - center
		if offset.length() <= radius + config.fighter_radius:
			out.append(t)
	return out


static func _hittable(f: Fighter, t: Fighter) -> bool:
	return t != f and t.is_alive() and not t.untouchable() and not f.hit_ids.has(t.id)
