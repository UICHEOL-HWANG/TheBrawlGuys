class_name ProjectileMotion
extends RefCounted
## Projectile life (PRD-STYLE-03): fired on the first active tick of a projectile attack, flies
## straight, hits the first fighter capsule it touches (never its owner, never invulnerable
## fighters; guard blocks it through Combat.apply_hit) and expires after its lifetime. The big
## fireball explodes on contact or at the end of its range instead (BigFireball.explode).
## Events: projectile_spawn / projectile_hit (+ "target") / projectile_expire {id, owner, kind, pos}.


## Fires for each fighter that advanced this tick (not frozen) and just reached the first active
## tick of a projectile attack, so a frozen fighter never fires twice.
static func fire(advanced: Array[Fighter], book: StyleBook, field: ProjectileField,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for f: Fighter in advanced:
		if f.state != Fighter.State.ATTACK:
			continue
		var attack := book.attacks(f.id).get_attack(f.attack_kind)
		if attack.projectile_kind == AttackData.MELEE or f.attack_ticks != attack.startup_ticks + 1:
			continue
		var power := f.charge_mul if f.attack_kind == AttackSet.Kind.HEAVY else 1.0
		events.append(field.fire(f, attack, f.attack_kind, power, config).event("projectile_spawn"))
	return events


static func step(field: ProjectileField, fighters: Array[Fighter], book: StyleBook,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Projectile] = []
	for p: Projectile in field.list:
		p.pos += p.vel * SimTime.TICK_DT
		p.ticks_left -= 1
		var target := _first_hit(p, fighters, config)
		var attack := book.attacks(p.owner_id).get_attack(p.attack_kind)
		if target != null:
			events.append_array(_hit(p, target, fighters, attack, config))
		elif p.ticks_left <= 0:
			events.append_array(_expire(p, fighters, attack, config))
		else:
			keep.append(p)
	field.list = keep
	return events


static func _hit(p: Projectile, target: Fighter, fighters: Array[Fighter], attack: AttackData,
		config: GameConfig) -> Array[Dictionary]:
	var e := p.event("projectile_hit")
	e["target"] = target.id
	var events: Array[Dictionary] = [e]
	if p.kind == Projectile.Kind.FIREBALL:
		events.append_array(BigFireball.explode(p, fighters, attack, config))
		return events
	var hit := Combat.apply_hit(target, attack, p.vel, p.power, config, p.pos, p.owner_id)
	hit["attack_kind"] = p.attack_kind
	hit["projectile_kind"] = p.kind
	events.append(hit)
	return events


static func _expire(p: Projectile, fighters: Array[Fighter], attack: AttackData,
		config: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = [p.event("projectile_expire")]
	if p.kind == Projectile.Kind.FIREBALL:
		events.append_array(BigFireball.explode(p, fighters, attack, config))
	return events


static func _first_hit(p: Projectile, fighters: Array[Fighter], config: GameConfig) -> Fighter:
	var half := Vector3.ONE * p.radius
	for f: Fighter in fighters:
		if f.id == p.owner_id or not f.is_alive() or f.untouchable_by(p.owner_id):
			continue
		if Collision.capsule_hits_box(f.pos, config.fighter_radius, config.fighter_height, p.pos, 0.0, half):
			return f
	return null
