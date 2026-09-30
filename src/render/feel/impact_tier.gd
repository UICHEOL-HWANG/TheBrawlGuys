class_name ImpactTier
extends RefCounted
## Hit impact sizing (design.md DS-VFX-01 v2, DS-VFX-09): the knockback of a hit picks a tier,
## and each tier sets the comic burst radius, spike count, speed lines and damage number size.
## Also the flat direction a hit travels in, and the per-quality cap on live effects.

enum Tier { LIGHT, MEDIUM, HEAVY }

## Star burst outer radius (m) per tier.
const BURST_RADIUS := [0.8, 1.15, 1.55]
## Star spikes per tier.
const STAR_POINTS := [7, 9, 12]
## Damage number size multiplier per tier.
const POPUP_SCALE := [1.0, 1.2, 1.55]
## Heavy-hit speed lines at full particle quality.
const SPEED_LINES := 10
## Simultaneous bursts / damage numbers at full particle quality.
const POOL_CAP := 6
## Melee hits read attacker -> target; closer than this the hit point is used instead.
const MIN_DIRECTION := 0.05


static func of(knockback: float, config: GameConfig) -> int:
	if knockback >= config.spark_large_threshold:
		return Tier.HEAVY
	if knockback >= config.impact_medium_threshold:
		return Tier.MEDIUM
	return Tier.LIGHT


static func burst_radius(tier: int) -> float:
	return BURST_RADIUS[clampi(tier, Tier.LIGHT, Tier.HEAVY)]


static func star_points(tier: int) -> int:
	return STAR_POINTS[clampi(tier, Tier.LIGHT, Tier.HEAVY)]


static func popup_scale(tier: int) -> float:
	return POPUP_SCALE[clampi(tier, Tier.LIGHT, Tier.HEAVY)]


static func speed_lines(tier: int, particle_scale: float) -> int:
	if tier != Tier.HEAVY:
		return 0
	return maxi(roundi(SPEED_LINES * particle_scale), 3)


static func pool_cap(particle_scale: float) -> int:
	return maxi(roundi(POOL_CAP * particle_scale), 1)


## "+12%" (whole percent), keeping one decimal for chip damage under 1%.
static func popup_text(dealt: float) -> String:
	if dealt < 1.0:
		return "+%.1f%%" % dealt
	return "+%d%%" % roundi(dealt)


## Flat unit direction the hit pushes the target in: attacker -> target for melee, hit point ->
## target otherwise (projectiles, explosions), each falling back to the other (throws hit at the
## target's own position) and finally to +X.
static func hit_direction(target_pos: Vector3, hit_pos: Vector3, attacker_pos: Vector3, melee: bool) -> Vector3:
	for from: Vector3 in ([attacker_pos, hit_pos] if melee else [hit_pos, attacker_pos]):
		var d := _flat(target_pos - from)
		if d.length() >= MIN_DIRECTION:
			return d.normalized()
	return Vector3.RIGHT


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
