class_name StyleShape
extends RefCounted
## Helpers the style files use to reshape classic attacks into their own (always on copies).

const MELEE_KINDS: Array[int] = [
	AttackSet.Kind.LIGHT_1, AttackSet.Kind.LIGHT_2, AttackSet.Kind.LIGHT_3, AttackSet.Kind.HEAVY,
]


## A copy of `a` with damage and knockback scaled, reach (forward) and width scaled, and
## startup / recovery shifted (never below 0).
static func melee(a: AttackData, damage_mul: float, knockback_mul: float, reach_mul: float,
		width_mul: float, startup_add: int, recovery_add: int) -> AttackData:
	var out := a.copy()
	out.damage *= damage_mul
	out.base_knockback *= knockback_mul
	out.knockback_scaling *= knockback_mul
	out.hitbox_forward *= reach_mul
	out.hitbox_half = Vector3(a.hitbox_half.x * width_mul, a.hitbox_half.y, a.hitbox_half.z * width_mul)
	out.startup_ticks = maxi(a.startup_ticks + startup_add, 0)
	out.recovery_ticks = maxi(a.recovery_ticks + recovery_add, 0)
	return out


## {Kind: reshaped copy} for the light combo and heavy of `base`.
static func melee_table(base: AttackSet, damage_mul: float, knockback_mul: float, reach_mul: float,
		width_mul: float, startup_add: int, recovery_add: int) -> Dictionary:
	var out := {}
	for kind: int in MELEE_KINDS:
		out[kind] = melee(base.get_attack(kind), damage_mul, knockback_mul, reach_mul, width_mul,
				startup_add, recovery_add)
	return out


## A copy of `a` with only damage and knockback scaled (grab and throw overrides).
static func weaker(a: AttackData, mul: float) -> AttackData:
	return melee(a, mul, mul, 1.0, 1.0, 0, 0)


## A copy of `a` fired as a projectile of `kind` flying `speed` m/s for `range_m` metres.
static func as_projectile(a: AttackData, kind: int, speed: float, range_m: float, radius: float) -> AttackData:
	var out := a.copy()
	out.projectile_kind = kind
	out.projectile_speed = speed
	out.projectile_ticks = maxi(SimTime.to_ticks(range_m / maxf(speed, 0.001)), 1)
	out.projectile_radius = radius
	out.active_ticks = 1
	return out
