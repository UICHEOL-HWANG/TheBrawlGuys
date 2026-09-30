class_name RangedStyle
extends RefCounted
## Ranged (PRD-STYLE-03, Mage): light fires bolts (hits 1-2 are link bolts that hold hitstun like
## the light combo, hit 3 knocks back) and heavy fires a charged heavy bolt. Grab and throw are
## weak (ranged_melee_mul), so a ranged fighter wants distance.

const ID := "ranged"


static func moves(c: GameConfig) -> StyleData:
	return StyleData.make(ID, null, c.ranged_move_speed, c.ranged_jump_velocity, c.ranged_air_acceleration,
			c.ranged_knockback_taken)


## base is this tick's classic table (AttackSet.from_config), shared by every style.
static func attacks(c: GameConfig, base: AttackSet) -> AttackSet:
	var link := _bolt(c, 0.0, 0.0, c.bolt_hitstun_ticks)
	var table := {
		AttackSet.Kind.LIGHT_1: link,
		AttackSet.Kind.LIGHT_2: link,
		AttackSet.Kind.LIGHT_3: _bolt(c, c.bolt_knockback_scaling, c.bolt_launch_angle_y, 0),
		AttackSet.Kind.HEAVY: _heavy_bolt(c, base.get_attack(AttackSet.Kind.HEAVY)),
		AttackSet.Kind.THROW: StyleShape.weaker(base.get_attack(AttackSet.Kind.THROW), c.ranged_melee_mul),
	}
	return base.with_attacks(table)


static func _bolt(c: GameConfig, scaling: float, angle: float, min_hitstun: int) -> AttackData:
	var a := AttackData.new()
	a.damage = c.bolt_damage
	a.base_knockback = c.bolt_base_knockback
	a.knockback_scaling = scaling
	a.launch_angle_y = angle
	a.startup_ticks = c.bolt_startup_ticks
	a.recovery_ticks = c.bolt_recovery_ticks
	a.hitbox_up = c.light_hitbox_up
	a.hitstop_ticks = SimTime.to_ticks(c.hitstop_light)
	a.min_hitstun_ticks = min_hitstun
	return StyleShape.as_projectile(a, Projectile.Kind.BOLT, c.bolt_speed, c.bolt_range, c.bolt_radius)


static func _heavy_bolt(c: GameConfig, heavy: AttackData) -> AttackData:
	var a := StyleShape.weaker(heavy, c.heavy_bolt_damage_mul)
	return StyleShape.as_projectile(a, Projectile.Kind.HEAVY_BOLT, c.heavy_bolt_speed, c.heavy_bolt_range,
			c.heavy_bolt_radius)
