class_name WeaponStyle
extends RefCounted
## Weapon (PRD-STYLE-02, Knight): slower swings with longer, wider hitboxes and bigger knockback;
## throws hit as hard as the swings. Slower on foot and heavier (takes less knockback).

const ID := "weapon"


static func moves(c: GameConfig) -> StyleData:
	return StyleData.make(ID, null, c.weapon_move_speed, c.weapon_jump_velocity, c.weapon_air_acceleration,
			c.weapon_knockback_taken)


## base is this tick's classic table (AttackSet.from_config), shared by every style.
static func attacks(c: GameConfig, base: AttackSet) -> AttackSet:
	var table := StyleShape.melee_table(base, c.weapon_damage_mul, c.weapon_knockback_mul, c.weapon_reach_mul,
			c.weapon_width_mul, c.weapon_startup_add, c.weapon_recovery_add)
	table[AttackSet.Kind.THROW] = StyleShape.weaker(base.get_attack(AttackSet.Kind.THROW), c.weapon_knockback_mul)
	return base.with_attacks(table)
