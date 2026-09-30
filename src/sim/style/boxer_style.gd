class_name BoxerStyle
extends RefCounted
## Boxer (PRD-STYLE-01, Barbarian and Rogue): the light combo recovers faster and moves quicker,
## with shorter reach and a little less knockback. Grab and throw stay classic.

const ID := "boxer"


static func moves(c: GameConfig) -> StyleData:
	return StyleData.make(ID, null, c.boxer_move_speed, c.boxer_jump_velocity, c.boxer_air_acceleration,
			c.boxer_knockback_taken)


## base is this tick's classic table (AttackSet.from_config), shared by every style.
static func attacks(c: GameConfig, base: AttackSet) -> AttackSet:
	return base.with_attacks(StyleShape.melee_table(base, c.boxer_damage_mul, c.boxer_knockback_mul,
			c.boxer_reach_mul, 1.0, 0, c.boxer_recovery_add))
