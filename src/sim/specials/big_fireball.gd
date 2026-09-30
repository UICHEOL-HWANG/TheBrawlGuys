class_name BigFireball
extends Special
## Mage "거대 화염구" (big fireball): after the windup a big, slow fireball leaves her hand on the
## first active tick; it explodes on the first fighter it touches or at the end of its range,
## hitting every foe in fireball_explode_radius (never the Mage herself) away from the blast.

const ID := "big_fireball"


func attack(c: GameConfig) -> AttackData:
	var a := AttackData.make(c.fireball_damage, c.fireball_base_knockback, c.fireball_knockback_scaling,
			c.fireball_launch_angle_y, c.fireball_startup_ticks, 1, c.fireball_recovery_ticks, c.hitstop_heavy)
	a.hitbox_up = c.light_hitbox_up
	return StyleShape.as_projectile(a, Projectile.Kind.FIREBALL, c.fireball_speed, c.fireball_range, c.fireball_radius)


func advance(f: Fighter, a: AttackData, field: ProjectileField, c: GameConfig) -> Array[Dictionary]:
	if f.attack_ticks != a.startup_ticks + 1:
		return []
	return [field.fire(f, a, AttackSet.Kind.SPECIAL, 1.0, c).event("projectile_spawn")]


func reach(c: GameConfig) -> float:
	return c.fireball_range


## The blast of fireball p (on contact or at the end of its range).
static func explode(p: Projectile, fighters: Array[Fighter], a: AttackData, c: GameConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var owner := Grab.find(fighters, p.owner_id)
	if owner == null:
		return events
	for t: Fighter in SpecialHits.in_blast(p.pos, c.fireball_explode_radius, fighters, p.owner_id, c):
		var dir := Vector3(t.pos.x - p.pos.x, 0.0, t.pos.z - p.pos.z)
		if dir.length() < Collision.EPSILON:
			dir = Vector3(p.vel.x, 0.0, p.vel.z)
		events.append_array(SpecialHits.hit(owner, t, a, dir, p.pos, c, false))
	return events
